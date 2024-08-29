// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {IPartPack} from "./interfaces/IPartPack.sol";
import {ICarPart, Part} from "./interfaces/ICarPart.sol";

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract PartPack is
    ERC1155URIStorage,
    AccessControl,
    VRFConsumerBaseV2Plus,
    IPartPack
{
    ICarPart private immutable _carPart;

    mapping(uint256 tokenId => uint256 remaining) private _remainingOf;
    mapping(uint256 tokenId => uint256 price) private _priceOf;
    mapping(uint256 tokenId => uint256[] partIds) private _partIdsOf;
    mapping(uint256 requestId => address requester) private _requesterOf;
    mapping(uint256 requestId => uint256 tokenId) private _tokenIdOf;
    mapping(uint256 rareLevel => uint256 dropWeight) private _dropWeightOf;

    uint256 private immutable _subId;
    bytes32 private immutable _keyHash;
    uint32 private immutable _callbackGasLimit;
    uint16 private immutable _requestConfirmations;

    constructor(
        address carPart_,
        address vrfCoordinator_,
        uint256 subId_,
        bytes32 keyHash_,
        uint32 callbackGasLimit_,
        uint16 requestConfirmations_,
        uint256[] memory dropWeights_
    ) VRFConsumerBaseV2Plus(vrfCoordinator_) ERC1155("") {
        _carPart = ICarPart(carPart_);
        _subId = subId_;
        _keyHash = keyHash_;
        _callbackGasLimit = callbackGasLimit_;
        _requestConfirmations = requestConfirmations_;
        for (uint256 i = 0; i < dropWeights_.length; i++) {
            _dropWeightOf[i + 1] = dropWeights_[i];
        }
    }

    function open(uint256 tokenId, uint256 amount) external override {
        if (amount == 0) revert PartPackInvalidAmount();
        if (balanceOf(msg.sender, tokenId) < amount)
            revert PartPackInsufficientParts();
        _burn(msg.sender, tokenId, amount);
        uint256 requestId = IVRFCoordinatorV2Plus(s_vrfCoordinator)
            .requestRandomWords(
                VRFV2PlusClient.RandomWordsRequest({
                    subId: _subId,
                    keyHash: _keyHash,
                    requestConfirmations: _requestConfirmations,
                    callbackGasLimit: _callbackGasLimit,
                    numWords: 5,
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                    )
                })
            );
        _requesterOf[requestId] = msg.sender;
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external payable override {
        if (amount == 0) revert PartPackInvalidAmount();
        if (_remainingOf[tokenId] < amount) revert PartPackInsufficientParts();
        if (msg.value < _priceOf[tokenId] * amount)
            revert PartPackInsufficientParts();

        _mint(to, tokenId, amount, "");
        _remainingOf[tokenId] -= amount;
    }

    function addPack(
        uint256 tokenId,
        uint256 price,
        uint256 amount,
        Part[] memory parts,
        string calldata uri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256[] memory partIds = new uint256[](parts.length);
        for (uint256 i = 0; i < parts.length; i++) {
            partIds[i] = parts[i].id;
        }
        _partIdsOf[tokenId] = partIds;
        _remainingOf[tokenId] = amount;
        _priceOf[tokenId] = price;
        _setURI(tokenId, uri);

        _carPart.addParts(parts);
    }

    function remaining(
        uint256 tokenId
    ) external view override returns (uint256) {
        return _remainingOf[tokenId];
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControl, ERC1155, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        address requester = _requesterOf[requestId];
        uint256 tokenId = _tokenIdOf[requestId];
        uint256[] memory partIds = _partIdsOf[tokenId];
        Part[] memory parts = _carPart.partsOf(partIds);

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < parts.length; i++) {
            uint256 rareLevel = parts[i].rareLevel;
            uint256 dropWeight = _dropWeightOf[rareLevel];
            totalWeight += dropWeight;
        }

        uint256[] memory selectedPartIds = new uint256[](randomWords.length);
        for (uint256 i = 0; i < randomWords.length; i++) {
            uint256 randomNumber = randomWords[i];
            uint256 selectedWeight = randomNumber % totalWeight;
            uint256 accumulatedWeight = 0;

            for (uint256 j = 0; j < parts.length; j++) {
                uint256 rareLevel = parts[j].rareLevel;
                uint256 dropWeight = _dropWeightOf[rareLevel];
                accumulatedWeight += dropWeight;
                if (selectedWeight < accumulatedWeight) {
                    selectedPartIds[i] = partIds[j];
                    break;
                }
            }
        }

        _carPart.batchMint(requester, partIds);
    }
}
