// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {SwapSwap} from "../src/SwapSwap.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySwapSwap is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        (address zRouter, address usdc, address weth, address dai) = helperConfig.networkConfig();
        address token = helperConfig.BASE_CBBTC();
        new SwapSwap(zRouter, token, usdc, weth, dai, helperConfig.ADMIN());
    }
}
