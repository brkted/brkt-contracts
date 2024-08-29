// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {BitMaps} from "src/libraries/BitMaps.sol";
import {MatchOutcome} from "src/interfaces/ICompetition.sol";
import {ICompetitionFactory} from "src/interfaces/ICompetitionFactory.sol";

import "forge-std/console.sol";

/// @title Competition State
/// @author BRKT
/// @notice Contract used to hold the contract state and shared functions that read/write state
abstract contract CompetitionState is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using BitMaps for BitMaps.BitMap;

    error NotFactory(address sender);
    error InvalidStartTime();
    error InvalidMatchId(uint256 matchId);
    error MatchNotCompleted(uint256 matchId);
    error MatchAlreadyCompleted(uint256 matchId);
    error TooManyTeams(uint256 numTeams);
    error InvalidNumberOfTeams(uint256 numTeams);
    error TeamNamesMismatch(uint256 numTeams, uint256 numTeamNames);
    error CompetitionNotCompleted();
    error CompetitionNotLive();
    error CompetitionIsLive();
    error CompetitionStillInProgress();
    error CompetitionHasExpired();
    error CompetitionNotExpired();
    error CompetitionCompleted();
    error RoundAlreadyAtEnd();
    error InvalidCompetitionResultsLength(uint256 expectedLength, uint256 actualLength);

    uint256 public constant MAX_TEAMS = 256;

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //       -'~'-.,__,.-'~'-.,__,.- VARS -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    /**
     * @notice The factory that created this competition
     */
    ICompetitionFactory public competitionFactory;

    /**
     * @notice The name of the competition
     */
    string public competitionName;

    /**
     * @notice The URI for the competition's banner image
     */
    string public bannerURI;

    // Packed storage slot: 192
    // numTeams <> hasFinished: 16 + 16 + 16 + 64 + 64 + 8 + 8
    /**
     * @notice The number of teams in the competition
     */
    uint16 public numTeams;
    /**
     * @notice The total number of rounds in the competition
     */
    uint16 public totalRounds;
    /**
     * @notice The number of rounds remaining in the competition
     */
    uint16 public roundsRemaining;
    /**
     * @notice The epoch time when the competition starts
     */
    uint64 public startingEpoch;
    /**
     * @notice The epoch time when the competition expires
     */
    uint64 public expirationEpoch;
    /**
     * @notice Whether the competition has started
     */
    bool internal _hasStarted;
    /**
     * @notice Whether the competition has finished
     */
    bool public hasFinished;

    /**
     * @dev Holds the human friendly names of the teams. Used to reduce confusion when integrating into front ends for
     *  handling bracket management/predictions/etc
     * @dev Input uint256: Team id
     * @dev Output string: Team name
     */
    mapping(uint256 => string) public teamNames;

    /**
     * @dev Array of team ids denoting the winner of the match at the array's index
     */
    MatchOutcome[] internal bracketProgression;

    constructor(address _competitionFactory) {
        competitionFactory = ICompetitionFactory(_competitionFactory);
    }
}
