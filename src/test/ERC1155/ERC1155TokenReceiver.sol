pragma solidity ^0.8.26;

import "./IERC1155TokenReceiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

abstract contract ERC1155TokenReceiver is ERC165Storage, IERC1155TokenReceiver {
    constructor() {
        _registerInterface(
            IERC1155TokenReceiver.onERC1155Received.selector ^ IERC1155TokenReceiver.onERC1155BatchReceived.selector
        );
    }
}
