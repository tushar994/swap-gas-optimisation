// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import './interfaces/IV3SwapRouter.sol';

contract V3SwapRouter is IV3SwapRouter {

    /// @dev Used as the placeholder value for amountInCached, because the computed amount in for an exact output swap
    /// can never actually be this value
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    /// @dev Transient storage variable used for returning the computed amount in for an exact output swap.
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    bytes4 constant SWAP_SELECTOR = 0x128acb08; // bytes4(keccak256("swap(address,bool,int256,uint160,bytes)"))

    constructor() {}

    function decodePackedAddresses(bytes memory packedData) 
        public 
        pure 
        returns (address a1, address a2, address a3) 
    {
        // Require the input data to be exactly 60 bytes (3 * 20 bytes)
        // Note: The actual length of 'packedData' is stored in the first 32 bytes of the memory location.
        require(packedData.length == 60, "Data must be exactly 60 bytes (3 addresses)");

        // Inline assembly block
        assembly {
            // packedData points to the memory location of the bytes array.
            // The first 32 bytes (0x20) hold the length. 
            // We add 0x20 to get the pointer to the actual data content.
            let dataPtr := add(packedData, 0x20)
            
            // --- Address 1: Starts at offset 0x00 ---
            // mload loads a 32-byte word: [Addr1 (20B) | Addr2_High (12B)]
            // shr(96, ...) shifts the result 96 bits (12 bytes) to the right. 
            // This discards the 12 bytes of Addr2 and leaves the 20 bytes of Addr1 
            // correctly zero-padded on the left, ready to be treated as an address.
            a1 := shr(96, mload(dataPtr))
            
            // --- Address 2: Starts at offset 0x14 (20 bytes) ---
            // dataPtr + 0x14 points to the start of the second address.
            let offset2 := add(dataPtr, 0x14)
            // mload loads a 32-byte word: [Addr2 (20B) | Addr3_High (12B)]
            a2 := shr(96, mload(offset2))

            // --- Address 3: Starts at offset 0x28 (40 bytes) ---
            // dataPtr + 0x28 points to the start of the third address.
            let offset3 := add(dataPtr, 0x28)
            // mload loads a 32-byte word: [Addr3 (20B) | 12B of potential garbage/zeroes]
            a3 := shr(96, mload(offset3))
        }
    }

    function hyperswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        (address tokenIn, address tokenOut, address payer) = decodePackedAddresses(_data);

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            TransferHelper.safeTransferFrom(tokenIn, payer, msg.sender, amountToPay);
        } else {
            amountInCached = amountToPay;
            // note that because exact output swaps are executed in reverse order, tokenOut is actually tokenIn
            TransferHelper.safeTransferFrom(tokenOut, payer, msg.sender, amountToPay);
        }
    }

    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        (address tokenIn, address tokenOut, address payer) = decodePackedAddresses(_data);

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            TransferHelper.safeTransferFrom(tokenIn, payer, msg.sender, amountToPay);
        } else {
            amountInCached = amountToPay;
            // note that because exact output swaps are executed in reverse order, tokenOut is actually tokenIn
            TransferHelper.safeTransferFrom(tokenOut, payer, msg.sender, amountToPay);
        }
    }

    /// @inheritdoc IV3SwapRouter
    function exactInputSingle(ExactInputSingleParams memory params)
        external
        payable
        override
    {
        bool zeroForOne = params.tokenIn < params.tokenOut;

        // (int256 amount0, int256 amount1) =
        //     IUniswapV3Pool(params.pool).swap(
        //         params.recipient,
        //         zeroForOne,
        //         params.amountIn,
        //         params.sqrtPriceLimitX96,
        //         abi.encodePacked(params.tokenIn, params.tokenOut, msg.sender)
        //     );


        // 0000000000000000000000001111111111111111111111111111111111111111
        // 0000000000000000000000000000000000000000000000000000000000000001
        // 00000000000000000000000000000000000000000000000000000000000003e8
        // 00000000000000000000000000000000000000000000000000000001000276a4
        // 00000000000000000000000000000000000000000000000000000000000000c4
        // 000000000000000000000000000000000000000000000000000000000000003c
        // 5555555555555555555555555555555555555555
        // b88339cb7199b77e23db6e890353e22632ba630f
        // 1111111111111111111111111111111111111111

        // 0xb88339cb7199b77e23db6e8932ba630f

        // 0xb88339CB7199b77E23DB6E890353E22632Ba630f
        // 0xb88339cb7199b77e23db6e890353e22632ba630f00000000

        
        // -----------------------------------------------------------
        // 1. Prepare Calldata for the external swap call
        // -----------------------------------------------------------
        
        // We use the free memory pointer (0x40) to build the calldata.
        // Calldata layout:
        // 0x00: Function Selector (4 bytes)
        // 0x04: recipient (address, 32 bytes)
        // 0x24: zeroForOne (bool, 32 bytes)
        // 0x44: amountSpecified (int256, 32 bytes)
        // 0x64: sqrtPriceLimitX96 (uint160, 32 bytes)
        // 0x84: data offset (uint256, 32 bytes) - Points to the start of the dynamic bytes argument
        // 0xA4: data length (uint256, 32 bytes)
        // 0xC4: packed data payload (variable length)
        int256 amount0 = 1;
        int256 amount1 = 1;

        bytes memory packedData;
        
        assembly {
            let ptr := mload(0x40) // Free memory pointer
            mstore(0x40, add(ptr, 0xe4)) // Update to end of used memory
            mstore(ptr, SWAP_SELECTOR) // Function selector for swap(address,bool,int256,uint160,bytes)

            // Store function selector and arguments
            mstore(add(ptr, 0x04), mload(add(params, 0x40))) // recipient (offset 0x40)
            mstore(add(ptr, 0x24), zeroForOne) // zeroForOne (bool)
            mstore(add(ptr, 0x44), mload(add(params, 0x60))) // amountIn (offset 0x60)
            mstore(add(ptr, 0x64), mload(add(params, 0xa0))) // sqrtPriceLimitX96 (offset 0xa0)
            
            // Store bytes offset (points to 0xa4, i.e., 164 bytes from ptr)
            mstore(add(ptr, 0x84), 0x3c)
            
            // Store bytes data
            // mstore(add(ptr, 0xa4), 0x3c) // Length of bytes (60 bytes = 20 + 20 + 20)

            // Pack tokenIn, tokenOut, msg.sender into 60 bytes
            let tokenIn := mload(add(params, 0x00)) // Load tokenIn (20 bytes, right-aligned)
            let tokenOut := mload(add(params, 0x20)) // Load tokenOut (20 bytes, right-aligned)
            let sender := caller() // Load msg.sender (20 bytes, right-aligned)
            
            // Write first 32 bytes: tokenIn (20 bytes) + first 12 bytes of tokenOut
            // 96 = 12 bytes
            // 256 = 32 bytes
            // 160 = 20 bytes
            // 160-64 = 96
            // we want to show 64
            mstore(add(ptr, 0xa4), or(shl(96, tokenIn), shr(64, tokenOut)))
            // Write last 28 bytes: last 8 bytes of tokenOut + msg.sender (20 bytes)
            mstore(add(ptr, 0xc4), or(shl(192, tokenOut), shl(32, sender)))

            // Check if pool address has code
            let pool := mload(add(params, 0xc0)) // Load params.pool
            // Debug check: Ensure pool is not the function selector
            // if eq(pool, 0x128acb08) {
            //     revert(0, 0) // Revert if pool address is invalid
            // }
            if iszero(extcodesize(pool)) {
                revert(0, 0)
            }

            
            // Perform the call
            let success := call(
                gas(),           // Forward all available gas
                pool,           // Target contract (params.pool)
                0,              // No Ether sent
                ptr,            // Calldata start
                0xe4,           // Calldata size (196 bytes)
                ptr,            // Return data start
                0x40            // Return data size (64 bytes for two int256)
            )
            
            // Check call success
            if iszero(success) {
                revert(0, 0)
            }
            
            // Load return values
            amount0 := mload(ptr)          // First int256 (0x00-0x1f)
            amount1 := mload(add(ptr, 0x20)) // Second int256 (0x20-0x3f)
            
            // Update free memory pointer
            
        }


        int256 amountOut = (-(zeroForOne ? amount1 : amount0));

        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    // // / @dev Performs a single exact output swap
    // function exactOutputInternal(
    //     uint256 amountOut,
    //     address recipient,
    //     uint160 sqrtPriceLimitX96,
    //     SwapCallbackData memory data
    // ) private returns (uint256 amountIn) {
    //     // find and replace recipient addresses
    //     if (recipient == Constants.MSG_SENDER) recipient = msg.sender;
    //     else if (recipient == Constants.ADDRESS_THIS) recipient = address(this);

    //     (address tokenOut, address tokenIn, uint24 fee) = data.path.decodeFirstPool();

    //     bool zeroForOne = tokenIn < tokenOut;

    //     (int256 amount0Delta, int256 amount1Delta) =
    //         getPool(tokenIn, tokenOut, fee).swap(
    //             recipient,
    //             zeroForOne,
    //             -amountOut.toInt256(),
    //             sqrtPriceLimitX96 == 0
    //                 ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
    //                 : sqrtPriceLimitX96,
    //             abi.encode(data)
    //         );

    //     uint256 amountOutReceived;
    //     (amountIn, amountOutReceived) = zeroForOne
    //         ? (uint256(amount0Delta), uint256(-amount1Delta))
    //         : (uint256(amount1Delta), uint256(-amount0Delta));
    //     // it's technically possible to not receive the full output amount,
    //     // so if no price limit has been specified, require this possibility away
    //     if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut);
    // }

    // /// @inheritdoc IV3SwapRouter
    // function exactOutputSingle(ExactOutputSingleParams calldata params)
    //     external
    //     payable
    //     override
    //     returns (uint256 amountIn)
    // {
    //     // avoid an SLOAD by using the swap return data
    //     amountIn = exactOutputInternal(
    //         params.amountOut,
    //         params.recipient,
    //         params.sqrtPriceLimitX96,
    //         SwapCallbackData({path: abi.encodePacked(params.tokenOut, params.fee, params.tokenIn), payer: msg.sender})
    //     );

    //     require(amountIn <= params.amountInMaximum, 'Too much requested');
    //     // has to be reset even though we don't use it in the single hop case
    //     amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    // }
}
