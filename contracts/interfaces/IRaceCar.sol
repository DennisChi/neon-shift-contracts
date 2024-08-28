// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

interface IRaceCar is IERC721, IERC721Metadata, IERC721Errors {
    function mint(
        address to,
        uint256[] memory partIds
    ) external returns (uint256 tokenId);

    function burn(uint256 tokenId) external;

    function partsOf(
        uint256 tokenId
    ) external view returns (uint256[] memory partIds);
}
