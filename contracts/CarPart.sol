// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {ICarPart, Part} from "./interfaces/ICarPart.sol";
import {ICarFactory} from "./interfaces/ICarFactory.sol";

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract CarPart is ICarPart, AccessControl {
    bytes32 public constant CAR_FACTORY_ROLE = keccak256("CAR_FACTORY_ROLE");

    bytes32 public constant PART_TYPES =
        keccak256("Lighting") |
            keccak256("Painting") |
            keccak256("Engine") |
            keccak256("Tires");

    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(address => mapping(uint256 => uint256)) private _balances;
    mapping(uint256 => Part) private _partOf;

    modifier validSender(address sender) {
        if (sender == address(0)) {
            revert ERC1155InvalidSender(sender);
        }
        _;
    }

    modifier validReceiver(address receiver) {
        if (receiver == address(0)) {
            revert ERC1155InvalidReceiver(receiver);
        }
        _;
    }

    modifier validApprovalForAll(address operator) {
        if (
            operator != msg.sender && !_operatorApprovals[msg.sender][operator]
        ) {
            revert ERC1155MissingApprovalForAll(operator, msg.sender);
        }
        _;
    }

    modifier validOperator(address operator) {
        if (operator == address(0)) {
            revert ERC1155InvalidOperator(operator);
        }
        _;
    }

    modifier validArrayLength(uint256 idsLength, uint256 valuesLength) {
        if (idsLength != valuesLength) {
            revert ERC1155InvalidArrayLength(idsLength, valuesLength);
        }
        _;
    }

    constructor(address carFactoryAddress_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CAR_FACTORY_ROLE, carFactoryAddress_);

        _setRoleAdmin(CAR_FACTORY_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) external validOperator(operator) {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        external
        validSender(from)
        validReceiver(to)
        validApprovalForAll(msg.sender)
    {
        _safeTransferFrom(from, to, id, amount);

        if (to.code.length != 0) {
            bool success = IERC1155Receiver(to).onERC1155Received(
                msg.sender,
                from,
                id,
                amount,
                data
            ) == IERC1155Receiver.onERC1155Received.selector;
            if (!success) {
                revert ERC1155InvalidReceiver(to);
            }
        }

        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        external
        validSender(from)
        validReceiver(to)
        validApprovalForAll(msg.sender)
        validArrayLength(ids.length, amounts.length)
    {
        for (uint256 i = 0; i < ids.length; i++) {
            _safeTransferFrom(from, to, ids[i], amounts[i]);
        }

        if (to.code.length != 0) {
            bool success = IERC1155Receiver(to).onERC1155BatchReceived(
                msg.sender,
                from,
                ids,
                amounts,
                data
            ) == IERC1155Receiver.onERC1155BatchReceived.selector;
            if (!success) {
                revert ERC1155InvalidReceiver(to);
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    function mint(
        address to,
        uint256 id
    ) external override onlyRole(CAR_FACTORY_ROLE) validReceiver(to) {
        _mint(to, id);
        emit TransferSingle(msg.sender, address(0), to, id, 1);
    }

    function burn(
        address from,
        uint256 id
    ) external override onlyRole(CAR_FACTORY_ROLE) validReceiver(from) {
        _burn(from, id);
        emit TransferSingle(msg.sender, from, address(0), id, 1);
    }

    function batchMint(
        address to,
        uint256[] memory ids
    ) external override onlyRole(CAR_FACTORY_ROLE) validReceiver(to) {
        for (uint256 i = 0; i < ids.length; i++) {
            _mint(to, ids[i]);
        }
        uint256[] memory amounts = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            amounts[i] = 1;
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    function batchBurn(
        address from,
        uint256[] memory ids
    ) external override onlyRole(CAR_FACTORY_ROLE) validReceiver(from) {
        for (uint256 i = 0; i < ids.length; i++) {
            _burn(from, ids[i]);
        }
        uint256[] memory amounts = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            amounts[i] = 1;
        }
        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function addParts(Part[] memory parts) external {
        if (
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender) &&
            !hasRole(CAR_FACTORY_ROLE, msg.sender)
        ) {
            revert AccessControlUnauthorizedAccount(
                msg.sender,
                DEFAULT_ADMIN_ROLE | CAR_FACTORY_ROLE
            );
        }
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

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256) {
        return _balances[account][id];
    }

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) external view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](accounts.length);
        unchecked {
            for (uint256 i = 0; i < accounts.length; i++) {
                balances[i] = _balances[accounts[i]][ids[i]];
            }
        }
        return balances;
    }

    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function uri(uint256 id) external view returns (string memory) {
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl, IERC165) returns (bool) {
        return
            interfaceId == type(ICarPart).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) internal {
        uint256 fromBalance = _balances[from][id];
        if (fromBalance < amount) {
            revert ERC1155InsufficientBalance(from, fromBalance, amount, id);
        }

        unchecked {
            _balances[from][id] = fromBalance - amount;
        }
        _balances[to][id] += amount;
    }

    function _mint(address to, uint256 id) internal validReceiver(to) {
        _balances[to][id] += 1;
    }

    function _burn(address from, uint256 id) internal {
        uint256 fromBalance = _balances[from][id];
        if (fromBalance == 0) {
            revert ERC1155InsufficientBalance(from, fromBalance, 0, id);
        }
        unchecked {
            _balances[from][id] = fromBalance - 1;
        }
    }
}
