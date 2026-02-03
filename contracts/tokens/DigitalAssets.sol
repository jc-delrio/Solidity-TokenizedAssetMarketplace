// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract DigitalAssets is ERC1155, Ownable, Pausable {
    constructor() ERC1155("") Ownable(msg.sender) {
        string memory _baseURI = "https://gateway.pinata.cloud/ipfs/HASH/";
        _setURI(string.concat(_baseURI, "{id}.json"));
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(
        address to,
        uint256 id,
        uint56 value,
        bytes memory data
    ) external onlyOwner whenNotPaused {
        _mint(to, id, value, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) external onlyOwner whenNotPaused {
        _mintBatch(to, ids, values, data);
    }

    function burn(uint256 id, uint56 value) external whenNotPaused {
        _burn(msg.sender, id, value);
    }

    function setURI(string memory newURI) external onlyOwner {
        _setURI(string.concat(newURI, "{id}.json"));
    }
}
