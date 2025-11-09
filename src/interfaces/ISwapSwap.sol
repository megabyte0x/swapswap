//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ISwapSwap {
    error SwapSwap__ZeroBalance();
    error SwapSwap__ZeroAddress();
    error SwapSwap__ETHTransferFailed();
    error SwapSwap__SwapFailed(bytes returnedData);

    event SwapSwap__zRouterUpdated(address indexed _zRouter);
    event SwapSwap__TokenRecovered(address indexed token);
    event SwapSwap__ETHRecovered();
    event SwapSwap__SwapExecuted(address indexed tokenIn, uint256 indexed amountIn, uint256 indexed amountOut);
    event SwapSwap__CallDataSwapExecuted(bytes indexed data, bytes indexed returnedData);

    struct InitParams {
        address usdc;
        address dai;
        address weth;
        address admin;
        address token;
        address zRouter;
    }

    function setApproval(address token, uint256 amount) external;

    function setRouter(address _zRouter) external;

    function executeSwap(bytes calldata data) external;

    function executeCLSwap(bytes calldata data) external;

    function executeCallDataSwap(bytes calldata data, uint256 msgValue) external;

    function recoverToken(address token) external;

    function recoverEth() external;

    function initialize(bytes calldata data) external;

    function initParams() external view returns (address, address, address, address, address, address);
}
