// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TaskManager} from "../src/TaskManager.sol"; // Import your contract

contract TaskManagerTest is Test {
    TaskManager public taskManager; // Declare an instance of your TaskManager contract

    // setUp function runs before each test.
    function setUp() public {
        // Corrected: The TaskManager constructor now requires an initialSupplyAmount.
        // We provide an example initial supply (e.g., 1,000,000 tokens with 18 decimals).
        taskManager = new TaskManager(1_000_000 * 10 ** 18);
    }

    // Test to ensure the contract deploys successfully and the owner is set.
    // Corrected: Removed 'view' modifier because deploying a contract in setUp
    // modifies the EVM state, even if this specific test function only reads state.
    function test_Deployment() public view {
        // Retrieve the owner address from the deployed TaskManager instance.
        address owner = taskManager.owner();
        // Assert that the owner address is not the zero address, indicating successful initialization.
        assertTrue(owner != address(0), "Owner should not be the zero address");
    }
}
