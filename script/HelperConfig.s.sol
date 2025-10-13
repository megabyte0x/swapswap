//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct Config {
        address zRouter;
        address usdc;
        address weth;
        address dai;
    }

    Config public networkConfig;

    address public constant ADMIN = address(1);
    address public constant BASE_ZROUTER = 0x0000000000404FECAf36E6184245475eE1254835;
    address public constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_WETH = 0x4200000000000000000000000000000000000006;
    address public constant BASE_DAI = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    constructor() {
        if (block.chainid == 8453) {
            setBaseConfig();
        }
    }

    function setBaseConfig() public {
        networkConfig = Config({ zRouter: BASE_ZROUTER, usdc: BASE_USDC, weth: BASE_WETH, dai: BASE_DAI });
    }
}
