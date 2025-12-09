// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DigitalCurrency is ERC20, Ownable {

    constructor() ERC20("digitalCurrency", "CBDC") Ownable(msg.sender)
    {}

    function mint(address to, uint128 value) external onlyOwner {
        _mint(to, value);
    }

    function burn(address to, uint128 value) external onlyOwner {
        _burn(to, value);
    }
}