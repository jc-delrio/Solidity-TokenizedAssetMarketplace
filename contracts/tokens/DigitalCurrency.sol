// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract DigitalCurrency is ERC20, Ownable, Pausable {

    constructor() ERC20("digitalCurrency", "CBDC") Ownable(msg.sender){}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint128 value) external onlyOwner whenNotPaused {
        _mint(to, value);
    }

    function burn(address to, uint128 value) external onlyOwner whenNotPaused {
        _burn(to, value);
    }
}