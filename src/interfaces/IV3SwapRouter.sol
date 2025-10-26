// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface IV3SwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        int256 amountIn;
        int256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
        address pool;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
    /// and swap the entire amount, enabling contracts to send tokens before calling this function.
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    function exactInputSingle(ExactInputSingleParams calldata params) external payable;

    // struct ExactOutputSingleParams {
    //     address tokenIn;
    //     address tokenOut;
    //     uint24 fee;
    //     address recipient;
    //     uint256 amountOut;
    //     uint256 amountInMaximum;
    //     uint160 sqrtPriceLimitX96;
    // }

    // /// @notice Swaps as little as possible of one token for `amountOut` of another token
    // /// that may remain in the router after the swap.
    // /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    // /// @return amountIn The amount of the input token
    // function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);
}
