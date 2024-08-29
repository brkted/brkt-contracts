// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

/**
 * @dev Struct to wrap a match outcome for a competition. Needed to ensure team id 0 isn't misunderstood
 *  when assessing the winning team id
 * @param winningTeamId The team id of the winning team. This is the index of the team name in the teamNames array
 * @param isCompleted Whether or not the match has been completed
 */
struct MatchOutcome {
    uint8 winningTeamId;
    bool isCompleted;
}

/// @title Competition Interface
/// @notice Manages Competition round progression, registration, etc
interface ICompetition {
    /**
     * @dev Emitted when a match is completed. Must be a match in the current round and the match must not be completed
     * @param _matchId The id of the match that was completed
     * @param _winningTeamId The team id of the winning team.
     */
    event MatchCompleted(uint256 indexed _matchId, uint8 indexed _winningTeamId);

    /**
     * @notice sets required state for the competition
     * @param _competitionOwner The owner of the competition
     * @param _competitionName The name of the competition
     * @param _numTeams The number of teams in the competition
     * @param _startingEpoch The epoch time when the competition starts
     * @param _expirationEpoch The epoch time when the competition expires
     * @param _bannerURI The URI for the competition's banner
     */
    function initialize(
        address _competitionOwner,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI
    ) external;

    /**
     * @dev Owner only function to start the competition, which allows for progression submissions
     */
    function start() external;

    /**
     * @dev Owner only function to set the team names
     * @param _names List of names for the teams. This is what communicates the team order and match-up apart
     *  from simply "0 vs 1" which could be mistaken as a different team than it is.
     */
    function setTeamNames(string[] calldata _names) external;

    /**
     * @dev Owner only function to submit the results of a match
     */
    function completeMatch(uint256 _matchId, uint8 _winningTeamId) external;

    /**
     * @dev Owner only function to progress to the next round
     */
    function advanceRound(uint8[] calldata _matchResults) external;

    /**
     * @dev Owner only function to progress to the next round. Requires every match in the current round to be completed
     */
    function advanceRound() external;

    /**
     * @dev Returns the current progression of this competition. Each MatchOutcome is the outcome of the match at the array index
     */
    function getCompetitionProgression() external view returns (MatchOutcome[] memory bracketProgress_);

    /**
     * @dev Returns the MatchOutcome for the given match id. Will be default values if the
     *  match is incomplete or out of the bounds of the competition
     */
    function getMatchOutcome(uint256 _matchId) external view returns (MatchOutcome memory matchOutcome_);

    /**
     * @dev Returns the team names for the competition
     */
    function getTeamNames() external view returns (string[] memory teamNames_);
}
