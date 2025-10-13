//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

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
    address public constant BASE_CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    constructor() {
        if (block.chainid == 8453) {
            setBaseConfig();
        }
    }

    function setBaseConfig() public {
        networkConfig = Config({zRouter: BASE_ZROUTER, usdc: BASE_USDC, weth: BASE_WETH, dai: BASE_DAI});
    }

    function getPriceFeed(address asset) public pure returns (bytes32 priceFeed) {
        if (asset == BASE_WETH) {
            priceFeed = 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;
        } else if (asset == BASE_DAI) {
            priceFeed = 0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;
        } else if (asset == BASE_USDC) {
            priceFeed = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        } else if (asset == BASE_CBBTC) {
            priceFeed = 0x2817d7bfe5c64b8ea956e9a26f573ef64e72e4d7891f2d6af9bcc93f7aff9a97;
        } else {
            priceFeed = 0;
        }
    }
}
