//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IzRouter} from "./interfaces/IzRouter.sol";
import {ISwapSwap} from "./interfaces/ISwapSwap.sol";

contract SwapSwap is AccessControl, ISwapSwap {
    using SafeERC20 for IERC20;

    bytes32 public constant EXECUTOR = keccak256("EXECUTOR");

    address public immutable i_USDC;
    address public immutable i_WETH;
    address public immutable i_DAI;
    address public immutable i_admin;
    address public immutable i_token;
    IzRouter public s_zRouter;

    constructor(address _token, address _router, address _usdc, address _weth, address _dai, address _admin) {
        if (_router == address(0)) {
            revert SwapSwap__ZeroAddress();
        }

        s_zRouter = IzRouter(_router);

        i_USDC = _usdc;
        i_WETH = _weth;
        i_DAI = _dai;
        i_admin = _admin;
        i_token = _token;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    modifier isZeroAddress(address _address) {
        if (_address == address(0)) {
            revert SwapSwap__ZeroAddress();
        }

        _;
    }

    function setRouter(address _zRouter) external isZeroAddress(_zRouter) onlyRole(DEFAULT_ADMIN_ROLE) {
        s_zRouter = IzRouter(_zRouter);

        emit SwapSwap__zRouterUpdated(_zRouter);
    }

    function setApproval(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) isZeroAddress(token) {
        if (!IERC20(token).approve(address(s_zRouter), amount)) {
            revert SwapSwap__SetApprovalFailed(token, amount);
        }
    }

    function executeSwap(bytes calldata data) external onlyRole(EXECUTOR) {
        (address user, bool stable, address tokenIn, uint256 swapAmount, uint256 amountLimit, uint256 deadline) =
            abi.decode(data, (address, bool, address, uint256, uint256, uint256));

        address tokenOut = tokenIn == i_token ? i_USDC : i_token;

        (uint256 amountIn, uint256 amountOut) = s_zRouter.swapAero({
            to: user,
            stable: stable,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            swapAmount: swapAmount,
            amountLimit: amountLimit,
            deadline: deadline
        });

        emit SwapSwap__SwapExecuted(tokenIn, amountIn, amountOut);
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

        (uint256 amountIn, uint256 amountOut) =
            s_zRouter.swapAeroCL(to, exactOut, tickSpacing, tokenIn, tokenOut, swapAmount, amountLimit, deadline);

        emit SwapSwap__SwapExecuted(tokenIn, amountIn, amountOut);
    }

    function recoverToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (IERC20(token).balanceOf(address(this)) == 0) {
            revert SwapSwap__ZeroBalance();
        }

        uint256 balance = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(i_admin, balance);
        emit SwapSwap__TokenRecovered(token);
    }

    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(this).balance <= 0) {
            revert SwapSwap__ZeroBalance();
        }

        (bool success,) = msg.sender.call{value: address(this).balance}("");
        if (!success) {
            revert SwapSwap__ETHTransferFailed();
        }

        emit SwapSwap__ETHRecovered();
    }

    receive() external payable {}
}
