// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    ERC20Pausable
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract DigitalCurrency is ERC20, Ownable, ERC20Pausable {
    constructor() ERC20("digitalCurrency", "CBDC") Ownable(msg.sender) {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }

    function mint(address to, uint256 value) external onlyOwner whenNotPaused {
        _mint(to, value);
    }

    function burn(uint256 value) external whenNotPaused {
        _burn(msg.sender, value);
    }
}
