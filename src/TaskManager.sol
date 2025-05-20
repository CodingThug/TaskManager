// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TaskManager {
    address public owner;
    uint256 nextId = 1;

    mapping(address => Task[]) public userTasks;

    struct Task {
        uint256 userId;
        address personPostingTask;
        string nameOfPersonCreatingTask;
        string titleOfTask;
        string bodyOfTask;
        uint256 createdAt;
        bool taskComplete;
    }

    constructor() {
        owner = msg.sender;
    }
}
