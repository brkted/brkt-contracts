// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

/// @title Competition Router Interface
/// @notice Handles requests to every competition
interface ICompetitionRouter {
    /**
     * @dev Submits a bracket prediction for a competition
     * @param _competitionId The unique id of the competition
     * @param _matchPredictions The user's predictions for each match. Each uint8 is the team id for the match at array index
     */
    function createBracketPrediction(bytes32 _competitionId, uint8[] calldata _matchPredictions) external payable;
    /**
     * @dev Sets the factory address for the competition router. Only callable by the owner
     * @param _factoryAddr The address of the competition factory
     */
    function setFactory(address _factoryAddr) external;

    /**
     * @dev Returns the team names for the given competition
     * @param _competitionId The unique id of the competition
     */
    function getTeamNames(bytes32 _competitionId) external view returns (string[] memory teamNames_);
}
