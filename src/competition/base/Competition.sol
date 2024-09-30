// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CompetitionState, BitMaps, ICompetitionFactory} from "./CompetitionState.sol";
import {ICompetition, MatchOutcome} from "src/interfaces/ICompetition.sol";

/// @title Competition Management
/// @author BRKT
/// @notice Contract used to management all aspects of a competition.
///  This includes bracket buy-ins, payouts, round progression, gates, etc
contract Competition is CompetitionState, ICompetition {
    using EnumerableSet for EnumerableSet.AddressSet;
    using BitMaps for BitMaps.BitMap;

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //       -'~'-.,__,.-'~'-.,__,.- VARS -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    constructor(address _competitionFactory) CompetitionState(_competitionFactory) {}

    /**
     * @inheritdoc ICompetition
     */
    function initialize(
        address _competitionOwner,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI
    ) external override {
        _initializeCompetition(
            _competitionOwner, _competitionName, _numTeams, _startingEpoch, _expirationEpoch, _teamNames, _bannerURI
        );
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- EXTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    /**
     * @inheritdoc ICompetition
     */
    function start() public onlyOwner whenNotExpired {
        _hasStarted = true;
        startingEpoch = uint64(block.timestamp);
    }

    /**
     * @inheritdoc ICompetition
     */
    function setTeamNames(string[] calldata _names) public onlyOwner whenNotLive {
        _setTeamNames(_names);
    }

    /**
     * @inheritdoc ICompetition
     */
    function completeMatch(uint256 _matchId, uint8 _winningTeamId) external onlyOwner whenInProgress {
        _completeMatch(_matchId, _winningTeamId);
    }

    /**
     * @inheritdoc ICompetition
     */
    function advanceRound(uint8[] calldata _matchResults) public onlyOwner whenInProgress {
        _advanceRound(_matchResults);
    }

    /**
     * @inheritdoc ICompetition
     */
    function advanceRound() public onlyOwner whenInProgress {
        _advanceRound();
    }

    /**
     * @inheritdoc ICompetition
     */
    function getCompetitionProgression() public view returns (MatchOutcome[] memory bracketProgress_) {
        bracketProgress_ = bracketProgression;
    }

    /**
     * @inheritdoc ICompetition
     */
    function getMatchOutcome(uint256 _matchId) external view returns (MatchOutcome memory matchOutcome_) {
        if (_matchId < bracketProgression.length) {
            matchOutcome_ = bracketProgression[_matchId];
        }
    }

    function getTeamNames() external view override returns (string[] memory teamNames_) {
        teamNames_ = new string[](numTeams);
        for (uint256 i = 0; i < numTeams; i++) {
            teamNames_[i] = teamNames[i];
        }
    }

    function hasStarted() public view returns (bool) {
        return _hasStarted || block.timestamp >= startingEpoch;
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- INTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    function _initializeCompetition(
        address _competitionOwner,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI
    ) internal {
        if (msg.sender != address(competitionFactory)) {
            revert NotFactory(msg.sender);
        }
        if (_startingEpoch <= block.timestamp) {
            revert InvalidStartTime();
        }
        if (_teamNames.length != _numTeams) {
            revert TeamNamesMismatch(_numTeams, _teamNames.length);
        }
        if (_numTeams > MAX_TEAMS) {
            revert TooManyTeams(_numTeams);
        }
        _transferOwnership(_competitionOwner);
        competitionName = _competitionName;
        startingEpoch = _startingEpoch;
        bannerURI = _bannerURI;
        numTeams = _numTeams;
        uint256 numTeamsCur = 2; // Can't have a bracket with less than 2 teams
        uint16 _numRounds = 1; // Minimum 2 teams gives 1 round
        while (numTeamsCur < _numTeams) {
            _numRounds++;
            numTeamsCur = 2 ** _numRounds;
        }
        if (numTeamsCur != _numTeams) {
            revert InvalidNumberOfTeams(_numTeams);
        }
        totalRounds = _numRounds;
        roundsRemaining = _numRounds;

        // If the user doesn't specify an expiration, assume they don't want the competition to expire
        expirationEpoch = _expirationEpoch == 0 ? type(uint64).max : _expirationEpoch;
        for (uint256 i = 0; i < numTeams - 1; i++) {
            // Solidity compiler doesn't implicitly do this via new MatchOutcome[](numTeams - 1),
            //  so we need to do this manually to ensure the proper length bracketProgression and
            //  the ability to overwrite via index
            bracketProgression.push(MatchOutcome(0, false));
            teamNames[i] = _teamNames[i];
        }
        teamNames[numTeams - 1] = _teamNames[numTeams - 1];
    }

    function _setTeamNames(string[] calldata _names) internal {
        if (_names.length != numTeams) {
            revert InvalidNumberOfTeams(_names.length);
        }
        for (uint256 i = 0; i < numTeams; i++) {
            teamNames[i] = _names[i];
        }
    }

    function _completeMatch(uint256 _matchId, uint8 _winningTeamId) internal virtual {
        uint256 matchesCur = _getCurRoundMatchesNum();
        uint256 startingIdx = numTeams - _getTeamSizeCur();
        if (_matchId >= matchesCur + startingIdx || _matchId < startingIdx) {
            revert InvalidMatchId(_matchId);
        }
        if (bracketProgression[_matchId].isCompleted) {
            revert MatchAlreadyCompleted(_matchId);
        }
        // For trustlessness, we should check that the winning team is competing in this match
        bracketProgression[_matchId] = MatchOutcome(_winningTeamId, true);

        emit MatchCompleted(_matchId, _winningTeamId);
    }

    function _advanceRound(uint8[] calldata _matchResults) internal {
        if (roundsRemaining == 0) {
            revert RoundAlreadyAtEnd();
        }
        _saveCompetitionProgress(_matchResults);
        roundsRemaining--;

        if (roundsRemaining == 0) {
            hasFinished = true;
        }
    }

    function _advanceRound() internal {
        if (roundsRemaining == 0) {
            revert RoundAlreadyAtEnd();
        }
        uint256 matchesCur = _getCurRoundMatchesNum();
        uint256 startingIdx = numTeams - _getTeamSizeCur();
        for (uint256 i = startingIdx; i < matchesCur + startingIdx; i++) {
            if (!bracketProgression[i].isCompleted) {
                revert MatchNotCompleted(i);
            }
        }
        roundsRemaining--;

        if (roundsRemaining == 0) {
            hasFinished = true;
        }
    }

    function _saveCompetitionProgress(uint8[] memory _matchResults) internal {
        uint256 teamSizeCur = _getTeamSizeCur();
        uint256 numMatches = _matchResults.length;
        if (numMatches != teamSizeCur / 2) {
            revert InvalidCompetitionResultsLength(teamSizeCur / 2, numMatches);
        }
        // The starting index will always be the difference in starting team to current team size.
        // This is because the team size goes down 1/2 each round, which is proportionate with the number of matches
        uint256 startingIdx = numTeams - teamSizeCur;
        for (uint256 i = 0; i < numMatches; i++) {
            if (!bracketProgression[i + startingIdx].isCompleted) {
                bracketProgression[i + startingIdx] = MatchOutcome(_matchResults[i], true);
            }
        }
    }

    function _getTeamSizeCur() internal view returns (uint256 teamSizeCur_) {
        teamSizeCur_ = 2 ** roundsRemaining;
    }

    function _getCurRoundMatchesNum() internal view returns (uint256 matchesCur_) {
        matchesCur_ = _getTeamSizeCur() / 2;
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //    -'~'-.,__,.-'~'-.,__,.- MODIFIERS -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    modifier whenLive() {
        if (!hasStarted()) {
            revert CompetitionNotLive();
        }
        _;
    }

    modifier whenNotLive() {
        if (hasStarted()) {
            revert CompetitionIsLive();
        }
        _;
    }

    modifier whenCompleted() {
        if (!hasFinished) {
            revert CompetitionNotCompleted();
        }
        _;
    }

    /**
     * @dev A competition is in progress when it has started, hasn't finished, and is not expired
     */
    modifier whenInProgress() {
        if (!hasStarted()) {
            revert CompetitionNotLive();
        }
        if (hasFinished) {
            revert CompetitionCompleted();
        }
        if (block.timestamp >= expirationEpoch) {
            revert CompetitionHasExpired();
        }
        _;
    }

    /**
     * @dev A competition is not expired if the competition has not been finished and is not past the expiration epoch
     */
    modifier whenNotExpired() {
        if (!hasFinished && block.timestamp >= expirationEpoch) {
            revert CompetitionHasExpired();
        }
        _;
    }

    /**
     * @dev A competition is expired if the competition has not been finished and is past the expiration epoch
     */
    modifier whenExpired() {
        if (hasFinished || block.timestamp < expirationEpoch) {
            revert CompetitionNotExpired();
        }
        _;
    }
}
