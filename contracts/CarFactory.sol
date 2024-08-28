// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {ICarFactory} from "./interfaces/ICarFactory.sol";
import {IRaceCar} from "./interfaces/IRaceCar.sol";
import {ICarPart} from "./interfaces/ICarPart.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CarFactory is ICarFactory, Ownable {
    address private _carPart;
    address private _raceCar;

    constructor(address carPart, address raceCar) Ownable(msg.sender) {
        _carPart = carPart;
        _raceCar = raceCar;
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
            require(balance > 0, "Part not owned");
        }

        // TODO: Check the length of partIds array, validity of id range, and whether it can form a car based on type

        ICarPart(_carPart).batchBurn(msg.sender, partIds);
        return IRaceCar(_raceCar).mint(msg.sender, partIds);
    }

    // Entry point for users to initially build a car
    function buildCar() external payable returns (uint256 carId) {
        // TODO: Check the length of partIds array, validity of id range, and whether it can form a car based on type
    }
}
