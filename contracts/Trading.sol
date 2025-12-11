// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Delivery vs Payment
 * @notice Intercambio de activos entre inversores
 */
contract Trading is Ownable, Pausable, ReentrancyGuard {

    error ErrorAssetAlreadyDemanded(uint256 id);
    error ErrorAmountMustBePositive(uint56 amount);
    error ErrorNotEnoughBalance(uint128 value);
    error ErrorOverflow(uint);

    struct Asset {
        uint56 amount;
        uint128 price;
        bool approve;
    }

    IERC20 private immutable digitalCurrency;
    IERC1155 private immutable digitalAssets;

    mapping (uint256 => mapping(address => Asset)) offers;
    mapping (uint256 => mapping(address => Asset)) demands;

    event AssetRequested(uint256 id, uint56 amount, uint128 price);

    constructor(address _digitalCurrency, address _digitalAssets) Ownable(msg.sender) {
        digitalCurrency = IERC20(_digitalCurrency);
        digitalAssets = IERC1155(_digitalAssets);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // En caso de no conocer comprador --
    // Hace visible ofertas para que la otra parte pueda interactuar (ejecutar compra).
    // Deposita el activo en el contrato como garantía
    // No se permite ofrecer si el contrato está pausado
    function supply(uint256 id, uint56 amount, uint128 price) external whenNotPaused {}
    function cancelSupply() external {}

    // En caso de no conocer vendedor --
    // Hace visible solicitudes para que la otra parte pueda interactuar (ejecutar venta).
    // Deposita la cantidad de tokens currency en el contrato como garantía
    // Si el activo ya se habia solicitado, se rechaza -> Debe cancelar la solicitud e iniciar una nueva
    function request(uint256 id, uint56 amount, uint128 price) external {
        if (amount <= 0) revert ErrorAmountMustBePositive(amount);
        uint128 value = amount * price; // Cuidado con overflow (limitar cantidad y/o precio??)
        uint128 max = type(uint128).max;
        if (value > max) revert ErrorOverflow(max);

        if (digitalCurrency.balanceOf(msg.sender) < value) revert ErrorNotEnoughBalance(value);

        Asset storage asset = demands[id][msg.sender];
        if (asset.amount > 0) revert ErrorAssetAlreadyDemanded(id); 

        asset.amount = amount;
        asset.price = price;

        // ** Solicitante necesita aprobar traspaso de tokens al contrato
        digitalCurrency.transferFrom(msg.sender, address(this), value);

        emit AssetRequested(id, amount, price);
    }

    function cancelRequest(uint256 id) external whenNotPaused {

    }

    function buyAsset(address to, uint256 id, uint56 amount) external whenNotPaused {}

    function sellAsset(address buyer, uint256 id) external whenNotPaused {}
}