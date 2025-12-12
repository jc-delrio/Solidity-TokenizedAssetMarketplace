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
    error ErrorNotEnoughBalance(uint request);
    error ErrorOverflow(uint max);
    error ErrorAssetNotRequested(uint256 id);
    error ErrorAmountExceded(uint56 request);

    struct Asset { // Ajustado a 1 Slot
        uint56 amount;
        uint128 price;
        bool approved;
    }

    IERC20 private immutable digitalCurrency;
    IERC1155 private immutable digitalAssets;

    mapping (uint256 => mapping(address => Asset)) offers; // Listado de ofertas de activos
    mapping (uint256 => mapping(address => Asset)) demands; // Listado de solicitudes de activos
    mapping (address => uint128) withdrawableBalances; // Saldo disponible para retirar por cada inversor (en caso de cancelación de oferta o solicitud)

    event AssetRequested(address indexed buyer, uint256 indexed id, uint56 amount, uint128 price);

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
    function supply(uint256 id, uint56 amount, uint128 price) external whenNotPaused nonReentrant {}
    function cancelSupply() external {}

    // En caso de no conocer vendedor --
    // Hace visible solicitudes para que la otra parte pueda interactuar (ejecutar venta).
    // Deposita la cantidad de tokens currency en el contrato como garantía
    // Si el activo ya se habia solicitado, se rechaza -> Debe cancelar la solicitud e iniciar una nueva
    function request(uint256 id, uint56 amount, uint128 price) external whenNotPaused nonReentrant {
        if (amount <= 0) revert ErrorAmountMustBePositive(amount);
        uint128 value = amount * price; // revisar overflow (limitar cantidad y/o precio??)
        uint128 max = type(uint128).max;
        if (value > max) revert ErrorOverflow(max);

        Asset storage asset = demands[id][msg.sender];
        if (asset.amount > 0) revert ErrorAssetAlreadyDemanded(id); 

        if (digitalCurrency.balanceOf(msg.sender) < value) revert ErrorNotEnoughBalance(value);

        asset.amount = amount;
        asset.price = price;

        // ** Solicitante necesita aprobar traspaso de tokens al contrato
        digitalCurrency.transferFrom(msg.sender, address(this), value);

        emit AssetRequested(msg.sender, id, amount, price);
    }

    function cancelRequest(uint256 id) external nonReentrant {
        Asset storage asset = demands[id][msg.sender];
        if (asset.amount == 0) revert ErrorAssetNotRequested(id);

        asset.amount = 0;
        asset.price = 0;
        asset.approved = false;

        uint128 value = asset.amount * asset.price;
        withdrawableBalances[msg.sender] += value;
    }

    // Permite al fondo supervisar y validar los datos de la oferta o solicitud (precio y más) para habilitar compra o venta
    function approveAsset(address investor, uint256 id) external onlyOwner {
        Asset storage asset = demands[id][investor];
        if (asset.amount <= 0) revert ErrorAssetNotRequested(id);

        asset.approved = true;
    }

    function buyAsset(address to, uint256 id, uint56 amount) external whenNotPaused nonReentrant {}

    function sellAsset(address buyer, uint256 id, uint56 amount) external whenNotPaused nonReentrant {
        Asset storage asset = demands[id][buyer];
        if (amount > asset.amount) revert ErrorAmountExceded(asset.amount);
        if (!asset.approved || asset.amount <= 0) revert ErrorAssetNotRequested(id);

        uint256 sellerBalance = digitalAssets.balanceOf(msg.sender, id);
        if (sellerBalance < amount) revert ErrorNotEnoughBalance(amount);

        asset.amount -= amount;
        uint128 value = amount * asset.price;

        if (asset.amount == 0) {
            asset.price = 0;
            asset.approved = false;
        }

        // ** Vendedor necesita aprobar traspaso de activos al contrato
        digitalAssets.safeTransferFrom(msg.sender, buyer, id, amount, "");
        
        digitalCurrency.transferFrom(address(this), msg.sender, value);
    }

    function withdraw() external whenNotPaused nonReentrant{
        uint128 amount = withdrawableBalances[msg.sender];
        if (amount == 0) revert ErrorNotEnoughBalance(0);

        withdrawableBalances[msg.sender] = 0;

        digitalCurrency.transferFrom(address(this), msg.sender, amount);
    }
}