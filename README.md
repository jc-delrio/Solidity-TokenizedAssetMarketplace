# 🛒 Decentralized Marketplace (ERC1155 & ERC20)

![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.28-363636?style=flat-square&logo=solidity)
![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-Contracts-blue?style=flat-square)

## 📄 Project Description

This project implements a robust and optimized **on-chain Marketplace**. The contract acts as a trusted intermediary allowing the trading (buying and selling) of digital assets (**ERC1155** standard) using a specific digital currency (**ERC20** standard).

The design focuses on **Gas Optimization**, security against common attack vectors (such as Reentrancy), and clean state management through strict access control.

### 1. Storage Optimization (Struct Packing)
The main data structure has been designed to occupy exactly **1 Storage Slot (256 bits)**. This drastically reduces gas costs when reading or writing asset information, as the EVM operates in 32-byte words.

```solidity
struct Asset {
    uint128 value;      // 16 bytes
    uint56 listed;      // 7 bytes
    uint56 available;   // 7 bytes
    bool marketable;    // 1 byte
} 
// Total: 31 bytes (248 bits) < 32 bytes (1 Slot)
```

### 2. Error Efficiency (Custom Errors)
Instead of using `require` with string messages (which increase bytecode size and deployment costs), **Custom Errors** defined at the beginning of the contract are used.

✅ revert ErrorInsufficientBalance(required, actual)    
❌ require(balance >= amount, "Insufficient Balance")

### 3. Arithmetic Gas Savings
`unchecked` blocks are implemented in operations where overflow/underflow is logically impossible due to prior validations (`if`), saving the gas cost of the automatic checks present in Solidity 0.8+.

### 4. Security
- **Pausable**: Allow pause/unpause critical functions if bugs are detected.
- **ReentrancyGuard**: Implemented in critical value transfer functions (`buyAsset`, `sellAsset`).
- **Patrón Checks-Effects-Interactions**: Internal contract state is updated before calling external contracts to prevent reentrancy attacks.
- **Control de Acceso**: Strict use of `Ownable` for administrative inventory management functions.

## 📚 Main Functions

🛠 For the Fund (Owner)  
- **listNewAsset**: Registers a new asset in the catalog (ID, Price, Stock).
- **restockAsset**: Increases the inventory of an existing asset. 
- **delistAsset**: Removes inventory from the market (unsold stock only).   
- **updateAsset**: Updates the price or the marketable status of an asset.   
 
👤 For the Investor  
- **buyAsset**: Buys assets. Requires: Prior approve of the ERC20 token.  
- **sellAsset**: Sells assets back to the fund. Requires: Asset marked as marketable and setApprovalForAll of the ERC1155.  

## 🚀 Installation & Deployment
This contract is compatible with frameworks like Hardhat.

*Prerequisites*      
- Solidity ^0.8.28
- OpenZeppelin Contracts

*Deployment*   
The constructor requires the addresses of the already deployed token contracts:

```solidity
constructor(
    address _digitalCurrency, // Dirección del contrato ERC20
    address _digitalAssets    // Dirección del contrato ERC1155
)
```

### License
This project is licensed under the MIT License.
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)