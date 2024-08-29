// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Competition, ICompetition} from "src/competition/base/Competition.sol";
import {BitMaps} from "src/libraries/BitMaps.sol";

/// @title Competition State
/// @author BRKT
/// @notice Contract used to hold the contract state and shared functions that read/write state
abstract contract PredictableCompetitionState is Competition {
    using EnumerableSet for EnumerableSet.AddressSet;
    using BitMaps for BitMaps.BitMap;

    error InvalidCompetitionPredictionLength(uint256 _expectedLength, uint256 _actualLength);

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //       -'~'-.,__,.-'~'-.,__,.- VARS -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    /**
     * @notice The total number of points available for the competition.
     *  Calculated as a static 32 points per round with 2 decimals (so 32 points is 3200), which increases the value
     *  of correct predictions as rounds progress.
     */
    uint16 public totalPointsAvailable;

    /**
     * @notice The total number of points available per round. Currently set to 3200 which is 32 points with 2 decimals.
     *  Can be customizable in the future.
     */
    uint16 public totalPointsPerRound;

    /**
     * @dev Input1 uint256: The match number
     * @dev Input2 uint8: The winning team id
     * @dev Output EnumerableSet: The set of users who predicted the winning team for the match
     */
    mapping(uint256 => mapping(uint8 => EnumerableSet.AddressSet)) internal matchPredictionsToUser;

    /**
     * @dev Input1 address: The user address
     * @dev Input2 uint8[]: The array of predictions for the user
     */
    mapping(address => uint8[]) internal userBracketPredictions;

    /**
     * @dev A set of all users who have registered for the competition. Used to prevent users from registering multiple times.
     */
    EnumerableSet.AddressSet internal _registeredUsers;

    constructor(address _competitionFactory) Competition(_competitionFactory) {}
}

