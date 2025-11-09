//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ISwapSwap} from "./interfaces/ISwapSwap.sol";
import {IzRouter} from "./interfaces/IzRouter.sol";

contract SwapSwap is AccessControl, ISwapSwap, Initializable {
    using SafeERC20 for IERC20;

    ISwapSwap.InitParams public initParams;

    bytes32 public constant EXECUTOR = keccak256("EXECUTOR");

    modifier isZeroAddress(address _address) {
        _isZeroAddress(_address);
        _;
    }

    function initialize(bytes calldata data) external initializer {
        initParams = abi.decode(data, (ISwapSwap.InitParams));

        _grantRole(DEFAULT_ADMIN_ROLE, initParams.admin);
    }

    function setRouter(
        address _zRouter
    ) external isZeroAddress(_zRouter) onlyRole(DEFAULT_ADMIN_ROLE) {
        initParams.zRouter = _zRouter;

        emit SwapSwap__zRouterUpdated(_zRouter);
    }

    function setApproval(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) isZeroAddress(token) {
        IERC20(token).forceApprove(initParams.zRouter, amount);
    }

    function executeCallDataSwap(
        bytes calldata data,
        uint256 msgValue
    ) external onlyRole(EXECUTOR) {
        bool success;
        bytes memory returnedData;

        if (msgValue == 0) {
            (success, returnedData) = initParams.zRouter.call(data);
        } else {
            (success, returnedData) = initParams.zRouter.call{value: msgValue}(
                data
            );
        }

        if (!success) {
            revert SwapSwap__SwapFailed(returnedData);
        }

        emit SwapSwap__CallDataSwapExecuted(data, returnedData);
    }

    function executeSwap(bytes calldata data) external onlyRole(EXECUTOR) {
        (
            address user,
            bool stable,
            address tokenIn,
            uint256 swapAmount,
            uint256 amountLimit,
            uint256 deadline
        ) = abi.decode(
                data,
                (address, bool, address, uint256, uint256, uint256)
            );

        address tokenOut = tokenIn == initParams.token
            ? initParams.usdc
            : initParams.token;
        uint256 amountIn;
        uint256 amountOut;

        if (tokenIn == address(0)) {
            (amountIn, amountOut) = IzRouter(initParams.zRouter).swapAero{
                value: swapAmount
            }({
                to: user,
                stable: stable,
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                swapAmount: swapAmount,
                amountLimit: amountLimit,
                deadline: deadline
            });
        } else {
            (amountIn, amountOut) = IzRouter(initParams.zRouter).swapAero({
                to: user,
                stable: stable,
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                swapAmount: swapAmount,
                amountLimit: amountLimit,
                deadline: deadline
            });
        }

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
        ) = abi.decode(
                data,
                (
                    address,
                    bool,
                    int24,
                    address,
                    address,
                    uint256,
                    uint256,
                    uint256
                )
            );

        uint256 amountIn;
        uint256 amountOut;

        if (tokenIn == address(0)) {
            (amountIn, amountOut) = IzRouter(initParams.zRouter).swapAeroCL{
                value: swapAmount
            }(
                to,
                exactOut,
                tickSpacing,
                tokenIn,
                tokenOut,
                swapAmount,
                amountLimit,
                deadline
            );
        } else {
            (amountIn, amountOut) = IzRouter(initParams.zRouter).swapAeroCL(
                to,
                exactOut,
                tickSpacing,
                tokenIn,
                tokenOut,
                swapAmount,
                amountLimit,
                deadline
            );
        }
        emit SwapSwap__SwapExecuted(tokenIn, amountIn, amountOut);
    }

    function recoverToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance == 0) {
            revert SwapSwap__ZeroBalance();
        }

        IERC20(token).safeTransfer(initParams.admin, balance);
        emit SwapSwap__TokenRecovered(token);
    }

    function recoverEth() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 ethBalance = address(this).balance;
        if (ethBalance <= 0) {
            revert SwapSwap__ZeroBalance();
        }

        (bool success, ) = initParams.admin.call{value: ethBalance}("");
        if (!success) {
            revert SwapSwap__ETHTransferFailed();
        }

        emit SwapSwap__ETHRecovered();
    }

    receive() external payable {}

    function _isZeroAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert SwapSwap__ZeroAddress();
        }
    }
}
