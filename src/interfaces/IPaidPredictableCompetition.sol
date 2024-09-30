// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IPredictableCompetition} from "src/interfaces/IPredictableCompetition.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";

struct RegistrationFeeInfo {
    bool isNetworkToken;
    address paymentToken;
    uint256 fee;
}

/// @title Competition Interface
/// @notice Manages Competition buy-ins, payouts, round progression, etc
interface IPaidPredictableCompetition is IPredictableCompetition {
    /**
     * @dev Emitted when a user pays the registration fee. This will only happen the first time a user submits a bracket,
     *  since they can make changes until the competition starts
     * @param user The user submitting the bracket prediction
     * @param feeInfo The fee info for creating bracket predictions in this competition
     */
    event UserPaidForBracketPrediction(address indexed user, RegistrationFeeInfo feeInfo);

    /**
     * @dev Emitted when a user increases their registration fee multiplier.
     * @param user The user submitting the bracket prediction
     * @param feeInfo The fee info for creating bracket predictions in this competition
     */
    event UserIncreasedBracketPrediction(address indexed user, RegistrationFeeInfo feeInfo);

    /**
     * @dev Emitted when a user is refunded the registration fee. This will only happen if the competition has expired
     * @param user The user who was refunded
     * @param amount The amount of the fee that was refunded
     */
    event UserRefundedForBracket(address indexed user, uint256 amount);

    /**
     * @dev Emitted when a user claims their reward at the end of the competition
     * @param user The user who claimed the rewards
     * @param amount The amount of the reward that was claimed (in the payment token's decimal precision)
     */
    event UserClaimedRewards(address indexed user, uint256 amount);

    /**
     * @notice sets required state for the competition
     * @param _competitionOwner The owner of the competition
     * @param _competitionName The name of the competition
     * @param _numTeams The number of teams in the competition
     * @param _startingEpoch The epoch time when the competition starts
     * @param _expirationEpoch The epoch time when the competition expires
     * @param _bannerURI The URI for the competition's banner
     * @param _totalPointsPerRound The total points available for each round of the competition
     * @param _registrationFeeInfo The bracket creation fee information for the competition
     */
    function initialize(
        address _competitionOwner,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI,
        uint16 _totalPointsPerRound,
        RegistrationFeeInfo memory _registrationFeeInfo
    ) external;

    /**
     * @dev Overrides IPredictableCompetition.createBracketPrediction to require an ERC20 fee payment if ERC20 is the fee token
     * @inheritdoc IPredictableCompetition
     */
    function createBracketPrediction(address _user, uint8[] calldata _matchPredictions) external;

    /**
     * @dev Submits a bracket prediction for this competition using the network token (eth, matic, etc).
     *  Can only be called before the competition has started
     * @param _registrant The user who is submitting the bracket prediction
     * @param _matchPredictions The user's predictions for each match. Each uint8 is the team id for the match at array index
     */
    function createBracketPredictionGasToken(address _registrant, uint8[] calldata _matchPredictions)
        external
        payable;

    /**
     * @dev Allows the user to send funds to increase their payment multiplier for their current predictions.
     * @param _registrant The user to increase the multiplier for
     */
    function increasePredictionPaymentMultiplier(address _registrant) external;

    /**
     * @dev Allows the user to send funds to increase their payment multiplier for their current predictions.
     * @param _registrant The user to increase the multiplier for
     */
    function increasePredictionPaymentMultiplierGasToken(address _registrant) external payable;

    /**
     * @dev Refunds the registration fee to the sender if the competition has expired and the sender created a bracket prediction
     */
    function refundRegistrationFee() external;

    /**
     * @dev Collects the reward for the sending user. Can only be called when the competition is completed
     */
    function claimRewards() external;

    /**
     * @dev Calculates the reward for the given user. Will only calculate the reward
     *  if the competition is completed and the user has not claimed it yet
     * @param _user The user to calculate the reward for
     * @return pendingRewards_ The pending reward for the user with the payment token's decimal precision
     */
    function calculatePendingRewards(address _user) external view returns (uint256 pendingRewards_);

    /**
     * @return feeInfo_ The fee info for creating bracket predictions in this competition
     */
    function getBracketPredictionFeeInfo() external view returns (RegistrationFeeInfo memory feeInfo_);

    /**
     *
     * @param _user The user to get the payment multiplier for
     * @return The payment multiplier for the user
     */
    function getUserPaymentMultiplier(address _user) external view returns (UD60x18);

    /**
     * @dev Calculates the total amount of protocol fees captured by the competition, to be claimed by the owner.
     */
    function calculateProtocolFeeCaptured() external view returns (uint256);

    /**
     * @dev Allows the owner to claim the protocol fees captured by the competition after the competition has
     * successfully ended.
     */
    function claimProtocolFees() external;
}
