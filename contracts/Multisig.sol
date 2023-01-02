// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Multisig{
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public immutable numberOfConfirmations;
    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public isConfirmed;

    event Confirmed(uint indexed id, address indexed owner, uint confirmations);

    event Executed(uint indexed id, bytes response);

    event Revoked(uint indexed id, address indexed owner, uint confirmations);

    event Queued(
        uint indexed id,
        address indexed initiator,
        address indexed to,
        uint value,
        bytes data
    );

    modifier onlyOwners(){
        require(isOwner[msg.sender]);
        _;
    }

    constructor(address[] memory _owners, uint _numberOfConfirmations) {
        uint length = _owners.length;
        require(length > 0 && _numberOfConfirmations > 0);
        require(_numberOfConfirmations <= length);

        for (uint i = 0; i < length; i++){
            address nextOwner = _owners[i];

            require(nextOwner != address(0));
            require(!isOwner[nextOwner]);

            isOwner[nextOwner] = true;
            owners.push(nextOwner);
        }

        numberOfConfirmations = _numberOfConfirmations;
    }

    function queue(address _to, uint _value, bytes memory _data) external onlyOwners{
        uint id = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        }));

        emit Queued(id, msg.sender, _to, _value, _data);
    }

    function confirm(uint id) external onlyOwners{
        require(id < transactions.length);
        require(!isConfirmed[id][msg.sender]);

        Transaction storage currentTx = transactions[id];
        require(!currentTx.executed);

        currentTx.confirmations++;
        isConfirmed[id][msg.sender] = true;

        emit Confirmed(id, msg.sender, currentTx.confirmations);
    }

    function revoke(uint id) external onlyOwners{
        require(id < transactions.length);
        require(isConfirmed[id][msg.sender]);

        Transaction storage currentTx = transactions[id];

        require(!currentTx.executed);
        
        currentTx.confirmations--;
        isConfirmed[id][msg.sender] = false;

        emit Revoked(id, msg.sender, currentTx.confirmations);
    }

    function execute(uint id) external onlyOwners{
        require(id < transactions.length);

        Transaction storage currentTx = transactions[id];

        require(!currentTx.executed);
        require(currentTx.confirmations >= numberOfConfirmations);

        currentTx.executed = true;

        (bool success, bytes memory resp) = currentTx.to.call{value: currentTx.value}(currentTx.data);

        require(success);

        emit Executed(id, resp);
    }

    receive() external payable {}
}

contract Demo{
    receive() external payable {}
}