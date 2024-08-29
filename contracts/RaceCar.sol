// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {ICarPart, Part} from "./interfaces/ICarPart.sol";
import {IRaceCar} from "./interfaces/IRaceCar.sol";
import {ICarFactory} from "./interfaces/ICarFactory.sol";

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract RaceCar is IRaceCar, ERC721, AccessControl {
    bytes32 public constant CAR_FACTORY_ROLE = keccak256("CAR_FACTORY_ROLE");

    // carId => partIds
    mapping(uint256 => uint256[]) private _partsOf;

    address private _carPart;

    uint256 private _maxTokenId;

    constructor(
        string memory name_,
        string memory symbol_,
        address carFactoryAddress_,
        address carPartAddress_
    ) ERC721(name_, symbol_) {
        _carPart = carPartAddress_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CAR_FACTORY_ROLE, carFactoryAddress_);

        _setRoleAdmin(CAR_FACTORY_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function mint(
        address to,
        uint256[] memory partIds
    ) external override onlyRole(CAR_FACTORY_ROLE) returns (uint256 tokenId) {
        for (uint256 i = 0; i < partIds.length; i++) {
            if (ICarPart(_carPart).partOf(partIds[i]).id == 0) {
                revert RaceCarInvalidPartId(partIds[i]);
            }
        }

        tokenId = ++_maxTokenId;
        _safeMint(to, tokenId);
        _partsOf[tokenId] = partIds;
    }

    function burn(
        uint256 tokenId
    ) external override onlyRole(CAR_FACTORY_ROLE) {
        _burn(tokenId);
        delete _partsOf[tokenId];
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, IERC721Metadata) returns (string memory) {
        _requireOwned(tokenId);
        uint256[] memory partIds = _partsOf[tokenId];
        Part[] memory parts = ICarPart(_carPart).partsOf(partIds);
        string memory svgImage = '<svg xmlns="http://www.w3.org/2000/svg">';
        string memory jsonParts = "[";
        for (uint i = 0; i < parts.length; i++) {
            svgImage = string(
                abi.encodePacked(
                    svgImage,
                    '<image href="',
                    parts[i].image,
                    '" />'
                )
            );
            if (i > 0) {
                jsonParts = string(abi.encodePacked(jsonParts, ","));
            }
            jsonParts = string(
                abi.encodePacked(
                    jsonParts,
                    '{"type":"',
                    parts[i].partType,
                    '","name":"',
                    parts[i].name,
                    '","rareLevel":',
                    Strings.toString(parts[i].rareLevel),
                    "}"
                )
            );
        }
        svgImage = string(abi.encodePacked(svgImage, "</svg>"));
        jsonParts = string(abi.encodePacked(jsonParts, "]"));
        string memory json = string(
            abi.encodePacked(
                '{"name": "',
                name(),
                " #",
                Strings.toString(tokenId),
                '", "description": "',
                symbol(),
                ' NFT",',
                '"image": "data:image/svg+xml;base64,',
                Base64.encode(bytes(svgImage)),
                '",',
                '"parts": ',
                jsonParts,
                "}"
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

    function partsOf(
        uint256 tokenId
    ) external view returns (uint256[] memory partIds) {
        _requireOwned(tokenId);
        return _partsOf[tokenId];
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl, IERC165) returns (bool) {
        return
            interfaceId == type(IRaceCar).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
