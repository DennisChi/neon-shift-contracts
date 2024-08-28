// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

interface IERC1155BurnMint {
    function mint(address to, uint256 id) external;

    function burn(address from, uint256 id) external;

    function batchMint(address to, uint256[] memory ids) external;

    function batchBurn(address from, uint256[] memory ids) external;
}
