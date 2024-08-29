// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ICompetition} from "src/interfaces/ICompetition.sol";

/// @title Competition Interface
/// @notice Manages Competition round progression, registration, etc
interface IPredictableCompetition is ICompetition {
    /**
     *
     * @param sender The address of the user who called the function
     * @param user The user submitting the bracket prediction
     */
    event BracketPredictionSaved(address indexed sender, address indexed user);

    /**
     * @notice sets required state for the competition
     * @param _competitionOwner The owner of the competition
     * @param _competitionName The name of the competition
     * @param _numTeams The number of teams in the competition
     * @param _startingEpoch The epoch time when the competition starts
     * @param _expirationEpoch The epoch time when the competition expires
     * @param _bannerURI The URI for the competition's banner
     * @param _totalPointsPerRound The total points available for each round of the competition
     */
    function initialize(
        address _competitionOwner,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI,
        uint16 _totalPointsPerRound
    ) external;

    /**
     * @dev Submits a bracket prediction for this competition. Can only be called before the competition has started
     * @param _user The user submitting the bracket prediction
     * @param _matchPredictions The user's predictions for each match. Each uint8 is the team id for the match at array index
     */
    function createBracketPrediction(address _user, uint8[] calldata _matchPredictions) external;

    /**
     * @param _user The user to check
     * @return bracketPrediction_ The user's bracket predictions for this competition. Each uint8 is the team id for the match at array index
     */
    function getUserBracketPrediction(address _user) external view returns (uint8[] memory bracketPrediction_);

    /**
     * @param _user The user to check
     * @return isRegistered_ Whether or not the user has created a bracket prediction for this competition
     */
    function hasUserRegistered(address _user) external view returns (bool isRegistered_);

    /**
     * @dev The returned score is multiplied by 100 to allow for 2 decimal places of precision.
     * @param _user The user to get score for
     * @return score_ The user's current score for this competition
     */
    function getUserBracketScore(address _user) external view returns (uint256 score_);

    /**
     * @dev The returned score is multiplied by 100 to allow for 2 decimal places of precision.
     *  This score is used to determine a user's rank in the competition
     * @return totalScore_ The total score for this competition
     */
    function getTotalScore() external view returns (uint256 totalScore_);

    /**
     *
     * @param _user The user to get score for
     * @return scorePercent_ The user's current score for this competition as a percentage of the total score with 4 decimal places of precision
     */
    function getUserScorePercent(address _user) external view returns (uint256 scorePercent_);
}
