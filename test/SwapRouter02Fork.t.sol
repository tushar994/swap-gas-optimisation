// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IQuoterV2} from "lib/swap-router-contracts/contracts/interfaces/IQuoterV2.sol";
import {IV3SwapRouter} from "../src/interfaces/IV3SwapRouter.sol";
import {V3SwapRouter} from "../src/V3SwapRouter.sol";

contract OurForkTest is Test {
    address proxyAddress;
    address implementation;

    // address admin = address(0xD6642090EDE21cb1Bd6a8FBbd3861A7dbd6D3EA8);
    // address executer = address(0xD6642090EDE21cb1Bd6a8FBbd3861A7dbd6D3EA8);
    address admin = address(0x1);
    address executer = address(0x1111111111111111111111111111111111111111);
    address WETH = 0x5555555555555555555555555555555555555555;
    V3SwapRouter ourSwapRouter02;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    function setUp() public {
        vm.createSelectFork("https://rpc.hyperliquid.xyz/evm");
        ourSwapRouter02 = new V3SwapRouter();
    }

    function testOurSwaprouterSwap() public {
        // Test swaping on pool 0xe712d505572b3f84c1b4deb99e1beab9dd0e23c9 - WHYPE/USDC
        vm.startPrank(executer);

        uint24 fee = 3000;

        address USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
        address pool = 0xe712D505572b3f84C1B4deB99E1BeAb9dd0E23c9;

        deal(USDC, executer, 1e20);
        deal(WETH, executer, 1e20);
        IERC20(USDC).approve(address(ourSwapRouter02), type(uint256).max);
        IERC20(WETH).approve(address(ourSwapRouter02), type(uint256).max);

        uint256 prevBalance = IERC20(USDC).balanceOf(address(executer));

        console.logBytes4(bytes4(keccak256("swap(address,bool,int256,uint160,bytes)")));

        // IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams(
        //     WETH,
        //     USDC,
        //     executer,
        //     1000,
        //     0,
        //     WETH < USDC ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
        //     pool
        // );
        // address poolAddress;
        // assembly{
        //     let ptr := mload(0x40) // Free memory pointer
        //     mstore(ptr, 0x128acb08) // Function selector for swap(address,bool,int256,uint160,bytes)

        //     // Pack tokenIn, tokenOut, msg.sender into 60 bytes
        //     let tokenIn := mload(add(params, 0x00)) // Load tokenIn (20 bytes, right-aligned)
        //     let tokenOut := mload(add(params, 0x20)) // Load tokenOut (20 bytes, right-aligned)
        //     let sender := caller() // Load msg.sender (20 bytes, right-aligned)
            
        //     // Write first 32 bytes: tokenIn (20 bytes) + first 12 bytes of tokenOut
        //     mstore(add(ptr, 0x04), or(shl(96, tokenIn), shr(160, tokenOut)))
        //     // Write last 28 bytes: last 8 bytes of tokenOut + msg.sender (20 bytes)
        //     mstore(add(ptr, 0x24), or(shl(96, and(tokenOut, 0xffffffffffffffff)), sender))

        //     // Check if pool address has code
        //     poolAddress := mload(add(params, 0xc0)) // Load params.pool
        // }
        // console.log("Pool address from params:", poolAddress);

        vm.startSnapshotGas("ourSwapRouter02 - exactInputSingle WETH to USDC");

        ourSwapRouter02.exactInputSingle(IV3SwapRouter.ExactInputSingleParams(
            WETH,
            USDC,
            executer,
            1000,
            0,
            WETH < USDC ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            pool
        ));

        uint256 gasUsed = vm.stopSnapshotGas();

        console.log("Gas used for exactInputSingle WETH to USDC by ourSwapRouter02:", gasUsed);

        vm.stopPrank();
    }
}