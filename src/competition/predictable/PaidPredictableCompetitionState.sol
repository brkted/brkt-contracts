// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {UD60x18} from "@prb/math/UD60x18.sol";

import {BitMaps} from "src/libraries/BitMaps.sol";
import {IPaidPredictableCompetition, RegistrationFeeInfo} from "src/interfaces/IPaidPredictableCompetition.sol";
import {PredictableCompetition} from "./PredictableCompetition.sol";

/// @title Paid Predictable Competition State
/// @author BRKT
/// @notice Contract used to hold the contract state and shared functions that read/write state
abstract contract PaidPredictableCompetitionState is PredictableCompetition {
    using EnumerableSet for EnumerableSet.AddressSet;
    using BitMaps for BitMaps.BitMap;

    error InvalidExpiration();
    error NoRegistrationFee();
    error IncorrectRegistrationFeePaid();
    error IncorrectRegistrationToken();
    error InvalidRegistrationFeeInfo();
    error UserNotRegistered(address user);
    error NoPendingRewards(address user);
    error SafeTransferEthFailed();
    error NoProtocolFeesCaptured();

    event ProtocolFeesClaimed(address _owner, uint256 _amount);

    /**
     * @notice The total amount of registration fees collected through users creating bracket predictions
     */
    uint256 public totalRegistrationReserves;

    /**
     * @notice Registration fee information for the competition
     */
    RegistrationFeeInfo internal registrationFeeInfo;

    /**
     * @dev Input1 address: The user address
     * @dev Output bool: Whether the user has claimed their rewards
     */
    mapping(address => bool) internal claimedRewards;

    /**
     * @dev Input1 address: The user address
     * @dev Output UD60x18: The multiplier for the user's payment in fixed point. If 0, assume the user does not have a prediction
     */
    mapping(address => UD60x18) internal userToPaymentMultiplier;

    /**
     * @dev Input1 uint256: The match number
     * @dev Input2 uint8: The winning team id
     * @dev Output UD60x18: The total of all multipliers for the match outcome
     */
    mapping(uint256 => mapping(uint8 => UD60x18)) internal matchPredictionsToMultipliers;

    constructor(address _competitionFactory) PredictableCompetition(_competitionFactory) {}
}
