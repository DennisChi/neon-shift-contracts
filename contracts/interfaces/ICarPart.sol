// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

struct Part {
    uint256 id;
    uint256 rareLevel;
    string name;
    string partType;
    string image;
}

interface ICarPart is IERC1155MetadataURI, IERC1155Errors {
    error CarPartInvalidPart(Part part);

    error CarPartInvalidPartId(uint256 partId);

    function mint(address to, uint256 id) external;

    function burn(address from, uint256 id) external;

    function batchMint(address to, uint256[] memory ids) external;

    function batchBurn(address from, uint256[] memory ids) external;

    function addParts(Part[] memory parts) external;

    function partOf(uint256 partId) external view returns (Part memory);

    function partsOf(
        uint256[] memory partIds
    ) external view returns (Part[] memory);
}
