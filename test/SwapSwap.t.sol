// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20, SwapSwap} from "../src/SwapSwap.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

contract SwapSwapTest is Test {
    SwapSwap public swapSwap;
    HelperConfig public helperConfig;
    IPyth public pyth = IPyth(0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);

    bytes32 btcUsdPriceFeed = 0x2817d7bfe5c64b8ea956e9a26f573ef64e72e4d7891f2d6af9bcc93f7aff9a97;
    uint256 public constant APPROVAL_AMT = 1_000_000e18;
    uint256 public constant USDC_APPROVAL_AMT = 1_000_000e6;
    uint256 public constant USDC_AMT_TO_SWAP = 1000e6;

    address public EXECUTOR = makeAddr("EXECUTOR");
    address public USER = makeAddr("USER");

    address public s_admin;
    address public zRouter;
    address public usdc;
    address public weth;
    address public dai;

    uint256 baseMainnetFork;
    string BASE_MAINNET_RPC_URL = vm.envString("BASE_MAINNET_RPC_URL");

    function setUp() public {
        baseMainnetFork = vm.createFork(BASE_MAINNET_RPC_URL);

        helperConfig = new HelperConfig();

        (zRouter, usdc, weth, dai) = helperConfig.networkConfig();
        s_admin = helperConfig.ADMIN();

        vm.startPrank(s_admin);
        swapSwap = new SwapSwap({
            _token: helperConfig.BASE_CBBTC(),
            _router: zRouter,
            _usdc: usdc,
            _weth: weth,
            _dai: dai,
            _admin: helperConfig.ADMIN()
        });
        swapSwap.setRouter(zRouter);
        setApprovals();
        vm.stopPrank();
    }

    function setApprovals() public {
        swapSwap.setApproval(usdc, USDC_APPROVAL_AMT);
        swapSwap.setApproval(weth, APPROVAL_AMT);
        swapSwap.setApproval(dai, APPROVAL_AMT);
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

    modifier sendFundsForSwap() {
        vm.startPrank(USER);
        deal(usdc, USER, USDC_APPROVAL_AMT);
        IERC20(usdc).transfer(address(swapSwap), USDC_AMT_TO_SWAP);
        vm.stopPrank();
        _;
    }

    function getPrice() public view returns (uint256) {
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(btcUsdPriceFeed, block.timestamp + 60);

        uint256 btcPrice18Decimals =
            (uint256(uint64(price.price)) * (10 ** 18)) / (10 ** uint8(uint32(-1 * price.expo)));

        return btcPrice18Decimals;
    }

    function testExecuteSwap() public grantExecutorRole sendFundsForSwap {
        bool stable = false;
        address tokenIn = usdc;
        uint256 swapAmount = USDC_AMT_TO_SWAP;

        uint256 btcPrice = getPrice();
        uint256 btcAmt = (swapAmount * 10e18) / btcPrice;

        uint256 slippage = 100; // 1%
        uint256 amountLimit = btcAmt * (1 - (slippage / 10_000));
        uint256 deadline = block.timestamp + 30 seconds;

        bytes memory data = abi.encode(USER, stable, tokenIn, USDC_AMT_TO_SWAP, amountLimit, deadline);

        address token = swapSwap.i_token();

        uint256 balanceBefore = IERC20(token).balanceOf(USER);
        console.log("balance before: ", balanceBefore);
        vm.prank(EXECUTOR);
        swapSwap.executeSwap(data);

        uint256 balanceAfter = IERC20(swapSwap.i_token()).balanceOf(USER);
        console.log("balance after: ", balanceAfter);
        uint256 change = (balanceAfter - balanceBefore);

        console.log("Change in balance: ", change);
    }
}
