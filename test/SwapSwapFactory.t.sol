// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";

import {HelperConfig} from "../script/HelperConfig.s.sol";
import {SwapSwapFactory} from "../src/SwapSwapFactory.sol";

contract SwapSwapFactoryTest is Test {
    SwapSwapFactory factory;
    HelperConfig helperConfig;

    address public admin;
    address public zRouter;
    address public usdc;
    address public weth;
    address public dai;

    function setUp() public {
        helperConfig = new HelperConfig();

        (zRouter, usdc, weth, dai) = helperConfig.networkConfig();
        admin = helperConfig.ADMIN();
        factory = new SwapSwapFactory(admin, zRouter, usdc, weth, dai);
    }

    function testSameDeployment() public {
        address token = helperConfig.BASE_CBBTC();

        vm.startPrank(admin);
        address instance1 = factory.deploySwapSwap(token);
        console.log("BTC Instance: ", instance1);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert();
        address instance2 = factory.deploySwapSwap(token);

        console.log("BTC Instance2: ", instance2);
    }
}
