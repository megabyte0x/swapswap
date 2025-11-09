//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ISwapSwap
/// @notice Interface for the SwapSwap executor contracts deployed by the factory.
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

    /// @notice Initialization arguments used when cloning SwapSwap instances.
    struct InitParams {
        /// @dev Address of the canonical USDC token.
        address usdc;
        /// @dev Address of the DAI token counterpart.
        address dai;
        /// @dev Wrapped native token used for routing.
        address weth;
        /// @dev Admin wallet that receives recovered funds and manages roles.
        address admin;
        /// @dev Token managed by this SwapSwap instance.
        address token;
        /// @dev zRouter contract address that performs swaps.
        address zRouter;
    }

    /// @notice Approves the router to spend a specific token.
    /// @param token ERC20 token address to approve.
    /// @param amount Allowance amount to grant.
    function setApproval(address token, uint256 amount) external;

    /// @notice Updates the router reference stored in the contract.
    /// @param _zRouter Address of the new router implementation.
    function setRouter(address _zRouter) external;

    /// @notice Executes an Aerodrome swap for the managed token pair.
    /// @param data ABI-encoded swap parameters.
    function executeSwap(bytes calldata data) external;

    /// @notice Executes an Aerodrome concentrated-liquidity swap.
    /// @param data ABI-encoded swap parameters for CL pools.
    function executeCLSwap(bytes calldata data) external;

    /// @notice Forwards arbitrary calldata to the router, optionally sending ETH.
    /// @param data Encoded router call.
    /// @param msgValue ETH value to forward.
    function executeCallDataSwap(bytes calldata data, uint256 msgValue) external;

    /// @notice Recovers ERC20 tokens held by the contract.
    /// @param token ERC20 token address to sweep.
    function recoverToken(address token) external;

    /// @notice Recovers native ETH held by the contract.
    function recoverEth() external;

    /// @notice Initializes the contract with encoded {InitParams}.
    /// @param data ABI-encoded initialization struct.
    function initialize(bytes calldata data) external;

    /// @notice Returns the immutable initialization parameters.
    /// @return usdc USDC token address.
    /// @return dai DAI token address.
    /// @return weth Wrapped native token address.
    /// @return admin Admin wallet with DEFAULT_ADMIN_ROLE.
    /// @return token Managed token address.
    /// @return zRouter Router contract address.
    function initParams()
        external
        view
        returns (address usdc, address dai, address weth, address admin, address token, address zRouter);
}
