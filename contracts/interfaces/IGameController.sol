// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

interface IGameController {
    struct Part {
        uint256 rareLevel;
        string name;
        string partType;
        string image;
    }

    function partsOf(uint256 tokenId) external view returns (Part[] memory);

    function partOf(uint256 partId) external view returns (Part memory);
}
