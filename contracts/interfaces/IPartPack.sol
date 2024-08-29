// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

interface IPartPack is IERC1155MetadataURI, IERC1155Errors {
    error PartPackInvalidAmount();

    error PartPackInsufficientParts();

    function open(uint256 tokenId, uint256 amount) external;

    function mint(address to, uint256 tokenId, uint256 amount) external payable;

    function remaining(uint256 tokenId) external view returns (uint256);
}
