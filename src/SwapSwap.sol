//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ISwapSwap} from "./interfaces/ISwapSwap.sol";
import {IzRouter} from "./interfaces/IzRouter.sol";

/// @title SwapSwap
/// @notice Role-gated swap executor that forwards operations to a configured zRouter.
/// @dev Deploy via factory clones and call {initialize} exactly once before using.
contract SwapSwap is AccessControl, ISwapSwap, Initializable {
    using SafeERC20 for IERC20;

    ISwapSwap.InitParams public initParams;

    bytes32 public constant EXECUTOR = keccak256("EXECUTOR");

    /// @dev Guards that rejects zero addresses.
    /// @param _address Address to validate.
    modifier isZeroAddress(address _address) {
        _isZeroAddress(_address);
        _;
    }

    /// @notice Initializes the contract with encoded {ISwapSwap.InitParams}.
    /// @param data ABI-encoded {ISwapSwap.InitParams} struct.
    function initialize(bytes calldata data) external initializer {
        initParams = abi.decode(data, (ISwapSwap.InitParams));

        _grantRole(DEFAULT_ADMIN_ROLE, initParams.admin);
    }

    /// @notice Updates the zRouter contract used for future swaps.
    /// @param _zRouter Address of the router implementation.
    function setRouter(address _zRouter) external isZeroAddress(_zRouter) onlyRole(DEFAULT_ADMIN_ROLE) {
        initParams.zRouter = _zRouter;

        emit SwapSwap__zRouterUpdated(_zRouter);
    }

    /// @notice Sets the ERC20 approval that the router can draw down.
    /// @param token ERC20 token being approved.
    /// @param amount Allowance amount to set on the router.
    function setApproval(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) isZeroAddress(token) {
        IERC20(token).forceApprove(initParams.zRouter, amount);
    }

    /// @notice Executes arbitrary calldata on the router, forwarding optional ETH.
    /// @param data Encoded router function call.
    /// @param msgValue Native value forwarded to the router call.
    function executeCallDataSwap(bytes calldata data, uint256 msgValue) external onlyRole(EXECUTOR) {
        bool success;
        bytes memory returnedData;

        if (msgValue == 0) {
            (success, returnedData) = initParams.zRouter.call(data);
        } else {
            (success, returnedData) = initParams.zRouter.call{value: msgValue}(data);
        }

        if (!success) {
            revert SwapSwap__SwapFailed(returnedData);
        }

        emit SwapSwap__CallDataSwapExecuted(data, returnedData);
    }

    /// @notice Executes an Aerodrome swap using the canonical token pair managed by this contract.
    /// @dev `data` must encode (address user, bool stable, address tokenIn, uint256 swapAmount, uint256 amountLimit, uint256 deadline).
    /// @param data ABI-encoded Aerodrome swap parameters.
    function executeSwap(bytes calldata data) external onlyRole(EXECUTOR) {
        (address user, bool stable, address tokenIn, uint256 swapAmount, uint256 amountLimit, uint256 deadline) =
            abi.decode(data, (address, bool, address, uint256, uint256, uint256));

        address tokenOut = tokenIn == initParams.token ? initParams.usdc : initParams.token;
        uint256 amountIn;
        uint256 amountOut;

        if (tokenIn == address(0)) {
            (amountIn, amountOut) = IzRouter(initParams.zRouter).swapAero{value: swapAmount}({
                to: user,
                stable: stable,
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                swapAmount: swapAmount,
                amountLimit: amountLimit,
                deadline: deadline
            });
        } else {
            (amountIn, amountOut) = IzRouter(initParams.zRouter)
                .swapAero({
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

    /// @notice Executes an Aerodrome concentrated-liquidity swap through the router.
    /// @dev `data` must encode (address to, bool exactOut, int24 tickSpacing, address tokenIn, address tokenOut, uint256 swapAmount, uint256 amountLimit, uint256 deadline).
    /// @param data ABI-encoded Aerodrome CL swap parameters.
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

        uint256 amountIn;
        uint256 amountOut;

        if (tokenIn == address(0)) {
            (amountIn, amountOut) = IzRouter(initParams.zRouter).swapAeroCL{value: swapAmount}(
                to, exactOut, tickSpacing, tokenIn, tokenOut, swapAmount, amountLimit, deadline
            );
        } else {
            (amountIn, amountOut) = IzRouter(initParams.zRouter)
                .swapAeroCL(to, exactOut, tickSpacing, tokenIn, tokenOut, swapAmount, amountLimit, deadline);
        }
        emit SwapSwap__SwapExecuted(tokenIn, amountIn, amountOut);
    }

    /// @notice Transfers an ERC20 balance from this contract back to the admin.
    /// @param token ERC20 token to sweep.
    function recoverToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance == 0) {
            revert SwapSwap__ZeroBalance();
        }

        IERC20(token).safeTransfer(initParams.admin, balance);
        emit SwapSwap__TokenRecovered(token);
    }

    /// @notice Sends any accumulated ETH back to the admin.
    function recoverEth() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 ethBalance = address(this).balance;
        if (ethBalance <= 0) {
            revert SwapSwap__ZeroBalance();
        }

        (bool success,) = initParams.admin.call{value: ethBalance}("");
        if (!success) {
            revert SwapSwap__ETHTransferFailed();
        }

        emit SwapSwap__ETHRecovered();
    }

    receive() external payable {}

    /// @dev Reverts when `_address` equals the zero address.
    /// @param _address Address under validation.
    function _isZeroAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert SwapSwap__ZeroAddress();
        }
    }
}
