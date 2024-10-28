// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PredictableCompetitionState, BitMaps, Competition, ICompetition} from "./PredictableCompetitionState.sol";
import {IPredictableCompetition} from "src/interfaces/IPredictableCompetition.sol";

/// @title Predictable Competition Management
/// @author BRKT
/// @notice Contract used to management all aspects of a competition.
///  This includes bracket buy-ins, payouts, round progression, gates, etc
contract PredictableCompetition is PredictableCompetitionState, IPredictableCompetition {
    using EnumerableSet for EnumerableSet.AddressSet;
    using BitMaps for BitMaps.BitMap;

    constructor(address _competitionFactory) PredictableCompetitionState(_competitionFactory) {}

    // /**
    //  * @inheritdoc IPredictableCompetition
    //  */
    function initialize(
        address _competitionOwner,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI,
        uint16 _totalPointsPerRound
    ) external virtual {
        _initializePredictable(
            _competitionOwner,
            _competitionName,
            _numTeams,
            _startingEpoch,
            _expirationEpoch,
            _teamNames,
            _bannerURI,
            _totalPointsPerRound
        );
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- EXTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    /**
     * @inheritdoc IPredictableCompetition
     */
    function createBracketPrediction(address _registrant, uint8[] calldata _matchPredictions)
        public
        virtual
        whenNotLive
    {
        _saveUserPrediction(_registrant, _matchPredictions);
    }

    /**
     * @inheritdoc IPredictableCompetition
     */
    function getUserBracketPrediction(address _user) public view returns (uint8[] memory bracketPrediction_) {
        bracketPrediction_ = userBracketPredictions[_user];
    }

    /**
     * @inheritdoc IPredictableCompetition
     */
    function hasUserRegistered(address _user) public view returns (bool isRegistered_) {
        isRegistered_ = _registeredUsers.contains(_user);
    }

    /**
     * @inheritdoc IPredictableCompetition
     */
    function getTotalScore() external view returns (uint256 totalScore_) {
        uint256 numMatches = (numTeams / 2);
        uint256 numMatchesPrev;
        // Subtracting the current number of matches from the total team size will get us the index of the last match in the current round
        // This lets us get realtime updates to the score as the round progresses
        // If the competition is completed, the ending match should be the total number of matches
        uint256 endingMatch = hasFinished ? numTeams - 1 : numTeams - _getCurRoundMatchesNum();
        uint256 pointsPerMatchCur = totalPointsPerRound / numMatches;
        for (uint256 i = 0; i < endingMatch; i++) {
            if (bracketProgression[i].isCompleted) {
                totalScore_ += _getTotalPoints(pointsPerMatchCur, i, bracketProgression[i].winningTeamId);
            }
            // Update the points and matches per round when we reach the end of each round
            // Don't update if it's the final match
            if (i < endingMatch - 1 && i + 1 == numMatches + numMatchesPrev) {
                numMatchesPrev += numMatches;
                numMatches /= 2;
                pointsPerMatchCur = totalPointsPerRound / numMatches;
            }
        }
    }

    /**
     * @inheritdoc IPredictableCompetition
     */
    function getUserScorePercent(address _user) external view returns (uint256 scorePercent_) {
        scorePercent_ = _getUserScorePercent(_user);
    }

    /**
     * @inheritdoc IPredictableCompetition
     */
    function getUserBracketScore(address _user) public view returns (uint256 score_) {
        uint256 numMatches = (numTeams / 2);
        uint256 numMatchesPrev;
        // Subtracting the current number of matches from the total team size will get us the index of the last match in the current round
        // This lets us get realtime updates to the score as the round progresses
        // If the competition is completed, the ending match should be the total number of matches
        uint256 endingMatch = hasFinished ? numTeams - 1 : numTeams - _getCurRoundMatchesNum();
        uint256 pointsPerMatchCur = totalPointsPerRound / numMatches;
        for (uint256 i = 0; i < endingMatch; i++) {
            if (
                bracketProgression[i].isCompleted
                    && matchPredictionsToUser[i][bracketProgression[i].winningTeamId].contains(_user)
            ) {
                score_ += _getUserPointsPerMatch(_user, pointsPerMatchCur);
            }
            // Update the points and matches per round when we reach the end of each round
            // Don't update if it's the final match
            if (i < endingMatch - 1 && i + 1 == numMatches + numMatchesPrev) {
                numMatchesPrev += numMatches;
                numMatches /= 2;
                pointsPerMatchCur = totalPointsPerRound / numMatches;
            }
        }
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- INTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    function _initializePredictable(
        address _competitionOwner,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI,
        uint16 _totalPointsPerRound
    ) internal {
        _initializeCompetition(
            _competitionOwner, _competitionName, _numTeams, _startingEpoch, _expirationEpoch, _teamNames, _bannerURI
        );

        totalPointsPerRound = _totalPointsPerRound;
        totalPointsAvailable = uint16(totalRounds * totalPointsPerRound);
    }

    function _saveUserPrediction(address _user, uint8[] calldata _matchPredictions) internal {
        uint256 numMatches = _matchPredictions.length;
        bool hasBracket = _registeredUsers.contains(_user);
        if (numMatches != numTeams - 1) {
            revert InvalidCompetitionPredictionLength(numTeams - 1, numMatches);
        }
        for (uint256 i = 0; i < numMatches; i++) {
            if (!hasBracket) {
                matchPredictionsToUser[i][_matchPredictions[i]].add(_user);
                _addUserMatchPrediction(_user, i, _matchPredictions[i]);
                continue;
            }
            if (matchPredictionsToUser[i][_matchPredictions[i]].contains(_user)) {
                continue; // Same as previous prediction, no need to update
            }
            // Remove old prediction and save new one
            _removeUserMatchPrediction(_user, i, userBracketPredictions[_user][i]);
            _addUserMatchPrediction(_user, i, _matchPredictions[i]);
        }
        _registeredUsers.add(_user);
        userBracketPredictions[_user] = _matchPredictions;

        emit BracketPredictionSaved(msg.sender, _user);
    }

    function _addUserMatchPrediction(address _user, uint256 _matchIndex, uint8 _teamId) internal virtual {
        matchPredictionsToUser[_matchIndex][_teamId].add(_user);
    }

    function _removeUserMatchPrediction(address _user, uint256 _matchIndex, uint8 _teamId) internal virtual {
        matchPredictionsToUser[_matchIndex][_teamId].remove(_user);
    }

    function _getUserScorePercent(address _user) internal view returns (uint256 scorePercent_) {
        if (!hasUserRegistered(_user)) {
            return 0;
        }
        uint256 numMatches = (numTeams / 2);
        uint256 numMatchesPrev;
        // Subtracting the current number of matches from the total team size will get us the index of the last match in the current round
        // This lets us get realtime updates to the score as the round progresses
        // If the competition is completed, the ending match should be the total number of matches
        uint256 endingMatch = hasFinished ? numTeams - 1 : numTeams - _getCurRoundMatchesNum();

        uint256 pointsPerMatchCur = totalPointsPerRound / numMatches;
        uint256 totalPoints;
        uint256 userPoints;
        for (uint256 i = 0; i < endingMatch; i++) {
            if (
                bracketProgression[i].isCompleted
                    && matchPredictionsToUser[i][bracketProgression[i].winningTeamId].contains(_user)
            ) {
                userPoints += _getUserPointsPerMatch(_user, pointsPerMatchCur);
            }
            // todo: make virtual function to return totalPoints to add here for paid to overwrite to increase by
            // multiplier
            totalPoints += _getTotalPoints(pointsPerMatchCur, i, bracketProgression[i].winningTeamId);
            // Update the points and matches per round when we reach the end of each round
            // Don't update if it's the final match
            if (i < endingMatch - 1 && i + 1 == numMatches + numMatchesPrev) {
                numMatchesPrev += numMatches;
                numMatches /= 2;
                if (numMatches > 0) {
                    pointsPerMatchCur = totalPointsPerRound / numMatches;
                } else {
                    pointsPerMatchCur = 0;
                }
            }
        }
        // Return the score as a percentage of the total possible score with 6 decimal places of precision
        if(totalPoints != 0) {
            scorePercent_ = (userPoints * 1e6) / totalPoints;
        }
    }

    /**
     * @dev Allow the calculation of user points per match to be overridden and enhanced
     * @param  (_user)The address of the user to calculate the points for
     * @param _pointsPerMatchCur The points per match for the current round without any further calculations
     */
    function _getUserPointsPerMatch(address, uint256 _pointsPerMatchCur)
        internal
        view
        virtual
        returns (uint256 pointsPerMatch_)
    {
        pointsPerMatch_ = _pointsPerMatchCur;
    }

    function _getTotalPoints(uint256 _pointsPerMatchCur, uint256 _matchIndex, uint8 _winningTeamId)
        internal
        view
        virtual
        returns (uint256 totalPoints_)
    {
        totalPoints_ = (_pointsPerMatchCur * matchPredictionsToUser[_matchIndex][_winningTeamId].length());
    }
}
