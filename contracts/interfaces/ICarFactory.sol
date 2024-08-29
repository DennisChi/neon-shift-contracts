// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

interface ICarFactory {
    error CarFactoryInvalidPartsLength();

    error CarFactoryInvalidPartsType();

    error CarFactoryPartNotOwned();

    function disassemble(uint256 carId) external;

    function assemble(
        uint256[] memory partIds
    ) external returns (uint256 carId);

    function buildCar() external payable;
}
