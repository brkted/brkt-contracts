// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import "forge-std/console.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {mulDiv} from "@prb/math/Common.sol";

import {
    PaidPredictableCompetitionState,
    IPaidPredictableCompetition,
    PredictableCompetition,
    BitMaps,
    RegistrationFeeInfo
} from "./PaidPredictableCompetitionState.sol";
import {IPredictableCompetition} from "src/interfaces/IPredictableCompetition.sol";

/// @title Paid Competition Management
/// @author BRKT
/// @notice Contract used to management all aspects of a competition.
///  This includes bracket buy-ins, payouts, round progression, gates, etc
contract PaidPredictableCompetition is PaidPredictableCompetitionState, IPaidPredictableCompetition {
    using EnumerableSet for EnumerableSet.AddressSet;
    using BitMaps for BitMaps.BitMap;

    constructor(address _competitionFactory) PaidPredictableCompetitionState(_competitionFactory) {}

    // /**
    //  * @inheritdoc IPaidPredictableCompetition
    //  */
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
    ) external override {
        _initializePaidPredictable(
            _competitionOwner,
            _competitionName,
            _numTeams,
            _startingEpoch,
            _expirationEpoch,
            _teamNames,
            _bannerURI,
            _totalPointsPerRound,
            _registrationFeeInfo
        );
    }

    function _initializePaidPredictable(
        address _competitionOwner,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI,
        uint16 _totalPointsPerRound,
        RegistrationFeeInfo memory _registrationFeeInfo
    ) internal {
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

        if (_expirationEpoch == 0) {
            revert InvalidExpiration();
        }
        registrationFeeInfo = _registrationFeeInfo;
        // If a fee was given there must be a payment token (or defined as a network payment token)
        if (
            registrationFeeInfo.fee != 0 && registrationFeeInfo.paymentToken == address(0)
                && !registrationFeeInfo.isNetworkToken
        ) {
            revert InvalidRegistrationFeeInfo();
        }
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- EXTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    /**
     * @inheritdoc IPredictableCompetition
     */
    function createBracketPrediction(address _registrant, uint8[] calldata _matchPredictions)
        public
        override(PredictableCompetition, IPaidPredictableCompetition)
        whenNotLive
    {
        if (registrationFeeInfo.fee != 0) {
            if (registrationFeeInfo.isNetworkToken) {
                revert IncorrectRegistrationToken();
            }
            // If the user is changing a prediction prior to the competition starting,
            // they don't need to pay the registration fee again
            if (_registeredUsers.contains(_registrant)) {
                // Revert if any new tokens were sent to the contract as payment
                if (IERC20(registrationFeeInfo.paymentToken).balanceOf(address(this)) != totalRegistrationReserves) {
                    revert IncorrectRegistrationFeePaid();
                }
            } else {
                // If the user hasn't paid the registration fee yet, they need to pay it now and emit the payment event
                uint256 _bal = IERC20(registrationFeeInfo.paymentToken).balanceOf(address(this));
                if (_bal < totalRegistrationReserves + registrationFeeInfo.fee) {
                    revert IncorrectRegistrationFeePaid();
                }
                UD60x18 _paid = ud(_bal - totalRegistrationReserves);
                UD60x18 _multiplier = _paid.div(ud(registrationFeeInfo.fee));
                userToPaymentMultiplier[_registrant] = _multiplier;

                // Any overpayment is allocated to the registrant as a multiplier for rewards
                totalRegistrationReserves += _paid.intoUint256();
                emit UserPaidForBracketPrediction(
                    _registrant,
                    RegistrationFeeInfo({
                        isNetworkToken: registrationFeeInfo.isNetworkToken,
                        fee: _paid.intoUint256(),
                        paymentToken: registrationFeeInfo.paymentToken
                    })
                );
            }
        }
        super.createBracketPrediction(_registrant, _matchPredictions);
    }

    /**
     * @inheritdoc IPaidPredictableCompetition
     */
    function increasePredictionPaymentMultiplier(address _registrant) external whenNotLive {
        if (registrationFeeInfo.fee == 0) {
            revert NoRegistrationFee();
        }
        if (!_registeredUsers.contains(_registrant) || userToPaymentMultiplier[_registrant].intoUint256() == 0) {
            revert UserNotRegistered(_registrant);
        }
        if (registrationFeeInfo.isNetworkToken) {
            revert IncorrectRegistrationToken();
        }
        uint256 _bal = IERC20(registrationFeeInfo.paymentToken).balanceOf(address(this));
        if (_bal - totalRegistrationReserves == 0) {
            revert IncorrectRegistrationFeePaid();
        }
        UD60x18 _paid = ud(_bal - totalRegistrationReserves);
        UD60x18 _multiplier = _paid.div(ud(registrationFeeInfo.fee));
        userToPaymentMultiplier[_registrant] = userToPaymentMultiplier[_registrant].add(_multiplier);
        totalRegistrationReserves += _paid.intoUint256();
        emit UserIncreasedBracketPrediction(
            _registrant,
            RegistrationFeeInfo({
                isNetworkToken: registrationFeeInfo.isNetworkToken,
                fee: _paid.intoUint256(),
                paymentToken: registrationFeeInfo.paymentToken
            })
        );

        // Add multiplier to all match predictions the user has made
        uint8[] memory predictions = userBracketPredictions[_registrant];
        for (uint256 i = 0; i  < predictions.length; i ++) {
            uint8 _teamId = predictions[i];
            matchPredictionsToMultipliers[i][_teamId] = matchPredictionsToMultipliers[i][_teamId]
                .add(_multiplier);
        }
    }

    /**
     * @inheritdoc IPaidPredictableCompetition
     */
    function increasePredictionPaymentMultiplierGasToken(address _registrant) external payable whenNotLive {
        if (registrationFeeInfo.fee == 0) {
            revert NoRegistrationFee();
        }
        if (!_registeredUsers.contains(_registrant) || userToPaymentMultiplier[_registrant].intoUint256() == 0) {
            revert UserNotRegistered(_registrant);
        }
        if (!registrationFeeInfo.isNetworkToken) {
            revert IncorrectRegistrationToken();
        }
        if (msg.value == 0) {
            revert IncorrectRegistrationFeePaid();
        }
        UD60x18 _paid = ud(msg.value);
        UD60x18 _multiplier = _paid.div(ud(registrationFeeInfo.fee));
        userToPaymentMultiplier[_registrant] = userToPaymentMultiplier[_registrant].add(_multiplier);
        totalRegistrationReserves += _paid.intoUint256();
        emit UserIncreasedBracketPrediction(
            _registrant,
            RegistrationFeeInfo({
                isNetworkToken: registrationFeeInfo.isNetworkToken,
                fee: _paid.intoUint256(),
                paymentToken: registrationFeeInfo.paymentToken
            })
        );

        // Add multiplier to all match predictions the user has made
        uint8[] memory predictions = userBracketPredictions[_registrant];
        for (uint256 i = 0; i  < predictions.length; i ++) {
            uint8 _teamId = predictions[i];
            matchPredictionsToMultipliers[i][_teamId] = matchPredictionsToMultipliers[i][_teamId]
                .add(_multiplier);
        }
    }

    /**
     * @inheritdoc IPaidPredictableCompetition
     */
    function createBracketPredictionGasToken(address _registrant, uint8[] calldata _matchPredictions)
        external
        payable
        override
        whenNotLive
    {
        if (registrationFeeInfo.fee != 0) {
            if (!registrationFeeInfo.isNetworkToken) {
                revert IncorrectRegistrationToken();
            }
            // If the user is changing a prediction prior to the competition starting,
            // they don't need to pay the registration fee again
            if (_registeredUsers.contains(_registrant)) {
                if (msg.value != 0) {
                    revert IncorrectRegistrationFeePaid();
                }
            } else {
                // If the user hasn't paid the registration fee yet, they need to pay it now and emit the payment event
                if (msg.value < registrationFeeInfo.fee) {
                    revert IncorrectRegistrationFeePaid();
                }

                UD60x18 _paid = ud(msg.value);
                UD60x18 _multiplier = _paid.div(ud(registrationFeeInfo.fee));
                userToPaymentMultiplier[_registrant] = _multiplier;
                // Any overpayment is allocated to the registrant as a multiplier for rewards
                totalRegistrationReserves += _paid.intoUint256();
                emit UserPaidForBracketPrediction(
                    _registrant,
                    RegistrationFeeInfo({
                        isNetworkToken: registrationFeeInfo.isNetworkToken,
                        fee: _paid.intoUint256(),
                        paymentToken: registrationFeeInfo.paymentToken
                    })
                );
            }
        }
        _saveUserPrediction(_registrant, _matchPredictions);
    }

    /**
     * @inheritdoc IPaidPredictableCompetition
     */
    function refundRegistrationFee() external override whenExpired {
        if (registrationFeeInfo.fee == 0) {
            revert NoRegistrationFee();
        }
        if (!_registeredUsers.contains(msg.sender)) {
            revert UserNotRegistered(msg.sender);
        }
        uint256 _paid = ud(registrationFeeInfo.fee).mul(userToPaymentMultiplier[msg.sender]).intoUint256();
        _registeredUsers.remove(msg.sender);
        userToPaymentMultiplier[msg.sender] = ud(0);
        if (registrationFeeInfo.isNetworkToken) {
            _safeTransferETH(msg.sender, _paid);
        } else {
            IERC20(registrationFeeInfo.paymentToken).transfer(msg.sender, _paid);
        }
        totalRegistrationReserves -= _paid;

        emit UserRefundedForBracket(msg.sender, _paid);
    }

    /**
     * @inheritdoc IPaidPredictableCompetition
     */
    function claimRewards() external override whenCompleted {
        uint256 pendingRewards = calculatePendingRewards(msg.sender);
        if (pendingRewards == 0) {
            revert NoPendingRewards(msg.sender);
        }
        claimedRewards[msg.sender] = true;
        if (registrationFeeInfo.isNetworkToken) {
            payable(msg.sender).transfer(pendingRewards);
        } else {
            IERC20(registrationFeeInfo.paymentToken).transfer(msg.sender, pendingRewards);
        }
        emit UserClaimedRewards(msg.sender, pendingRewards);
    }

    /**
     * @inheritdoc IPaidPredictableCompetition
     */
    function calculatePendingRewards(address _user) public view override returns (uint256 pendingRewards_) {
        // Don't calculate pending rewards if the user has already claimed them, or if the competition hasn't finished yet
        if (!claimedRewards[_user] && hasFinished) {
            uint256 percentOfTotal = _getUserScorePercent(_user);
            // percentOfTotal is a number between 0 and 10000, so we divide by 10000 to get the relative amount of token
            pendingRewards_ = totalRegistrationReserves * percentOfTotal / 10000;
        }
    }

    /**
     * @inheritdoc IPaidPredictableCompetition
     */
    function getBracketPredictionFeeInfo() external view override returns (RegistrationFeeInfo memory) {
        return registrationFeeInfo;
    }

    /**
     * @inheritdoc IPaidPredictableCompetition
     */
    function getUserPaymentMultiplier(address _user) external view override returns (UD60x18) {
        return userToPaymentMultiplier[_user];
    }

    /**
     * @notice Also add a user's added multiplier from the match outcome the user is picking
     * @dev Adds tracking of the sum of all multipliers for a match outcome. Needed to calculate points with respect to
     * overpayment of registration
     */
    function _addUserMatchPrediction(address _user, uint256 _matchIndex, uint8 _teamId) internal override {
        super._addUserMatchPrediction(_user, _matchIndex, _teamId);
        // There are no multipliers if registration is free
        if (registrationFeeInfo.fee == 0) {
            return;
        }
        // If the match doesn't have a multiplier yet, set it to the user's multiplier to avoid having it be 0 (uninitialized)
        if (matchPredictionsToMultipliers[_matchIndex][_teamId].intoUint256() == 0) {
            matchPredictionsToMultipliers[_matchIndex][_teamId] = userToPaymentMultiplier[_user];
        } else {
            matchPredictionsToMultipliers[_matchIndex][_teamId] = matchPredictionsToMultipliers[_matchIndex][_teamId]
                .add(userToPaymentMultiplier[_user].sub(_multiplierUnit()));
        }
    }

    /**
     * @notice Also remove a user's added multiplier from the match outcome the user is changing
     * @dev Adds tracking of the sum of all multipliers for a match outcome. Needed to calculate points with respect to
     * overpayment of registration
     */
    function _removeUserMatchPrediction(address _user, uint256 _matchIndex, uint8 _teamId) internal override {
        super._removeUserMatchPrediction(_user, _matchIndex, _teamId);
        // There are no multipliers if registration is free
        if (registrationFeeInfo.fee == 0) {
            return;
        }
        // Assume that the match multiplier is >=1 since it must be added to when the user made the initial prediction
        matchPredictionsToMultipliers[_matchIndex][_teamId].sub(userToPaymentMultiplier[_user].sub(_multiplierUnit()));
    }

    function _getUserPointsPerMatch(address _user, uint256 _pointsPerMatchCur)
        internal
        view
        virtual
        override
        returns (uint256 pointsPerMatch_)
    {
        pointsPerMatch_ = ud(super._getUserPointsPerMatch(_user, _pointsPerMatchCur)).mul(
            userToPaymentMultiplier[_user]
        ).intoUint256();
    }

    function _getTotalPoints(uint256 _pointsPerMatchCur, uint256 _matchIndex, uint8 _winningTeamId)
        internal
        view
        virtual
        override
        returns (uint256 totalPoints_)
    {
        // console.log("multiplier unit: ", _multiplierUnit().intoUint256());
        // console.log("_pointsPerMatchCur %s", _pointsPerMatchCur);
        // console.log("deployer points %s, leet points %s, bob points %s", _getUserPointsPerMatch(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496,_pointsPerMatchCur), _getUserPointsPerMatch(0x0000000000000000000000000000000000001337,_pointsPerMatchCur), _getUserPointsPerMatch(0x0000000000000000000000000000000000000B0b,_pointsPerMatchCur));
        // console.log(
        //     "match %s team %s base totalPoints: ",
        //     _matchIndex,
        //     _winningTeamId,
        //     super._getTotalPoints(_pointsPerMatchCur, _matchIndex, _winningTeamId)
        // );
        // console.log(
        //     "match %s team %s multiplier: ",
        //     _matchIndex,
        //     _winningTeamId,
        //     matchPredictionsToMultipliers[_matchIndex][_winningTeamId].sub(_multiplierUnit()).intoUint256()
        // );
        // Multiply total points by the multipliers of every correct user match prediction
        totalPoints_ = ud(super._getTotalPoints(_pointsPerMatchCur, _matchIndex, _winningTeamId)).add(
            ud(_pointsPerMatchCur).mul(
                matchPredictionsToMultipliers[_matchIndex][_winningTeamId].sub(_multiplierUnit())
            )
        ).intoUint256();
    }

    function _multiplierUnit() internal view returns (UD60x18) {
        return ud(registrationFeeInfo.fee).div(ud(registrationFeeInfo.fee));
    }

    function _safeTransferETH(address _to, uint256 _value) internal {
        (bool success,) = _to.call{value: _value}(new bytes(0));
        if (!success) {
            revert SafeTransferEthFailed();
        }
    }
}
