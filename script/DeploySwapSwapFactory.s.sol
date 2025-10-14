// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {SwapSwapFactory} from "../src/SwapSwapFactory.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySwapSwapFactory is Script {
    function deployFactoryWithConfig(address admin, address zRouter, address usdc, address weth, address dai) public {
        vm.startBroadcast();
        SwapSwapFactory factory = new SwapSwapFactory(admin, zRouter, usdc, weth, dai);
        vm.stopBroadcast();

        console.log("Factory contract deployed at: ", address(factory));
    }

    function deployFactory() public {
        HelperConfig helperConfig = new HelperConfig();
        (address zRouter, address usdc, address weth, address dai) = helperConfig.networkConfig();

        deployFactoryWithConfig(helperConfig.ADMIN(), zRouter, usdc, weth, dai);
    }

    function run() external {
        deployFactory();
    }
}
