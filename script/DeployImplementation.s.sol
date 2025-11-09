// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {SwapSwap} from "../src/SwapSwap.sol";

contract DeployImplementation is Script {
    function run() external returns (address) {
        return address(new SwapSwap());
    }
}
