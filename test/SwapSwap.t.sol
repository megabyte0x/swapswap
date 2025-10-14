// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPyth, PythStructs} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {HelperConfig} from "../script/HelperConfig.s.sol";
import {IERC20, SafeERC20, SwapSwap} from "../src/SwapSwap.sol";

contract SwapSwapTest is Test {
    using SafeERC20 for IERC20;

    SwapSwap public swapSwap;
    HelperConfig public helperConfig;
    IPyth public pyth = IPyth(0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);

    uint256 public constant APPROVAL_AMT = 1_000;
    uint256 public constant USDC_APPROVAL_AMT = 1_000_000 * 1e6;
    uint256 public constant DECIMALS_18 = 1e18;
    address constant ETH = address(0);

    address public EXECUTOR = makeAddr("EXECUTOR");
    address public USER = makeAddr("USER");

    address public admin;
    address public zRouter;
    address public usdc;
    address public weth;
    address public dai;
    address public token;

    uint256 public token_decimals;

    function setUp() public {
        helperConfig = new HelperConfig();

        (zRouter, usdc, weth, dai) = helperConfig.networkConfig();
        admin = helperConfig.ADMIN();
        token = helperConfig.BASE_CBBTC();
        token_decimals = IERC20Metadata(token).decimals();

        vm.startPrank(admin);
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
        deal(USER, 100 ether);
        deal(usdc, USER, USDC_APPROVAL_AMT);
        deal(weth, USER, APPROVAL_AMT * DECIMALS_18);
        deal(dai, USER, APPROVAL_AMT * DECIMALS_18);
        deal(token, USER, APPROVAL_AMT * (10 ** token_decimals));
    }

    function testGrantExecutorRole() public {
        bytes32 role = keccak256("EXECUTOR");

        vm.prank(admin);
        swapSwap.grantRole(role, EXECUTOR);

        assert(swapSwap.hasRole(role, EXECUTOR));
    }

    modifier grantExecutorRole() {
        bytes32 role = keccak256("EXECUTOR");

        vm.prank(admin);
        swapSwap.grantRole(role, EXECUTOR);
        _;
    }

    function callSwap(address tokenIn, address tokenOut, uint256 swapAmount, uint256 amountLimit, uint256 deadline)
        internal
    {
        int24 tickSpacing = 100;
        bool exactOut = false;
        bool stable = false;

        if (helperConfig.checkIfCLPoolExists(tokenIn, tokenOut, tickSpacing)) {
            bytes memory data =
                abi.encode(USER, exactOut, tickSpacing, tokenIn, tokenOut, swapAmount, amountLimit, deadline);
            swapSwap.executeCLSwap(data);
        } else {
            bytes memory data = abi.encode(USER, stable, tokenIn, tokenOut, swapAmount, amountLimit, deadline);
            swapSwap.executeSwap(data);
        }
    }

    function _getPrice(address asset) internal view returns (uint256) {
        bytes32 priceFeed = helperConfig.getPriceFeed(asset);
        require(priceFeed != 0, "PRICE_FEED_NOT_FOUND");
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(priceFeed, block.timestamp + 60);

        uint256 tokenPrice18Decimals =
            (uint256(uint64(price.price)) * (10 ** 18)) / (10 ** uint8(uint32(-1 * price.expo)));

        return tokenPrice18Decimals;
    }

    function _getTokenAmount(address tokenIn, address tokenOut, uint256 tokenInAmt)
        internal
        view
        returns (uint256 tokenAmt)
    {
        uint8 inDecimals = tokenIn == ETH ? IERC20Metadata(weth).decimals() : IERC20Metadata(tokenIn).decimals();
        uint8 outDecimals = tokenOut == ETH ? IERC20Metadata(weth).decimals() : IERC20Metadata(tokenOut).decimals();
        uint256 tokenInPrice = _getPrice(tokenIn);
        uint256 tokenOutPrice = _getPrice(tokenOut);

        uint256 base = Math.mulDiv(tokenInAmt, tokenInPrice, tokenOutPrice);

        if (outDecimals >= inDecimals) {
            tokenAmt = tokenAmt = base * (10 ** (outDecimals - inDecimals));
        } else {
            tokenAmt = base / (10 ** (inDecimals - outDecimals));
        }
    }

    function _calculateAmountLimit(uint256 tokenAmt, uint256 slippage) internal pure returns (uint256) {
        return (tokenAmt * (10_000 - slippage)) / 10_000;
    }

    function testExecuteSwapFromUSDCtoToken() public grantExecutorRole {
        uint256 deadline = block.timestamp + 30 seconds;

        address tokenIn = usdc;
        address tokenOut = swapSwap.i_token();

        uint256 swapAmountIn1e18 = 12545e16; // 125.45e18
        uint8 inDecimals = IERC20Metadata(tokenIn).decimals();
        uint256 tokenInAmt = (swapAmountIn1e18 * 10 ** inDecimals) / DECIMALS_18;

        uint256 tokenAmt = _getTokenAmount(tokenIn, tokenOut, tokenInAmt);
        console.log("tokenAmt :", tokenAmt);

        uint256 slippage = 100; // 1%
        uint256 amountLimit = _calculateAmountLimit(tokenAmt, slippage);
        console.log("amt limit: ", amountLimit);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(USER);
        console.log("balance before: ", balanceBefore);

        vm.prank(USER);
        IERC20(tokenIn).safeTransfer(address(swapSwap), tokenInAmt);

        vm.startPrank(EXECUTOR);
        callSwap(tokenIn, tokenOut, tokenInAmt, amountLimit, deadline);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(USER);
        console.log("balance after: ", balanceAfter);

        uint256 change = (balanceAfter - balanceBefore);
        console.log("Change in balance: ", change);

        assertGt(change, amountLimit);
    }

    function testExecuteSwapFromTokentoUSDC() public grantExecutorRole {
        address tokenIn = token;
        address tokenOut = usdc;
        uint256 deadline = block.timestamp + 30 seconds;

        uint256 swapAmountIn1e18 = 6e17; // 0.6e18
        uint8 inDecimals = IERC20Metadata(tokenIn).decimals();

        // cbBTC have 8 decimal
        // 0.6 * 1e18 * 1e8 / 1e18 = 6e7 === 0.6 cbBTC
        uint256 tokenInAmt = (swapAmountIn1e18 * 10 ** inDecimals) / DECIMALS_18;

        uint256 tokenAmt = _getTokenAmount(tokenIn, tokenOut, tokenInAmt);
        console.log("tokenAmt :", tokenAmt);

        uint256 slippage = 300; // 1%
        uint256 amountLimit = _calculateAmountLimit(tokenAmt, slippage);
        console.log("amt limit: ", amountLimit);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(USER);
        console.log("balance before: ", balanceBefore);

        vm.prank(USER);
        IERC20(tokenIn).safeTransfer(address(swapSwap), tokenInAmt);

        vm.startPrank(EXECUTOR);
        callSwap(tokenIn, tokenOut, tokenInAmt, amountLimit, deadline);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(USER);
        console.log("balance after: ", balanceAfter);

        uint256 change = (balanceAfter - balanceBefore);
        console.log("Change in balance: ", change);

        assertGt(change, amountLimit);
    }

    function testExecuteSwapFromETHtoToken() public grantExecutorRole {
        uint256 deadline = block.timestamp + 30 seconds;

        address tokenIn = ETH;
        address tokenOut = swapSwap.i_token();

        uint256 swapAmountIn1e18 = 5e16; // 0.05e18
        uint8 inDecimals = tokenIn == ETH ? 18 : IERC20Metadata(tokenIn).decimals();

        // 0.05 * 1e18 * 1e18 / 1e18 = 5e16 === 0.05 ether
        uint256 tokenInAmt = (swapAmountIn1e18 * 10 ** inDecimals) / DECIMALS_18;

        uint256 tokenAmt = _getTokenAmount(tokenIn, tokenOut, tokenInAmt);
        console.log("tokenAmt :", tokenAmt);

        uint256 slippage = 100; // 1%
        uint256 amountLimit = _calculateAmountLimit(tokenAmt, slippage);
        console.log("amt limit: ", amountLimit);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(USER);
        console.log("balance before: ", balanceBefore);

        vm.prank(USER);
        (bool success,) = address(swapSwap).call{value: tokenInAmt}("");
        require(success, "ETH_TRANSFER_FAILED");

        vm.startPrank(EXECUTOR);
        callSwap(tokenIn, tokenOut, tokenInAmt, amountLimit, deadline);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(USER);
        console.log("balance after: ", balanceAfter);

        uint256 change = (balanceAfter - balanceBefore);
        console.log("Change in balance: ", change);

        assertGt(change, amountLimit);
    }
}
