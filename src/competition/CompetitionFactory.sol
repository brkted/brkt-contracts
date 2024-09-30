// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SSTORE2} from "@0xsequence/sstore2/contracts/SSTORE2.sol";
import {Create3} from "@0xsequence/create3/contracts/Create3.sol";

import {ICompetition} from "src/interfaces/ICompetition.sol";
import {IPredictableCompetition} from "src/interfaces/IPredictableCompetition.sol";
import {IPaidPredictableCompetition, RegistrationFeeInfo} from "src/interfaces/IPaidPredictableCompetition.sol";
import {ICompetitionFactory, CompetitionImpl, CompetitionInfo} from "src/interfaces/ICompetitionFactory.sol";

/// @title Competition Factory
/// @author BRKT
/// @notice Contract used to create and retrieve competition contracts and info
contract CompetitionFactory is ICompetitionFactory, Ownable {
    error CompetitionAlreadyExists(bytes32 _competitionId);
    error InvalidCompetitionImpl(CompetitionImpl _competitionImpl);
    error NoCreationCodeForImpl(CompetitionImpl _competitionImpl);

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //       -'~'-.,__,.-'~'-.,__,.- VARS -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    /**
     * @dev Input bytes32: The competition ID
     *      Output CompetitionInfo: The competition details (address and type, etc.)
     */
    mapping(bytes32 => CompetitionInfo) internal _competitions;

    mapping(CompetitionImpl => address) internal _contractCodes;

    /**
     * @dev The fee associated to running a competition, in bps
     */
    uint256 public override protocolFee;

    constructor(address _owner) {
        transferOwnership(_owner);
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- EXTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    /**
     * @inheritdoc ICompetitionFactory
     */
    function createCompetition(
        bytes32 _competitionId,
        string calldata _competitionName,
        uint16 _numTeams,
        uint64 _startingEpoch,
        uint64 _expirationEpoch,
        string[] memory _teamNames,
        string memory _bannerURI
    ) public override returns (address addr_) {
        CompetitionInfo storage info = _initializeCompetition(_competitionId);
        info.impl = CompetitionImpl.BASE;
        info.addr = Create3.create3(
            _competitionId,
            abi.encodePacked(abi.encodePacked(_getCreationCode(CompetitionImpl.BASE), abi.encode(address(this))))
        );
        ICompetition(info.addr).initialize(
            msg.sender, _competitionName, _numTeams, _startingEpoch, _expirationEpoch, _teamNames, _bannerURI
        );
        addr_ = info.addr;

        emit CompetitionCreated(msg.sender, _competitionId, addr_, info.impl);
    }

    /**
     * @inheritdoc ICompetitionFactory
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
    ) public override returns (address addr_) {
        CompetitionInfo storage info = _initializeCompetition(_competitionId);
        info.impl = CompetitionImpl.BASE;
        info.addr = Create3.create3(
            _competitionId,
            abi.encodePacked(abi.encodePacked(_getCreationCode(CompetitionImpl.PREDICTABLE), abi.encode(address(this))))
        );
        IPredictableCompetition(info.addr).initialize(
            msg.sender,
            _competitionName,
            _numTeams,
            _startingEpoch,
            _expirationEpoch,
            _teamNames,
            _bannerURI,
            _totalPointsPerRound
        );
        addr_ = info.addr;

        emit CompetitionCreated(msg.sender, _competitionId, addr_, info.impl);
    }

    /**
     * @inheritdoc ICompetitionFactory
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
    ) public override returns (address addr_) {
        CompetitionInfo storage info = _initializeCompetition(_competitionId);
        info.impl = CompetitionImpl.PAID_PREDICTABLE;
        info.addr = Create3.create3(
            _competitionId,
            abi.encodePacked(_getCreationCode(CompetitionImpl.PAID_PREDICTABLE), abi.encode(address(this)))
        );
        IPaidPredictableCompetition(info.addr).initialize(
            msg.sender,
            _competitionName,
            _numTeams,
            _startingEpoch,
            _expirationEpoch,
            _teamNames,
            _bannerURI,
            _totalPointsPerRound,
            _feeInfo
        );
        addr_ = info.addr;

        emit CompetitionCreated(msg.sender, _competitionId, addr_, info.impl);
    }

    /**
     * @inheritdoc ICompetitionFactory
     */
    function setProtocolFee(uint256 _feeBps) public onlyOwner {
        protocolFee = _feeBps;
    }

    /**
     * @inheritdoc ICompetitionFactory
     */
    function setContractCode(CompetitionImpl _impl, bytes memory _code) public onlyOwner {
        _contractCodes[_impl] = SSTORE2.write(_code);
    }

    /**
     * @inheritdoc ICompetitionFactory
     */
    function getCompetitionInfo(bytes32 _competitionId) external view returns (CompetitionInfo memory info_) {
        info_ = _competitions[_competitionId];
    }

    /**
     * @inheritdoc ICompetitionFactory
     */
    function getCompetitionAddress(bytes32 _competitionId) external view returns (address addr_) {
        addr_ = _competitions[_competitionId].addr;
    }

    /**
     * @inheritdoc ICompetitionFactory
     */
    function getCompetitionImplType(bytes32 _competitionId) external view returns (CompetitionImpl impl_) {
        impl_ = _competitions[_competitionId].impl;
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- INTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    function _initializeCompetition(bytes32 _competitionId) internal view returns (CompetitionInfo storage info_) {
        info_ = _competitions[_competitionId];
        if (info_.addr != address(0)) {
            revert CompetitionAlreadyExists(_competitionId);
        }
    }

    function _getCreationCode(CompetitionImpl _competitionImpl) internal view returns (bytes memory code_) {
        if (_contractCodes[_competitionImpl] == address(0)) {
            revert NoCreationCodeForImpl(_competitionImpl);
        }
        code_ = SSTORE2.read(_contractCodes[_competitionImpl]);
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //    -'~'-.,__,.-'~'-.,__,.- MODIFIERS -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
}
