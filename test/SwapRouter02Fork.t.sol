// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IQuoterV2} from "lib/swap-router-contracts/contracts/interfaces/IQuoterV2.sol";
import {IV3SwapRouter} from "../src/interfaces/IV3SwapRouter.sol";
import {V3SwapRouter} from "../src/V3SwapRouter.sol";

contract HyperswapForkTest is Test {
    address proxyAddress;
    address implementation;

    // address admin = address(0xD6642090EDE21cb1Bd6a8FBbd3861A7dbd6D3EA8);
    // address executer = address(0xD6642090EDE21cb1Bd6a8FBbd3861A7dbd6D3EA8);
    address admin = address(0x1);
    address executer = address(0x2);
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

        vm.startSnapshotGas("ourSwapRouter02 - exactInputSingle WETH to USDC");

        ourSwapRouter02.exactInputSingle(IV3SwapRouter.ExactInputSingleParams(
            WETH,
            USDC,
            fee,
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