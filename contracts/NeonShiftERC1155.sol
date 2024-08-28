// SPDX-License-Identifier: GLP-3.0-or-later
pragma solidity ^0.8.20;

import {IERC1155} from "./interfaces/IERC1155.sol";
import {IERC1155MetadataURI} from "./interfaces/IERC1155MetadataURI.sol";
import {IERC1155Errors} from "./interfaces/IERC1155Errors.sol";
import {IERC1155Receiver} from "./interfaces/IERC1155Receiver.sol";

contract NeonShiftERC1155 is IERC1155MetadataURI, IERC1155Errors {
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
        // TODO: 实现uri函数
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
}
