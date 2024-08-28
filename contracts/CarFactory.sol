// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "./access/Ownable.sol";
import {ICarFactory} from "./interfaces/ICarFactory.sol";
import {IERC1155} from "./interfaces/IERC1155.sol";
import {IERC721} from "./interfaces/IERC721.sol";
import {IERC1155BurnMint} from "./interfaces/IERC1155BurnMint.sol";
import {IERC721BurnMint} from "./interfaces/IERC721BurnMint.sol";

// TODO: Move the part section to CarPart and RaceCar contracts
// 1. replace the ownable with access control
//    ADMIN_ROLE, CAR_FACTORY_ROLE
// 2. reduce the interfaces with OpenZeppelin & inherit from them
//    IRaceCar, ICarPart
contract CarFactory is ICarFactory, Ownable {
    // carId => parts
    mapping(uint256 => Part[]) private _partsOf;
    // partId => part
    mapping(uint256 => Part) private _partOf;

    uint256 private _maxPartId;
    address private _carPart;
    address private _raceCar;

    constructor(address carPart, address raceCar) Ownable(msg.sender) {
        _carPart = carPart;
        _raceCar = raceCar;
    }

    function disassemble(uint256 carId) external override {
        address owner = IERC721(_raceCar).ownerOf(carId);
        require(msg.sender == owner, "Not owner");

        Part[] memory parts = _partsOf[carId];
        uint256[] memory partIds = new uint256[](parts.length);
        for (uint256 i = 0; i < parts.length; i++) {
            partIds[i] = parts[i].id;
        }

        IERC721BurnMint(_raceCar).burn(carId);
        IERC1155BurnMint(_carPart).batchMint(owner, partIds);
    }

    function assemble(
        uint256[] memory partIds
    ) external override returns (uint256) {
        for (uint256 i = 0; i < partIds.length; i++) {
            uint256 balance = IERC1155(_carPart).balanceOf(
                msg.sender,
                partIds[i]
            );
            require(balance > 0, "Part not owned");
        }

        // TODO: Check the length of partIds array, validity of id range, and whether it can form a car based on type

        IERC1155BurnMint(_carPart).batchBurn(msg.sender, partIds);
        return IERC721BurnMint(_raceCar).mint(msg.sender);
    }

    function addParts(Part[] memory parts) external onlyOwner {
        uint256 partId = _maxPartId;
        for (uint256 i = 0; i < parts.length; i++) {
            // TODO: Check the validity of the part
            parts[i].id = ++partId;
            _partOf[partId] = parts[i];
        }
        _maxPartId = partId;
    }

    // Entry point for users to initially build a car
    function buildCar() external payable returns (uint256 carId) {
        // TODO: Check the length of partIds array, validity of id range, and whether it can form a car based on type
    }

    function partsOf(
        uint256 carId
    ) external view override returns (Part[] memory) {
        return _partsOf[carId];
    }

    function partOf(
        uint256 partId
    ) external view override returns (Part memory) {
        return _partOf[partId];
    }
}
