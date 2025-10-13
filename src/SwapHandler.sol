//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Useful for debugging. Remove when deploying to a live network.
import "forge-std/console.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IzRouter } from "./zRouter/IzRouter.sol";

contract SwapHandler is AccessControl {
    error SwapHandler__ZeroBalance();
    error SwapHandler__TransferFailed(address token);
    error SwapHandler__ZeroAddress();
    error SwapHandler__ETHTransferFailed();

    event SwapHandler__AeroRouterUpdated(address indexed _aeroRouter);
    event SwapHandler__TokenRecovered(address indexed token);
    event SwapHandler__ETHRecovered();
    event SwapHandler__SwapExecuted(address indexed tokenIn, uint256 indexed amountIn, uint256 indexed amountOut);

    bytes32 public constant EXECUTOR = keccak256("EXECUTOR");

    address public immutable i_USDC;
    address public immutable i_WETH;
    address public immutable i_DAI;
    address public immutable i_admin;
    address public immutable i_token;
    address public s_aeroRouter;

    constructor(address _token, address _router, address _usdc, address _weth, address _dai, address _admin) {
        i_USDC = _usdc;
        i_WETH = _weth;
        i_DAI = _dai;
        i_admin = _admin;
        s_aeroRouter = _router;
        i_token = _token;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function setRouter(address _aeroRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_aeroRouter == address(0)) {
            revert SwapHandler__ZeroAddress();
        }

        s_aeroRouter = _aeroRouter;

        emit SwapHandler__AeroRouterUpdated(_aeroRouter);
    }

    function executeSwap(bytes calldata data) external onlyRole(EXECUTOR) {
        (
            address to,
            bool stable,
            address tokenIn,
            address tokenOut,
            uint256 swapAmount,
            uint256 amountLimit,
            uint256 deadline
        ) = abi.decode(data, (address, bool, address, address, uint256, uint256, uint256));

        (uint256 amountIn, uint256 amountOut) =
            IzRouter(s_aeroRouter).swapAero(to, stable, tokenIn, tokenOut, swapAmount, amountLimit, deadline);

        emit SwapHandler__SwapExecuted(tokenIn, amountIn, amountOut);
    }

    function executeCLSwap(bytes calldata data) external onlyRole(EXECUTOR) {
        (
            address to,
            bool exactOut,
            int24 tickSpacing,
            address tokenIn,
            address tokenOut,
            uint256 swapAmount,
            uint256 amountLimit,
            uint256 deadline
        ) = abi.decode(data, (address, bool, int24, address, address, uint256, uint256, uint256));

        (uint256 amountIn, uint256 amountOut) = IzRouter(s_aeroRouter).swapAeroCL(
            to, exactOut, tickSpacing, tokenIn, tokenOut, swapAmount, amountLimit, deadline
        );

        emit SwapHandler__SwapExecuted(tokenIn, amountIn, amountOut);
    }

    function recoverToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (IERC20(token).balanceOf(address(this)) < 0) {
            revert SwapHandler__ZeroBalance();
        }

        uint256 balance = IERC20(token).balanceOf(address(this));

        bool success = IERC20(token).transfer(i_admin, balance);

        if (!success) {
            revert SwapHandler__TransferFailed(token);
        }

        emit SwapHandler__TokenRecovered(token);
    }

    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(this).balance < 0) {
            revert SwapHandler__ZeroBalance();
        }

        (bool success,) = msg.sender.call{ value: address(this).balance }("");
        if (!success) {
            revert SwapHandler__ETHTransferFailed();
        }

        emit SwapHandler__ETHRecovered();
    }

    receive() external payable { }
}
