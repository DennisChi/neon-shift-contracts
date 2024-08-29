// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {ICarPart, Part} from "./interfaces/ICarPart.sol";
import {ICarFactory} from "./interfaces/ICarFactory.sol";

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract CarPart is ICarPart, ERC1155, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTABLE_ROLE = keccak256("MINTABLE_ROLE");
    bytes32 public constant BURNABLE_ROLE = keccak256("BURNABLE_ROLE");

    bytes32 public constant PART_TYPES =
        keccak256("Lighting") |
            keccak256("Painting") |
            keccak256("Engine") |
            keccak256("Tires");

    mapping(uint256 => Part) private _partOf;

    constructor() ERC1155("") {
        _grantRole(ADMIN_ROLE, msg.sender);

        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MINTABLE_ROLE, ADMIN_ROLE);
        _setRoleAdmin(BURNABLE_ROLE, ADMIN_ROLE);
    }

    function mint(
        address to,
        uint256 id
    ) external override onlyRole(MINTABLE_ROLE) {
        if (_partOf[id].id == 0) {
            revert CarPartInvalidPartId(id);
        }

        _mint(to, id, 1, "");
    }

    function burn(
        address from,
        uint256 id
    ) external override onlyRole(BURNABLE_ROLE) {
        _burn(from, id, 1);
    }

    function batchMint(
        address to,
        uint256[] memory ids
    ) external override onlyRole(MINTABLE_ROLE) {
        for (uint256 i = 0; i < ids.length; i++) {
            if (_partOf[ids[i]].id == 0) {
                revert CarPartInvalidPartId(ids[i]);
            }
        }
        uint256[] memory amounts = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            amounts[i] = 1;
        }
        _mintBatch(to, ids, amounts, "");
    }

    function batchBurn(
        address from,
        uint256[] memory ids
    ) external override onlyRole(BURNABLE_ROLE) {
        uint256[] memory amounts = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            amounts[i] = 1;
        }
        _burnBatch(from, ids, amounts);
    }

    function addParts(Part[] memory parts) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < parts.length; i++) {
            Part memory part = parts[i];
            if (part.rareLevel < 1 || part.rareLevel > 4) {
                revert CarPartInvalidPart(part);
            }
            bytes32 partType = keccak256(bytes(part.partType));
            bytes32 selectedPartType = PART_TYPES & partType;
            if (partType != selectedPartType) {
                revert CarPartInvalidPart(part);
            }

            uint256 partId = uint256(
                keccak256(
                    abi.encodePacked(
                        part.name,
                        part.partType,
                        part.rareLevel,
                        part.image
                    )
                )
            );
            part.id = partId;
            _partOf[partId] = part;
        }
    }

    function partOf(uint256 tokenId) external view returns (Part memory part) {
        return _partOf[tokenId];
    }

    function partsOf(
        uint256[] memory partIds
    ) external view returns (Part[] memory parts) {
        parts = new Part[](partIds.length);
        for (uint256 i = 0; i < partIds.length; i++) {
            parts[i] = _partOf[partIds[i]];
        }
        return parts;
    }

    function uri(
        uint256 id
    )
        public
        view
        override(ERC1155, IERC1155MetadataURI)
        returns (string memory)
    {
        Part memory part = _partOf[id];
        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                part.name,
                '","type":"',
                part.partType,
                " - Rare Level: ",
                Strings.toString(part.rareLevel),
                '","image":"',
                part.image,
                '"}'
            )
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(json))
                )
            );
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControl, ERC1155, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(ICarPart).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
