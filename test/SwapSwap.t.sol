// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20, SafeERC20, SwapSwap} from "../src/SwapSwap.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

contract SwapSwapTest is Test {
    using SafeERC20 for IERC20;

    SwapSwap public swapSwap;
    HelperConfig public helperConfig;
    IPyth public pyth = IPyth(0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);

    bytes32 btcUsdPriceFeed = 0x2817d7bfe5c64b8ea956e9a26f573ef64e72e4d7891f2d6af9bcc93f7aff9a97;
    uint256 public constant APPROVAL_AMT = 1_000;
    uint256 public constant USDC_APPROVAL_AMT = 1_000_000 * 1e6;
    uint256 public constant DECIMALS_18 = 1e18;

    address public EXECUTOR = makeAddr("EXECUTOR");
    address public USER = makeAddr("USER");

    address public s_admin;
    address public zRouter;
    address public usdc;
    address public weth;
    address public dai;
    address public token;

    uint256 public token_decimals;

    function setUp() public {
        helperConfig = new HelperConfig();

        (zRouter, usdc, weth, dai) = helperConfig.networkConfig();
        s_admin = helperConfig.ADMIN();
        token = helperConfig.BASE_CBBTC();
        token_decimals = IERC20Metadata(token).decimals();

        vm.startPrank(s_admin);
        swapSwap = new SwapSwap({
            _token: token,
            _router: zRouter,
            _usdc: usdc,
            _weth: weth,
            _dai: dai,
            _admin: helperConfig.ADMIN()
        });
        swapSwap.setRouter(zRouter);
        setApprovals();
        vm.stopPrank();

        setDeals();
    }

    function setApprovals() public {
        swapSwap.setApproval(usdc, USDC_APPROVAL_AMT);
        swapSwap.setApproval(weth, APPROVAL_AMT * DECIMALS_18);
        swapSwap.setApproval(dai, APPROVAL_AMT * DECIMALS_18);
        swapSwap.setApproval(token, APPROVAL_AMT * (10 ** token_decimals));
    }

    function setDeals() public {
        deal(usdc, USER, USDC_APPROVAL_AMT);
        deal(weth, USER, APPROVAL_AMT * DECIMALS_18);
        deal(dai, USER, APPROVAL_AMT * DECIMALS_18);
        deal(token, USER, APPROVAL_AMT * (10 ** token_decimals));
    }

    function testGrantExecutorRole() public {
        bytes32 role = keccak256("EXECUTOR");

        vm.prank(s_admin);
        swapSwap.grantRole(role, EXECUTOR);

        assert(swapSwap.hasRole(role, EXECUTOR));
    }

    modifier grantExecutorRole() {
        bytes32 role = keccak256("EXECUTOR");

        vm.prank(s_admin);
        swapSwap.grantRole(role, EXECUTOR);
        _;
    }

    function _getPrice(address asset) internal view returns (uint256) {
        bytes32 priceFeed = helperConfig.getPriceFeed(asset);
        require(priceFeed != 0, "PRICE_FEED_NOT_FOUND");
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(priceFeed, block.timestamp + 60);

        uint256 tokenPrice18Decimals =
            (uint256(uint64(price.price)) * (10 ** 18)) / (10 ** uint8(uint32(-1 * price.expo)));

        return tokenPrice18Decimals;
    }

    function _getTokenAmount(address tokenIn, address tokenOut, uint256 swapAmount)
        internal
        view
        returns (uint256 tokenAmt)
    {
        uint8 inDecimals = IERC20Metadata(tokenIn).decimals();
        uint8 outDecimals = IERC20Metadata(tokenOut).decimals();
        uint256 tokenInPrice = _getPrice(tokenIn);
        uint256 tokenOutPrice = _getPrice(tokenOut);
        // tokenPrice is in 18 decimals (from Pyth)
        uint256 scale = 10 ** (outDecimals + 18 - inDecimals);

        tokenAmt = (swapAmount * scale * tokenInPrice) / (tokenOutPrice * DECIMALS_18);
    }

    function _calculateAmountLimit(uint256 tokenAmt, uint256 slippage) internal pure returns (uint256) {
        return (tokenAmt * (10_000 - slippage)) / 10_000;
    }

    function testExecuteSwapFromUSDCtoToken() public grantExecutorRole {
        bool stable = false;
        address tokenIn = usdc;
        address tokenOut = swapSwap.i_token();
        uint256 swapAmount = 1000 * 1e6;
        uint256 deadline = block.timestamp + 30 seconds;

        uint256 tokenAmt = _getTokenAmount(tokenIn, tokenOut, swapAmount);
        console.log("tokenAmt :", tokenAmt);

        uint256 slippage = 100; // 1%
        uint256 amountLimit = _calculateAmountLimit(tokenAmt, slippage);

        console.log("amt limit: ", amountLimit);

        bytes memory data = abi.encode(USER, stable, tokenIn, swapAmount, amountLimit, deadline);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(USER);
        console.log("balance before: ", balanceBefore);

        vm.prank(USER);
        IERC20(usdc).safeTransfer(address(swapSwap), swapAmount);

        vm.prank(EXECUTOR);
        swapSwap.executeSwap(data);

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(USER);
        console.log("balance after: ", balanceAfter);

        uint256 change = (balanceAfter - balanceBefore);
        console.log("Change in balance: ", change);

        assertGt(change, amountLimit);
    }

    function testExecuteSwapFromTokentoUSDC() public grantExecutorRole {
        bool stable = false;
        address tokenIn = swapSwap.i_token();
        address tokenOut = usdc;
        uint256 deadline = block.timestamp + 30 seconds;

        // cbBTC have 8 decimal
        uint256 swapAmount = 1e5; // 0.001 cbBTC

        uint256 tokenAmt = _getTokenAmount(tokenIn, tokenOut, swapAmount);
        console.log("tokenAmt :", tokenAmt);

        uint256 slippage = 100; // 1%
        uint256 amountLimit = _calculateAmountLimit(tokenAmt, slippage);
        console.log("amt limit: ", amountLimit);

        bytes memory data = abi.encode(USER, stable, tokenIn, swapAmount, amountLimit, deadline);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(USER);
        console.log("balance before: ", balanceBefore);

        vm.prank(USER);
        IERC20(token).safeTransfer(address(swapSwap), swapAmount);

        vm.prank(EXECUTOR);
        swapSwap.executeSwap(data);

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(USER);
        console.log("balance after: ", balanceAfter);

        uint256 change = (balanceAfter - balanceBefore);
        console.log("Change in balance: ", change);

        assertGt(change, amountLimit);
    }
}
