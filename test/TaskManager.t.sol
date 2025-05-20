// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TaskManager} from "../src/TaskManager.sol"; // Import your contract

contract TaskManagerTest is Test {
    TaskManager public taskManager;

    function setUp() public {
        taskManager = new TaskManager();
    }

    function test_Deployment() public view {
        address owner = taskManager.owner();
        assertTrue(owner != address(0), "Owner should not be the zero address");
    }
}
