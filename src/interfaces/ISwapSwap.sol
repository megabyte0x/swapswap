//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ISwapSwap {
    error SwapSwap__ZeroBalance();
    error SwapSwap__ZeroAddress();
    error SwapSwap__ETHTransferFailed();
    error SwapSwap__SetApprovalFailed(address token, uint256 amount);

    event SwapSwap__zRouterUpdated(address indexed _zRouter);
    event SwapSwap__TokenRecovered(address indexed token);
    event SwapSwap__ETHRecovered();
    event SwapSwap__SwapExecuted(address indexed tokenIn, uint256 indexed amountIn, uint256 indexed amountOut);

    function setApproval(address token, uint256 amount) external;

    function setRouter(address _zRouter) external;

    function executeSwap(bytes calldata data) external;

    function executeCLSwap(bytes calldata data) external;

    function recoverToken(address token) external;

    function recoverETH() external;
}
