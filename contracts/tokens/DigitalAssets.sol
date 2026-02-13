// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {
    ERC1155Supply
} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract DigitalAssets is ERC1155, ERC1155Supply, Ownable, Pausable {
    error ErrorNotEnoughBalance();

    event AssetMinted(address indexed to, uint256 indexed id, uint256 value);
    event AssetMintedBatch(
        address indexed to,
        uint256[] indexed ids,
        uint256[] values
    );
    event AssetBurned(address indexed from, uint256 indexed id, uint256 value);
    event ContractPaused(address indexed owner);
    event ContractUnpaused(address indexed owner);

    mapping(uint256 => uint256) public maxSupply;

    constructor() ERC1155("") Ownable(msg.sender) {
        string
            memory _baseURI = "ipfs://bafybeifmpqp3tff7y3zq42viecii63hj5vk7divzlanfakovmp6ebw2na4/";
        _setURI(string.concat(_baseURI, "{id}.json"));
    }

    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    function mint(
        address to,
        uint256 id,
        uint56 value,
        bytes memory data
    ) external onlyOwner whenNotPaused {
        maxSupply[id] += value;
        _mint(to, id, value, data);
        emit AssetMinted(to, id, value);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) external onlyOwner whenNotPaused {
        for (uint256 i = 0; i < ids.length; i++) {
            maxSupply[ids[i]] += values[i];
        }
        _mintBatch(to, ids, values, data);
        emit AssetMintedBatch(to, ids, values);
    }

    function burn(uint256 id, uint56 value) external whenNotPaused {
        if (balanceOf(msg.sender, id) < value) revert ErrorNotEnoughBalance();
        maxSupply[id] -= value;
        _burn(msg.sender, id, value);
        emit AssetBurned(msg.sender, id, value);
    }

    function setURI(string memory newURI) external onlyOwner {
        _setURI(string.concat(newURI, "{id}.json"));
        emit URI(newURI, 0);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }
}
