// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {IRaceCar} from "./interfaces/IRaceCar.sol";
import {ICarPart, Part} from "./interfaces/ICarPart.sol";
import {ICarFactory} from "./interfaces/ICarFactory.sol";

import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

contract CarFactory is ICarFactory, VRFConsumerBaseV2Plus {
    bytes32 public constant PART_TYPES =
        keccak256("Lighting") |
            keccak256("Painting") |
            keccak256("Engine") |
            keccak256("Tires");

    bytes32 private _keyHash;
    uint256 private _subId;
    uint32 private _callbackGasLimit;
    uint16 private _requestConfirmations;

    address private _carPart;
    address private _raceCar;

    // rare level => drop rate
    mapping(uint256 => uint256) private _dropWeightOf;
    // requestId => builder
    mapping(uint256 => address) private _builderOf;

    // Default Parts
    Part[] private _defaultLightingParts;
    Part[] private _defaultPaintingParts;
    Part[] private _defaultEngineParts;
    Part[] private _defaultTiresParts;

    uint256 private _totalWeightOfDefaultLightingParts;
    uint256 private _totalWeightOfDefaultPaintingParts;
    uint256 private _totalWeightOfDefaultEngineParts;
    uint256 private _totalWeightOfDefaultTiresParts;

    constructor(
        address carPart_,
        address raceCar_,
        address vrfCoordinator_,
        uint256 subId_,
        bytes32 keyHash_,
        uint32 callbackGasLimit_,
        uint16 requestConfirmations_,
        Part[] memory defaultLightingParts_,
        Part[] memory defaultPaintingParts_,
        Part[] memory defaultEngineParts_,
        Part[] memory defaultTiresParts_
    ) VRFConsumerBaseV2Plus(vrfCoordinator_) {
        _initializeAddresses(carPart_, raceCar_);
        _initializeVRFParameters(
            subId_,
            keyHash_,
            callbackGasLimit_,
            requestConfirmations_
        );
        _initializeDefaultParts(
            defaultLightingParts_,
            defaultPaintingParts_,
            defaultEngineParts_,
            defaultTiresParts_
        );
    }

    function disassemble(uint256 carId) external override {
        address owner = IRaceCar(_raceCar).ownerOf(carId);
        require(msg.sender == owner, "Not owner");

        uint256[] memory partIds = IRaceCar(_raceCar).partsOf(carId);

        IRaceCar(_raceCar).burn(carId);
        ICarPart(_carPart).batchMint(owner, partIds);
    }

    function assemble(
        uint256[] memory partIds
    ) external override returns (uint256) {
        for (uint256 i = 0; i < partIds.length; i++) {
            uint256 balance = ICarPart(_carPart).balanceOf(
                msg.sender,
                partIds[i]
            );
            if (balance == 0) {
                revert CarFactoryPartNotOwned();
            }
        }

        if (partIds.length != 4) {
            revert CarFactoryInvalidPartsLength();
        }
        Part[] memory parts = ICarPart(_carPart).partsOf(partIds);

        bytes32 partTypes = 0;
        for (uint256 i = 0; i < parts.length; i++) {
            partTypes |= keccak256(abi.encodePacked(parts[i].partType));
        }

        if (partTypes != PART_TYPES) {
            revert CarFactoryInvalidPartsType();
        }

        ICarPart(_carPart).batchBurn(msg.sender, partIds);
        return IRaceCar(_raceCar).mint(msg.sender, partIds);
    }

    function buildCar() external payable {
        uint256 requestId = IVRFCoordinatorV2Plus(s_vrfCoordinator)
            .requestRandomWords(
                VRFV2PlusClient.RandomWordsRequest(
                    _keyHash,
                    _subId,
                    _requestConfirmations,
                    _callbackGasLimit,
                    4,
                    VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                )
            );

        _builderOf[requestId] = msg.sender;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert();
        }

        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) {
            revert();
        }
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        address builder = _builderOf[requestId];
        delete _builderOf[requestId];

        uint256 randomLighting = randomWords[0] %
            _totalWeightOfDefaultLightingParts;
        uint256 randomPainting = randomWords[1] %
            _totalWeightOfDefaultPaintingParts;
        uint256 randomEngine = randomWords[2] %
            _totalWeightOfDefaultEngineParts;
        uint256 randomTires = randomWords[3] % _totalWeightOfDefaultTiresParts;

        uint256[] memory partIds = new uint256[](4);
        partIds[0] = _defaultLightingParts[randomLighting].id;
        partIds[1] = _defaultPaintingParts[randomPainting].id;
        partIds[2] = _defaultEngineParts[randomEngine].id;
        partIds[3] = _defaultTiresParts[randomTires].id;

        IRaceCar(_raceCar).mint(builder, partIds);
    }

    function _initializeAddresses(address carPart_, address raceCar_) private {
        _carPart = carPart_;
        _raceCar = raceCar_;
    }

    function _initializeVRFParameters(
        uint256 subId_,
        bytes32 keyHash_,
        uint32 callbackGasLimit_,
        uint16 requestConfirmations_
    ) private {
        _subId = subId_;
        _keyHash = keyHash_;
        _callbackGasLimit = callbackGasLimit_;
        _requestConfirmations = requestConfirmations_;
    }

    function _initializeDefaultParts(
        Part[] memory defaultLightingParts_,
        Part[] memory defaultPaintingParts_,
        Part[] memory defaultEngineParts_,
        Part[] memory defaultTiresParts_
    ) private {
        _defaultLightingParts = _calculatePartsWithId(defaultLightingParts_);
        _defaultPaintingParts = _calculatePartsWithId(defaultPaintingParts_);
        _defaultEngineParts = _calculatePartsWithId(defaultEngineParts_);
        _defaultTiresParts = _calculatePartsWithId(defaultTiresParts_);

        _totalWeightOfDefaultLightingParts = _calculateTotalWeight(
            _defaultLightingParts
        );
        _totalWeightOfDefaultPaintingParts = _calculateTotalWeight(
            _defaultPaintingParts
        );
        _totalWeightOfDefaultEngineParts = _calculateTotalWeight(
            _defaultEngineParts
        );
        _totalWeightOfDefaultTiresParts = _calculateTotalWeight(
            _defaultTiresParts
        );
    }

    function _calculatePartsWithId(
        Part[] memory parts
    ) private pure returns (Part[] memory) {
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i].id = _generatePartId(parts[i]);
        }
        return parts;
    }

    function _calculateTotalWeight(
        Part[] memory parts
    ) private view returns (uint256) {
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < parts.length; i++) {
            totalWeight += _dropWeightOf[parts[i].rareLevel];
        }
        return totalWeight;
    }

    function _generatePartId(Part memory part) private pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        part.name,
                        part.partType,
                        part.rareLevel,
                        part.image
                    )
                )
            );
    }
}
