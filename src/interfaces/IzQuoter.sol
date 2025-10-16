//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IzQuoter {
    enum AMM {
        UNI_V2,
        AERO,
        ZAMM,
        UNI_V3,
        UNI_V4,
        AERO_CL
    }

    struct Quote {
        AMM source;
        uint256 feeBps;
        uint256 amountIn;
        uint256 amountOut;
    }

    function buildBestSwap(
        address to,
        bool exactOut,
        address tokenIn,
        address tokenOut,
        uint256 swapAmount,
        uint256 slippageBps,
        uint256 deadline
    ) external view returns (Quote memory best, bytes memory callData, uint256 amountLimit, uint256 msgValue);

    function buildBestSwapViaETHMulticall(
        address to,
        address refundTo,
        bool exactOut,
        address tokenIn,
        address tokenOut,
        uint256 swapAmount,
        uint256 slippageBps,
        uint256 deadline
    )
        external
        view
        returns (Quote memory a, Quote memory b, bytes[] memory calls, bytes memory multicall, uint256 msgValue);
}
