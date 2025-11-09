// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPyth, PythStructs} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {HelperConfig} from "../script/HelperConfig.s.sol";
import {IERC20, SafeERC20, SwapSwap} from "../src/SwapSwap.sol";
import {IzQuoter} from "../src/interfaces/IzQuoter.sol";
import {SwapSwapFactory} from "../src/SwapSwapFactory.sol";

contract SwapSwapTest is Test {
    using SafeERC20 for IERC20;

    SwapSwap public swapSwap;
    SwapSwapFactory public factory;
    HelperConfig public helperConfig;
    IPyth public pyth = IPyth(0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);

    uint256 public constant APPROVAL_AMT = 1_000_000;
    uint256 public constant USDC_APPROVAL_AMT = 1_000_000 * 1e6;
    uint256 public constant DECIMALS_18 = 1e18;
    address constant ETH = address(0);

    address public EXECUTOR = makeAddr("EXECUTOR");
    address public USER = makeAddr("USER");

    address public zRouter;
    address public zQuoterBase;

    address public admin;
    address public usdc;
    address public weth;
    address public dai;
    address public token;

    uint256 public token_decimals;
    uint256 slippageBps = 500; // 1%
    bool EXACT_OUT = false;

    function setUp() public {
        helperConfig = new HelperConfig();

        (zRouter, usdc, weth, dai) = helperConfig.networkConfig();
        admin = helperConfig.ADMIN();
        token = helperConfig.BASE_CBBTC();
        zQuoterBase = helperConfig.BASE_zQUOTER();
        token_decimals = IERC20Metadata(token).decimals();
        string memory salt = helperConfig.SALT();

        vm.startPrank(admin);
        address implementation = address(new SwapSwap());
        factory = new SwapSwapFactory(
            implementation,
            admin,
            zRouter,
            usdc,
            weth,
            dai,
            salt
        );
        address swap = factory.deploySwapSwap(token);

        swapSwap = SwapSwap(payable(swap));

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

    function callDataSwap(bytes memory data, uint256 msgValue) internal {
        swapSwap.executeCallDataSwap(data, msgValue);
    }

    function _generateCallDataForSwap(
        address tokenIn,
        address tokenOut,
        uint256 swapAmount,
        uint256 deadline
    )
        internal
        view
        returns (bytes memory data, uint256 amountLimit, uint256 msgValue)
    {
        bool success;
        bytes memory returnedData;

        {
            (success, returnedData) = address(zQuoterBase).staticcall(
                abi.encodeWithSelector(
                    IzQuoter.buildBestSwap.selector,
                    USER,
                    EXACT_OUT,
                    tokenIn,
                    tokenOut,
                    swapAmount,
                    slippageBps,
                    deadline
                )
            );
        }

        if (success) {
            (, data, amountLimit, msgValue) = abi.decode(
                returnedData,
                (IzQuoter.Quote, bytes, uint256, uint256)
            );
            return (data, amountLimit, msgValue);
        } else {
            {
                (success, returnedData) = address(zQuoterBase).staticcall(
                    abi.encodeWithSelector(
                        IzQuoter.buildBestSwapViaETHMulticall.selector,
                        USER, // to
                        USER, // refundTo
                        EXACT_OUT,
                        tokenIn,
                        tokenOut,
                        swapAmount,
                        slippageBps,
                        deadline
                    )
                );
            }

            if (success) {
                (, , , data, msgValue) = abi.decode(
                    returnedData,
                    (IzQuoter.Quote, IzQuoter.Quote, bytes[], bytes, uint256)
                );
                amountLimit = 0;
                return (data, amountLimit, msgValue);
            }
        }
        revert("NOTHING");
    }

    function testExecuteCallDataSwapFromUSDCtoToken() public grantExecutorRole {
        uint256 deadline = block.timestamp + 30 seconds;

        address tokenIn = usdc;
        address tokenOut = token;

        uint256 swapAmountIn1e18 = 12545e16; // 125.45e18
        uint8 inDecimals = IERC20Metadata(tokenIn).decimals();
        uint256 tokenInAmt = (swapAmountIn1e18 * 10 ** inDecimals) /
            DECIMALS_18;

        (
            bytes memory data,
            uint256 amountLimit,
            uint256 msgValue
        ) = _generateCallDataForSwap(tokenIn, tokenOut, tokenInAmt, deadline);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(USER);
        console.log("balance before: ", balanceBefore);

        vm.prank(USER);
        IERC20(tokenIn).safeTransfer(address(swapSwap), tokenInAmt);

        vm.startPrank(EXECUTOR);
        callDataSwap(data, msgValue);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(USER);
        console.log("balance after: ", balanceAfter);

        uint256 change = (balanceAfter - balanceBefore);
        console.log("Change in balance: ", change);

        assertGt(change, amountLimit);
    }

    function testExecuteCallDataSwapFromTokenToUSDC() public grantExecutorRole {
        uint256 deadline = block.timestamp + 60 seconds;

        address tokenOut = usdc;
        address tokenIn = token;

        uint256 swapAmountIn1e18 = 12545e18; // 0.12545e18
        uint8 inDecimals = IERC20Metadata(tokenIn).decimals();
        uint256 tokenInAmt = (swapAmountIn1e18 * 10 ** inDecimals) /
            DECIMALS_18;

        (
            bytes memory data,
            uint256 amountLimit,
            uint256 msgValue
        ) = _generateCallDataForSwap(tokenIn, tokenOut, tokenInAmt, deadline);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(USER);
        console.log("balance before: ", balanceBefore);

        vm.prank(USER);
        IERC20(tokenIn).safeTransfer(address(swapSwap), tokenInAmt);

        vm.startPrank(EXECUTOR);
        callDataSwap(data, msgValue);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(USER);
        console.log("balance after: ", balanceAfter);

        uint256 change = (balanceAfter - balanceBefore);
        console.log("Change in balance: ", change);

        assertGt(change, amountLimit);
    }

    function testExecuteCallDataSwapFromETHToToken() public grantExecutorRole {
        uint256 deadline = block.timestamp + 60 seconds;

        address tokenOut = token;
        address tokenIn = ETH;

        uint256 swapAmountIn1e18 = 5e16;
        uint8 inDecimals = tokenIn == ETH
            ? 18
            : IERC20Metadata(tokenIn).decimals();
        uint256 tokenInAmt = (swapAmountIn1e18 * 10 ** inDecimals) /
            DECIMALS_18;

        (
            bytes memory data,
            uint256 amountLimit,
            uint256 msgValue
        ) = _generateCallDataForSwap(tokenIn, tokenOut, tokenInAmt, deadline);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(USER);
        console.log("balance before: ", balanceBefore);

        vm.prank(USER);
        (bool success, ) = address(swapSwap).call{value: msgValue}("");
        require(success, "ETH_TRANSFER_FAILED");

        vm.startPrank(EXECUTOR);
        callDataSwap(data, msgValue);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(USER);
        console.log("balance after: ", balanceAfter);

        uint256 change = (balanceAfter - balanceBefore);
        console.log("Change in balance: ", change);

        assertGt(change, amountLimit);
    }
}
