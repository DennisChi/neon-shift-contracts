// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

interface IERC721BurnMint {
    function burn(uint256 tokenId) external;

    function mint(address to) external returns (uint256 tokenId);
}
