// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {RegistrationFeeInfo} from "src/interfaces/IPaidPredictableCompetition.sol";

enum CompetitionImpl {
    UNKNOWN,
    BASE,
    PREDICTABLE,
    PAID_PREDICTABLE
}

struct CompetitionInfo {
    address addr;
    CompetitionImpl impl;
}

/// @title Competition Factory Interface
/// @notice Manages Competition creation and retrieval
interface ICompetitionFactory {
    event CompetitionCreated(address sender, bytes32 indexed competitionId, address indexed addr, CompetitionImpl impl);

    function protocolFee() external view returns (uint256);

    /**
     * @dev Assumes that the impl type requires only `_numTeams` as a constructor arg
     * @param _competitionId The unique id of the competition
     * @param _competitionName The name of the competition
     * @param _numTeams The total number of teams in the competition
     * @param _startingEpoch The epoch at which the competition starts
     * @param _expirationEpoch The epoch at which the competition expires
     * @param _teamNames The names of the teams in the competition
     * @param _bannerURI The URI for the competition banner
     */
    function createCompetition(
        bytes32 _competitionId,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI
    ) external returns (address addr_);
    /**
     * @dev Assumes that the impl type requires only `_numTeams` as a constructor arg
     * @param _competitionId The unique id of the competition
     * @param _competitionName The name of the competition
     * @param _numTeams The total number of teams in the competition
     * @param _startingEpoch The epoch at which the competition starts
     * @param _expirationEpoch The epoch at which the competition expires
     * @param _teamNames The names of the teams in the competition
     * @param _bannerURI The URI for the competition banner
     * @param _totalPointsPerRound The total points available for each round of the competition. Recommended 2 decimal precision (e.g. 3200 for 32.00 points per round)
     */
    function createPredictableCompetition(
        bytes32 _competitionId,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI,
        uint16 _totalPointsPerRound
    ) external returns (address addr_);
    /**
     * @notice Creates a new competition that allows users to submit bracket predictions for a fee
     * @dev Assumes that the impl type requires `_numTeams` and feeInfo as constructor args. Can set fee to 0 to have a free bracket,
     *  or use createCompetition with impl type PREDICTABLE to have free bracket prediction submissions
     * @param _competitionId The unique id of the competition
     * @param _competitionName The name of the competition
     * @param _numTeams The total number of teams in the competition
     * @param _startingEpoch The epoch at which the competition starts
     * @param _expirationEpoch The epoch at which the competition expires
     * @param _teamNames The names of the teams in the competition
     * @param _bannerURI The URI for the competition's banner image
     * @param _totalPointsPerRound The total points available for each round of the competition. Recommended 2 decimal precision (e.g. 3200 for 32.00 points per round)
     * @param _feeInfo The registration fee information for the competition
     */
    function createPaidPredictableCompetition(
        bytes32 _competitionId,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI,
        uint16 _totalPointsPerRound,
        RegistrationFeeInfo calldata _feeInfo
    ) external returns (address addr_);
    /**
     * @dev Sets the protocol fee that is charged for running a competition
     * @param _feeBps The protocol fee in bps
     */
    function setProtocolFee(uint256 _feeBps) external;
    /**
     * @dev Sets the bytecode for a competition implementation type to use when creating competitions.
     *  Only callable by the owner, and is stored via SSTORE2 in a contract
     * @param _impl The implementation type of the competition
     * @param _code The bytecode of the competition contract
     */
    function setContractCode(CompetitionImpl _impl, bytes memory _code) external;
    /**
     * @dev Returns the info of the competition contract or a default struct if it doesn't exist
     * @param _competitionId The unique id of the competition
     */
    function getCompetitionInfo(bytes32 _competitionId) external view returns (CompetitionInfo memory info_);
    /**
     * @dev Returns the address of the competition contract or address(0) if it doesn't exist
     * @param _competitionId The unique id of the competition
     */
    function getCompetitionAddress(bytes32 _competitionId) external view returns (address addr_);
    /**
     * @dev Returns the implementation type of the competition contract or UNKNOWN if it doesn't exist
     * @param _competitionId The unique id of the competition
     */
    function getCompetitionImplType(bytes32 _competitionId) external view returns (CompetitionImpl impl_);
}
