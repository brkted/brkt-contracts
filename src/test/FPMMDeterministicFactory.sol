pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import {CTHelpers} from "./CTHelpers.sol";
import {Create2CloneFactory} from "./Create2CloneFactory.sol";
import {FixedProductMarketMaker, FixedProductMarketMakerData} from "./FixedProductMarketMaker.sol";
import {ERC1155TokenReceiver, IERC1155TokenReceiver} from "./ERC1155/ERC1155TokenReceiver.sol";

import "forge-std/console.sol";

contract FPMMDeterministicFactory is Create2CloneFactory, FixedProductMarketMakerData, ERC1155TokenReceiver {
    event FixedProductMarketMakerCreation(
        address indexed creator,
        FixedProductMarketMaker fixedProductMarketMaker,
        ConditionalTokens conditionalTokens,
        IERC20 collateralToken,
        bytes32[] conditionIds,
        uint256 fee
    );

    FixedProductMarketMaker public implementationMaster;
    address internal currentFunder;

    constructor() {
        implementationMaster = new FixedProductMarketMaker();
    }

    function cloneConstructor(bytes calldata consData) external override {
        (ConditionalTokens _conditionalTokens, IERC20 _collateralToken, bytes32[] memory _conditionIds, uint256 _fee) =
            abi.decode(consData, (ConditionalTokens, IERC20, bytes32[], uint256));

        _supportedInterfaces[_INTERFACE_ID_ERC165] = true;
        _supportedInterfaces[IERC1155TokenReceiver.onERC1155Received.selector
            ^ IERC1155TokenReceiver.onERC1155BatchReceived.selector] = true;

        conditionalTokens = _conditionalTokens;
        collateralToken = _collateralToken;
        conditionIds = _conditionIds;
        fee = _fee;

        uint256 atomicOutcomeSlotCount = 1;
        outcomeSlotCounts = new uint256[](conditionIds.length);
        for (uint256 i = 0; i < conditionIds.length; i++) {
            uint256 outcomeSlotCount = conditionalTokens.getOutcomeSlotCount(conditionIds[i]);
            atomicOutcomeSlotCount *= outcomeSlotCount;
            outcomeSlotCounts[i] = outcomeSlotCount;
        }
        require(atomicOutcomeSlotCount > 1, "conditions must be valid");

        collectionIds = new bytes32[][](conditionIds.length);
        _recordCollectionIDsForAllConditions(conditionIds.length, bytes32(0));
        require(positionIds.length == atomicOutcomeSlotCount, "position IDs construction failed!?");
    }

    function _recordCollectionIDsForAllConditions(uint256 conditionsLeft, bytes32 parentCollectionId) private {
        if (conditionsLeft == 0) {
            positionIds.push(CTHelpers.getPositionId(collateralToken, parentCollectionId));
            return;
        }

        conditionsLeft--;

        uint256 outcomeSlotCount = outcomeSlotCounts[conditionsLeft];

        collectionIds[conditionsLeft].push(parentCollectionId);
        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            _recordCollectionIDsForAllConditions(
                conditionsLeft, CTHelpers.getCollectionId(parentCollectionId, conditionIds[conditionsLeft], 1 << i)
            );
        }
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        ConditionalTokens(msg.sender).safeTransferFrom(address(this), currentFunder, id, value, data);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        console.log("");
        console.log("currentFunder", currentFunder);
        console.log("id: %s, value: %s", ids[0], values[0]);
        console.log("id: %s, value: %s", ids[1], values[1]);
        console.log("");
        ConditionalTokens(msg.sender).safeBatchTransferFrom(address(this), currentFunder, ids, values, data);
        return this.onERC1155BatchReceived.selector;
    }

    function create2FixedProductMarketMaker(
        uint256 saltNonce,
        ConditionalTokens conditionalTokens,
        IERC20 collateralToken,
        bytes32[] calldata conditionIds,
        uint256 fee,
        uint256 initialFunds,
        uint256[] calldata distributionHint
    ) external returns (FixedProductMarketMaker) {
        FixedProductMarketMaker fixedProductMarketMaker = FixedProductMarketMaker(
            create2Clone(
                address(implementationMaster),
                saltNonce,
                abi.encode(conditionalTokens, collateralToken, conditionIds, fee)
            )
        );
        emit FixedProductMarketMakerCreation(
            msg.sender, fixedProductMarketMaker, conditionalTokens, collateralToken, conditionIds, fee
        );

        if (initialFunds > 0) {
            currentFunder = msg.sender;
            collateralToken.transferFrom(msg.sender, address(this), initialFunds);
            collateralToken.approve(address(fixedProductMarketMaker), initialFunds);
            console.log("sending initial funds!");
            fixedProductMarketMaker.addFunding(initialFunds, distributionHint);
            console.log("initial funds sent!");
            fixedProductMarketMaker.transfer(msg.sender, fixedProductMarketMaker.balanceOf(address(this)));
            currentFunder = address(0);
        }

        return fixedProductMarketMaker;
    }
}
