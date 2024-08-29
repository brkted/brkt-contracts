// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BitScan} from "solidity-bits/contracts/BitScan.sol";
import {Popcount} from "solidity-bits/contracts/Popcount.sol";

import "forge-std/console.sol";

/**
 * @dev This Library is a fork of https://github.com/estarriolvetch/solidity-bits/blob/main/contracts/BitMaps.sol 
 *  but reverting their MSB index change from OZ's BitMap
*/
library BitMaps {
    using BitScan for uint256;
    uint256 private constant MASK_FULL = type(uint256).max;

    struct BitMap {
        mapping(uint256 => uint256) _data;
    }

    /**
     * @dev Returns whether the bit at `index` is set.
     */
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev Sets the bit at `index` to the boolean `value`.
     */
    function setTo(
        BitMap storage bitmap,
        uint256 index,
        bool value
    ) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /**
     * @dev Sets the bit at `index`.
     */
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev Unsets the bit at `index`.
     */
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }


    /**
     * @dev Consecutively sets `amount` of bits starting from the bit at `startIndex`.
     */    
    function setBatch(BitMap storage bitmap, uint256 startIndex, uint256 amount) internal {
        uint256 bucket = startIndex >> 8;

        uint256 bucketStartIndex = (startIndex & 0xff);
        unchecked {
            if(bucketStartIndex + amount < 256) {
                bitmap._data[bucket] |= MASK_FULL >> (256 - amount) << bucketStartIndex;
            } else {
                bitmap._data[bucket] |= MASK_FULL << bucketStartIndex;
                amount -= (256 - bucketStartIndex);
                bucket++;

                while(amount > 256) {
                    bitmap._data[bucket] = MASK_FULL;
                    amount -= 256;
                    bucket++;
                }

                bitmap._data[bucket] |= MASK_FULL >> (256 - amount);
            }
        }
    }


    /**
     * @dev Consecutively unsets `amount` of bits starting from the bit at `startIndex`.
     */    
    function unsetBatch(BitMap storage bitmap, uint256 startIndex, uint256 amount) internal {
        uint256 bucket = startIndex >> 8;

        uint256 bucketStartIndex = (startIndex & 0xff);
        unchecked {
            if(bucketStartIndex + amount < 256) {
                bitmap._data[bucket] &= ~(MASK_FULL >> (256 - amount) << bucketStartIndex);
            } else {
                bitmap._data[bucket] &= ~(MASK_FULL << bucketStartIndex);
                amount -= (256 - bucketStartIndex);
                bucket++;

                while(amount > 256) {
                    bitmap._data[bucket] = 0;
                    amount -= 256;
                    bucket++;
                }

                bitmap._data[bucket] &= ~(MASK_FULL >> (256 - amount));
            }
        }
    }

    /**
     * @dev Returns number of set bits within a range.
     */
    function popcountA(BitMap storage bitmap, uint256 startIndex, uint256 amount) internal view returns(uint256 count) {
        uint256 bucket = startIndex >> 8;

        uint256 bucketStartIndex = (startIndex & 0xff);

        unchecked {
            // shift the offset out and then mask to the range length
            uint256 range = bitmap._data[bucket] >> bucketStartIndex & ((1 << (amount)) - 1);
            if(bucketStartIndex + amount < 256) {
                count +=  Popcount.popcount256A(range);
            } else {
                // Add every set in the starting board from the given offset
                count += Popcount.popcount256A(
                    bitmap._data[bucket] >> bucketStartIndex
                );
                amount -= (256 - bucketStartIndex);
                bucket++;

                while(amount > 256) {
                    // Add every set from the entire board
                    count += Popcount.popcount256A(bitmap._data[bucket]);
                    amount -= 256;
                    bucket++;
                }
                // Mask the final board and add the sets
                count += Popcount.popcount256A(
                    bitmap._data[bucket] & ((1 << (amount)) - 1)
                );
            }
        }
    }

    /**
     * @dev Returns number of set bits within a range.
     */
    function popcountB(BitMap storage bitmap, uint256 startIndex, uint256 amount) internal view returns(uint256 count) {
        uint256 bucket = startIndex >> 8;

        uint256 bucketStartIndex = (startIndex & 0xff);

        unchecked {
            // shift the offset out and then mask to the range length
            uint256 range = bitmap._data[bucket] >> bucketStartIndex & ((1 << (amount)) - 1);
            if(bucketStartIndex + amount < 256) {
                count +=  Popcount.popcount256A(range);
            } else {
                // Add every set in the starting board from the given offset
                count += Popcount.popcount256A(
                    bitmap._data[bucket] >> bucketStartIndex
                );
                amount -= (256 - bucketStartIndex);
                bucket++;

                while(amount > 256) {
                    // Add every set from the entire board
                    count += Popcount.popcount256A(bitmap._data[bucket]);
                    amount -= 256;
                    bucket++;
                }
                // Mask the final board and add the sets
                count += Popcount.popcount256A(
                    bitmap._data[bucket] & ((1 << (amount)) - 1)
                );
            }
        }
    }


    /**
     * @dev Find the closest index of the set bit of lesser significance from `index`.
     */
    function scanForward(BitMap storage bitmap, uint256 index) internal view returns (uint256 setBitIndex) {
        uint256 bucket = index >> 8;

        // index within the bucket
        uint256 bucketIndex = (index & 0xff);

        // load a bitboard from the bitmap.
        uint256 bb = bitmap._data[bucket];

        // Mask the board to the given index and all lesser significant bits
        bb = bb & ((1 << (bucketIndex)) - 1);
        
        if(bb > 0) {
            // Get the most significant bit of the masked board (overflowed so subtract 255)
            unchecked {
                setBitIndex = (bucket << 8) | (255 -  bb.bitScanReverse256());
            }
        } else {
            while(true) {
                require(bucket > 0, "BitMaps: The set bit before the index doesn't exist.");
                unchecked {
                    bucket--;
                }
                // No offset. Always scan from the most significiant bit now.
                bb = bitmap._data[bucket];
                
                if(bb > 0) {
                    unchecked {
                        setBitIndex = (bucket << 8) | (255 -  bb.bitScanReverse256());
                        break;
                    }
                } 
            }
        }
    }

    function getBucket(BitMap storage bitmap, uint256 bucket) internal view returns (uint256) {
        return bitmap._data[bucket];
    }
}