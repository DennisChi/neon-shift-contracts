// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {IERC1155} from "./interfaces/IERC1155.sol";
import {IERC1155MetadataURI} from "./interfaces/IERC1155MetadataURI.sol";
import {IERC1155Errors} from "./interfaces/IERC1155Errors.sol";
import {IERC1155Receiver} from "./interfaces/IERC1155Receiver.sol";
import {Ownable} from "./access/Ownable.sol";
import {IGameController} from "./interfaces/IGameController.sol";
import {Base64} from "./libraries/Base64.sol";
import {Strings} from "./libraries/Strings.sol";

contract NeonShiftERC1155 is IERC1155MetadataURI, IERC1155Errors, Ownable {
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(address => mapping(uint256 => uint256)) private _balances;

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

    constructor(
        address gameControllerAddress_
    ) Ownable(gameControllerAddress_) {}

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

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount);
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function burn(address from, uint256 id, uint256 amount) external onlyOwner {
        _burn(from, id, amount);
        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    )
        external
        onlyOwner
        validReceiver(to)
        validArrayLength(ids.length, amounts.length)
    {
        for (uint256 i = 0; i < ids.length; i++) {
            _mint(to, ids[i], amounts[i]);
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    function batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyOwner validArrayLength(ids.length, amounts.length) {
        for (uint256 i = 0; i < ids.length; i++) {
            _burn(from, ids[i], amounts[i]);
        }
        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
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
        IGameController gameController = IGameController(owner());
        IGameController.Part memory part = gameController.partOf(id);
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
    ) external pure override returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId;
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

    function _mint(
        address to,
        uint256 id,
        uint256 amount
    ) internal validReceiver(to) {
        _balances[to][id] += amount;
    }

    function _burn(address from, uint256 id, uint256 amount) internal {
        uint256 fromBalance = _balances[from][id];
        if (fromBalance < amount) {
            revert ERC1155InsufficientBalance(from, fromBalance, amount, id);
        }
        unchecked {
            _balances[from][id] = fromBalance - amount;
        }
    }
}
