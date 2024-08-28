// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC165} from "./interfaces/IERC165.sol";
import {IERC721Metadata} from "./interfaces/IERC721Metadata.sol";
import {IERC721Errors} from "./interfaces/IERC721Errors.sol";
import {IERC721Receiver} from "./interfaces/IERC721Receiver.sol";
import {IGameController} from "./interfaces/IGameController.sol";
import {Base64} from "./libraries/Base64.sol";
import {Strings} from "./libraries/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NeonShiftERC721 is IERC721Metadata, IERC721Errors, Ownable {
    string private _name;
    string private _symbol;

    mapping(address => uint256) private _balanceOf;
    mapping(uint256 => address) private _owners;
    mapping(uint256 => address) private _approvals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    uint256 private _maxTokenId;

    modifier validAddress(address addr) {
        if (addr == address(0)) {
            revert ERC721InvalidOwner(addr);
        }
        _;
    }

    modifier validToken(uint256 tokenId) {
        if (_owners[tokenId] == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        _;
    }

    modifier tokenOwnerOnly(uint256 tokenId) {
        address owner = _owners[tokenId];
        if (msg.sender != owner) {
            revert ERC721InvalidApprover(msg.sender);
        }
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address gameControllerAddress_
    ) Ownable(gameControllerAddress_) {
        _name = name_;
        _symbol = symbol_;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external validAddress(from) validAddress(to) validToken(tokenId) {
        _transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external validAddress(from) validAddress(to) validToken(tokenId) {
        _safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external validAddress(from) validAddress(to) validToken(tokenId) {
        _safeTransferFrom(from, to, tokenId, data);
    }

    function approve(
        address to,
        uint256 tokenId
    ) external validAddress(to) validToken(tokenId) tokenOwnerOnly(tokenId) {
        address owner = _owners[tokenId];
        _approvals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) external validAddress(operator) {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function mint(address to) external onlyOwner validAddress(to) {
        uint256 tokenId = ++_maxTokenId;
        _balanceOf[to]++;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function burn(uint256 tokenId) external onlyOwner validToken(tokenId) {
        address owner = _owners[tokenId];
        _balanceOf[owner]--;
        delete _owners[tokenId];
        delete _approvals[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    function balanceOf(
        address owner
    ) external view validAddress(owner) returns (uint256) {
        return _balanceOf[owner];
    }

    function getApproved(
        uint256 tokenId
    ) external view validToken(tokenId) returns (address) {
        return _approvals[tokenId];
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) external view validAddress(owner) validAddress(operator) returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function ownerOf(
        uint256 tokenId
    ) external view validToken(tokenId) returns (address) {
        return _owners[tokenId];
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(
        uint256 tokenId
    ) external view override validToken(tokenId) returns (string memory) {
        IGameController gameController = IGameController(owner());
        IGameController.Part[] memory parts = gameController.partsOf(tokenId);
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
                _name,
                " #",
                Strings.toString(tokenId),
                '", "description": "',
                _symbol,
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

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        _transferFrom(from, to, tokenId);

        if (to.code.length != 0) {
            bool success = IERC721Receiver(to).onERC721Received(
                msg.sender,
                from,
                tokenId,
                data
            ) == IERC721Receiver.onERC721Received.selector;
            if (!success) {
                revert ERC721InvalidReceiver(to);
            }
        }
    }

    function _transferFrom(address from, address to, uint256 tokenId) internal {
        address owner = _owners[tokenId];
        if (owner != from) {
            revert ERC721IncorrectOwner(from, tokenId, owner);
        }

        bool isApprovedOrOwner = (msg.sender == owner) ||
            (msg.sender == _approvals[tokenId]) ||
            _operatorApprovals[owner][msg.sender];
        if (!isApprovedOrOwner) {
            revert ERC721InsufficientApproval(msg.sender, tokenId);
        }

        _balanceOf[from]--;
        _balanceOf[to]++;
        _owners[tokenId] = to;
        delete _approvals[tokenId];

        emit Transfer(from, to, tokenId);
    }
}
