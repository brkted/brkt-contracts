// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CompetitionState} from "src/competition/base/CompetitionState.sol";
import {ICompetition} from "src/interfaces/ICompetition.sol";
import {ICompetitionRouter} from "src/interfaces/ICompetitionRouter.sol";
import {IPaidPredictableCompetition, RegistrationFeeInfo} from "src/interfaces/IPaidPredictableCompetition.sol";
import {IPredictableCompetition} from "src/interfaces/IPredictableCompetition.sol";
import {ICompetitionFactory, CompetitionImpl} from "src/interfaces/ICompetitionFactory.sol";

/// @title Competition Routing
/// @author BRKT
/// @notice Contract used to route through to specific competition contracts
///  Ensures that events stem from a singular contract for indexing
contract CompetitionRouter is ICompetitionRouter, Ownable {
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //       -'~'-.,__,.-'~'-.,__,.- VARS -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    ICompetitionFactory public _factory;

    constructor(address _owner, address _factoryAddress) {
        transferOwnership(_owner);
        _factory = ICompetitionFactory(_factoryAddress);
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- EXTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    /**
     * @inheritdoc ICompetitionRouter
     */
    function createBracketPrediction(bytes32 _competitionId, uint8[] calldata _matchPredictions) public payable {
        CompetitionImpl impl = _factory.getCompetitionImplType(_competitionId);
        if (impl == CompetitionImpl.PAID_PREDICTABLE) {
            IPaidPredictableCompetition comp =
                IPaidPredictableCompetition(_factory.getCompetitionAddress(_competitionId));
            RegistrationFeeInfo memory info = comp.getBracketPredictionFeeInfo();
            if (info.isNetworkToken) {
                // Assume the competition handles network token payment validation
                comp.createBracketPredictionGasToken{value: msg.value}(msg.sender, _matchPredictions);
            } else {
                if (info.fee > 0 && !comp.hasUserRegistered(msg.sender)) {
                    IERC20(info.paymentToken).transferFrom(msg.sender, address(comp), info.fee);
                }
                comp.createBracketPrediction(msg.sender, _matchPredictions);
            }
        } else if (impl == CompetitionImpl.PREDICTABLE) {
            IPredictableCompetition comp = IPredictableCompetition(_factory.getCompetitionAddress(_competitionId));
            comp.createBracketPrediction(msg.sender, _matchPredictions);
        } else {
            revert("CompetitionRouter: Unsupported competition type");
        }
    }

    /**
     * @inheritdoc ICompetitionRouter
     */
    function setFactory(address _factoryAddr) public onlyOwner {
        _factory = ICompetitionFactory(_factoryAddr);
    }

    function getTeamNames(bytes32 _competitionId) external view override returns (string[] memory teamNames_) {
        teamNames_ = ICompetition(_factory.getCompetitionAddress(_competitionId)).getTeamNames();
    }

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //     -'~'-.,__,.-'~'-.,__,.- INTERNAL -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>

    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
    //    -'~'-.,__,.-'~'-.,__,.- MODIFIERS -.,__,.-'~'-.,__,.-'~'-
    // <<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>><<>>
}
