// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

interface ICarFactory {
    struct Part {
        uint256 id;
        uint256 rareLevel;
        string name;
        string partType;
        string image;
    }

    function disassemble(uint256 carId) external;

    function assemble(
        uint256[] memory partIds
    ) external returns (uint256 carId);

    function partsOf(uint256 carId) external view returns (Part[] memory);

    function partOf(uint256 partId) external view returns (Part memory);
}
