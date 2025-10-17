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
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant AERO_IMPLEMENTATION = 0xA4e46b4f701c62e14DF11B48dCe76A7d793CD6d7;

    address constant AERO_CL_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address constant AERO_CL_IMPLEMENTATION = 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831;

    address public constant BASE_ZROUTER = 0x0000000000404FECAf36E6184245475eE1254835;
    address public constant BASE_zQUOTER = 0x772E2810A471dB2CC7ADA0d37D6395476535889a;

    address public constant ETH = address(0);
    address public constant ADMIN = 0xD1AD5A61768d745aCE465e0cfD4acd039cA95025; // swapswap_admin
    address public constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_WETH = 0x4200000000000000000000000000000000000006;
    address public constant BASE_DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address public constant BASE_CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public constant BASE_NOICE = 0x9Cb41FD9dC6891BAe8187029461bfAADF6CC0C69;

    string public salt = "token.swapswap.eth";

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
        } else if (asset == ETH) {
            // Using WETH price feed because swapAero uses WETH for the tokenIn/tokenOut if its ETH (address(0))
            priceFeed = 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;
        } else {
            priceFeed = 0;
        }
    }

    function checkIfCLPoolExists(address tokenA, address tokenB, int24 tickSpacing) public view returns (bool) {
        if (tokenA == address(0)) tokenA = BASE_WETH;
        if (tokenB == address(0)) tokenB = BASE_WETH;

        (address pool,) = _aeroCLPoolFor(tokenA, tokenB, tickSpacing);

        return pool.code.length != 0;
    }

    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1, bool zeroForOne)
    {
        (token0, token1) = (zeroForOne = tokenA < tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _aeroPoolFor(address tokenA, address tokenB, bool stable)
        internal
        pure
        returns (address aeroPool, bool zeroForOne)
    {
        (address token0, address token1, bool zF1) = _sortTokens(tokenA, tokenB);
        zeroForOne = zF1;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable));
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), AERO_FACTORY)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), AERO_IMPLEMENTATION)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            aeroPool := keccak256(add(ptr, 0x43), 0x55)
        }
    }

    function _aeroCLPoolFor(address tokenA, address tokenB, int24 tickSpacing)
        internal
        pure
        returns (address aeroCLPool, bool zeroForOne)
    {
        (address token0, address token1, bool zF1) = _sortTokens(tokenA, tokenB);
        zeroForOne = zF1;
        bytes32 salt = keccak256(abi.encode(token0, token1, tickSpacing));
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, AERO_CL_IMPLEMENTATION))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, AERO_CL_FACTORY))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            aeroCLPool := keccak256(add(ptr, 0x37), 0x55)
        }
    }
}
