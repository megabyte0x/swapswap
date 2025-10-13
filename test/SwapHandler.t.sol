// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SwapHandler.sol";
import "../script/HelperConfig.s.sol";

contract SwapSwap is Test {
    SwapHandler public swapHandler;
    HelperConfig public helperConfig;

    address public OWNER = makeAddr("OWNER");

    function setUp() public {
        helperConfig = new HelperConfig();

        (address zRouter, address usdc, address weth, address dai) = helperConfig.networkConfig();

        swapHandler = new SwapHandler(zRouter, usdc, weth, dai, OWNER);
    }

    function testGrantExecutorRole() public {
        address test = makeAddr("test");
        bytes32 role = keccak256("EXECUTOR");

        vm.prank(OWNER);
        swapHandler.grantRole(role, test);

        assert(swapHandler.hasRole(role, test));
    }
}
