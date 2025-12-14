// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol"; // Para que el contrato pueda recibir tokens ERC1155
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Delivery vs Payment
 * @notice Intercambio de activos entre inversores
 */
contract Trading is Ownable, Pausable, ERC1155Holder, ReentrancyGuard {

    error ErrorAssetAlreadyExist(uint256 id);
    error ErrorAmountMustBePositive(uint56 amount);
    error ErrorNotEnoughBalance(uint request);
    error ErrorOverflow(uint max);
    error ErrorAssetNotExist(uint256 id);
    error ErrorAmountExceded(uint56 request);
    error ErrorValueMustBePositive(uint128 value);

    struct Asset { // Ocupa 1 Slot
        //address investor; // Dirección del inversor que realizó la oferta o solicitud
        uint56 amount; // Cantidad de tokens
        uint128 price;  // Precio por token en currency
        bool approved; // Aprobado por el fondo
    }

    IERC20 private immutable digitalCurrency;
    IERC1155 private immutable digitalAssets;

    mapping (uint256 => mapping(address => Asset)) public offers; // Listado de ofertas de activos
    mapping (uint256 => mapping(address => Asset)) public demands; // Listado de solicitudes de activos
    mapping (address => uint128) public withdrawableBalances; // Saldo disponible para retirar por cada inversor (en caso de cancelación de oferta o solicitud)
    mapping (address => mapping(uint256 => uint56)) public withdrawableAssets; // Activos disponibles para retirar por cada inversor Ids -> Cantidad (en caso de cancelación de oferta)

    event AssetRequested(address indexed buyer, uint256 indexed id, uint56 amount, uint128 price);
    event AssetSupplied(address indexed seller, uint256 indexed id, uint56 amount, uint128 price);
    event AssetSold(address indexed seller,  address indexed buyer, uint256 indexed id, uint56 amount, uint128 price);
    event AssetBought(address indexed buyer, address indexed seller, uint256 indexed id, uint56 amount, uint128 price);
    event RequestCancelled(address indexed buyer, uint256 indexed id);
    event SupplyCancelled(address indexed seller, uint256 indexed id);
    event CurrencyWithdrawn(address indexed investor, uint128 amount);
    event AssetsWithdrawn(address indexed investor, uint256 indexed id, uint56 amount);
    event FundApproved(address indexed investor, uint256 indexed id);

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

    // *** Demanda de activos ***

    /**
    @notice Solicita un activo para su compra
    @param id (uint256) Identificador del activo
    @param amount (uint56) Cantidad solicitada
    @param price (uint128) Valor unitario del activo
        @dev La cantidad solicitada debe ser positiva
        @dev El inversor debe tener el balance suficiente para la solicitud
        @dev Deposita el precio del pedido (modenda digital) en el contrato como garantía
        @dev Un inversor no puede tener mas de una solicitud de un mismo activo. Si quiere modificarla, debe cancelarla e iniciar una nueva
    */
    function request(uint256 id, uint56 amount, uint128 price) external whenNotPaused nonReentrant {
        if (amount <= 0) revert ErrorAmountMustBePositive(amount);
        uint128 value = amount * price;
        uint128 max = type(uint128).max;
        if (value > max) revert ErrorOverflow(max);

        Asset storage asset = demands[id][msg.sender];
        if (asset.amount > 0) revert ErrorAssetAlreadyExist(id); 

        if (digitalCurrency.balanceOf(msg.sender) < value) revert ErrorNotEnoughBalance(value);

        //asset.investor = msg.sender;
        asset.amount = amount;
        asset.price = price;

        // ** Solicitante necesita aprobar traspaso de tokens al contrato
        digitalCurrency.transferFrom(msg.sender, address(this), value);

        emit AssetRequested(msg.sender, id, amount, price);
    }

    /**
    @notice Aprueba una solicitud de activo realizada por un inversor
    @param investor (address) Dirección del inversor que realizó la solicitud
    @param id (uint256) Identificador del activo
        @dev La solicitud debe existir. Se comprueba que la cantidad solicitada sea positiva
        @dev Los criterios de aprobación son definidos por el fondo externamente
    */
    function approveDemand(address investor, uint256 id) external onlyOwner {
        Asset storage asset = demands[id][investor];
        if (asset.amount <= 0) revert ErrorAssetNotExist(id);

        asset.approved = true;

        emit FundApproved(investor, id);
    }


    /**
    @notice Vende un activo a un inversor que realizó una solicitud aprobada
    @param buyer (address) Dirección del inversor que realizó la solicitud
    @param id (uint256) Identificador del activo
    @param amount (uint56) Cantidad solicitada
        @dev La cantidad a vender debe ser positiva
        @dev La solicitud debe existir y estar aprobada por el fondo
        @dev La cantidad a vender no puede exceder la cantidad solicitada
        @dev El inversor debe tener el balance suficiente para la solicitud
    */
    function sellAsset(address buyer, uint256 id, uint56 amount) external whenNotPaused nonReentrant {
        if (amount <= 0) revert ErrorAmountMustBePositive(amount);

        Asset storage asset = demands[id][buyer];
        if (amount > asset.amount) revert ErrorAmountExceded(asset.amount);
        if (!asset.approved || asset.amount <= 0) revert ErrorAssetNotExist(id);

        uint256 sellerBalance = digitalAssets.balanceOf(msg.sender, id);
        if (sellerBalance < amount) revert ErrorNotEnoughBalance(amount);

        uint128 price = asset.price;
        asset.amount -= amount;
        uint128 value = amount * price;

        if (asset.amount == 0) {
            asset.price = 0;
            asset.approved = false;
        }

        // ** Vendedor necesita aprobar traspaso de activos al contrato
        digitalAssets.safeTransferFrom(msg.sender, buyer, id, amount, "");
        
        digitalCurrency.transfer(msg.sender, value);

        emit AssetSold(msg.sender, buyer, id, amount, price);
    }

    /**
    @notice Cancela una solicitud de activo realizada por el inversor
    @param id (uint256) Identificador del activo
        @dev La solicitud debe existir y debe ser del inversor que llama a la función
        @dev El saldo correspondiente a la solicitud se añade al balance disponible para retirar del inversor
    */
    function cancelRequest(uint256 id) external nonReentrant {
        Asset storage asset = demands[id][msg.sender];
        if (asset.amount == 0) revert ErrorAssetNotExist(id);

        withdrawableBalances[msg.sender] += asset.amount * asset.price;
        asset.amount = 0;
        asset.price = 0;   
        asset.approved = false;

        emit RequestCancelled(msg.sender, id);
    }

    /**
    @notice Retira el balance disponible del inversor (en caso de cancelación de solicitud)
        @dev El balance disponible debe ser positivo
        @dev El balance disponible se transfiere del contrato al inversor
    */
    function withdrawBalance() external whenNotPaused nonReentrant{
        uint128 withdrawable = withdrawableBalances[msg.sender];
        if (withdrawable < 0) revert ErrorNotEnoughBalance(withdrawable);

        delete withdrawableBalances[msg.sender];

        // Devolver balance al inversor
        digitalCurrency.transfer(msg.sender, withdrawable);

        emit CurrencyWithdrawn(msg.sender, withdrawable);
    }


    // *** Ofertas de activos ***

    // En caso de no conocer comprador --
    // Hace visible ofertas para que la otra parte pueda interactuar (ejecutar compra).
    // Deposita el activo en el contrato como garantía
    // No se permite ofrecer si el contrato está pausado

    /**
    @notice Oferta un activo para su venta
    @param id (uint256) Identificador del activo
    @param amount (uint56) Cantidad solicitada
    @param price (uint128) Valor unitario del activo
        @dev La cantidad ofertada debe ser positiva
        @dev El inversor debe tener los activos suficiente para la oferta
        @dev Deposita los activos ofrecidos en el contrato como garantía
        @dev Un inversor no puede tener mas de una oferta de un mismo activo. Si quiere modificarla, debe cancelarla e iniciar una nueva
    */
    function supply(uint256 id, uint56 amount, uint128 price) external whenNotPaused nonReentrant {
        if (amount <= 0) revert ErrorAmountMustBePositive(amount);
        if (price <= 0) revert ErrorValueMustBePositive(price);

        Asset storage asset = offers[id][msg.sender];
        if (asset.amount > 0) revert ErrorAssetAlreadyExist(id); 

        if (digitalAssets.balanceOf(msg.sender, id) < amount) revert ErrorNotEnoughBalance(amount);

        asset.amount = amount;
        asset.price = price;

        // ** Proveedor necesita aprobar traspaso de activos al contrato
        digitalAssets.safeTransferFrom(msg.sender, address(this), id, amount, "");

        emit AssetSupplied(msg.sender, id, amount, price);
    }

    /**
    @notice Aprueba una oferta de activo realizada por un inversor
    @param investor (address) Dirección del inversor que realizó la oferta
    @param id (uint256) Identificador del activo
        @dev La oferta debe existir. Se comprueba que la cantidad ofertada sea positiva
        @dev Los criterios de aprobación son definidos por el fondo externamente
    */
    function approveOffer(address investor, uint256 id) external onlyOwner {
        Asset storage asset = offers[id][investor];
        if (asset.amount <= 0) revert ErrorAssetNotExist(id);

        asset.approved = true;

        emit FundApproved(investor, id);
    }

    /**
    @notice Compra un activo a un inversor que realizó una oferta aprobada
    @param seller (address) Dirección del inversor que realizó la oferta
    @param id (uint256) Identificador del activo
    @param amount (uint56) Cantidad solicitada
        @dev La cantidad a comprar debe ser positiva
        @dev La cantidad a comprar no puede exceder la cantidad ofertada
        @dev La oferta debe existir y estar aprobada por el fondo
        @dev El inversor debe tener el balance suficiente para la compra
    */
    function buyAsset(address seller, uint256 id, uint56 amount) external whenNotPaused nonReentrant {
        if (amount <= 0) revert ErrorAmountMustBePositive(amount);

        Asset storage asset = offers[id][seller];
        if (amount > asset.amount) revert ErrorAmountExceded(asset.amount);
        if (!asset.approved || asset.amount < 0) revert ErrorAssetNotExist(id);

        uint128 value = amount * asset.price;

        if (digitalCurrency.balanceOf(msg.sender) < value) revert ErrorNotEnoughBalance(value);

        uint128 price = asset.price;
        asset.amount -= amount;
        if (asset.amount == 0) {
            asset.price = 0;
            asset.approved = false;
        }

        // ** Comprador necesita aprobar traspaso de tokens al contrato
        digitalCurrency.transferFrom(msg.sender, seller, value);

        digitalAssets.safeTransferFrom(address(this), msg.sender, id, amount, "");

        emit AssetBought(msg.sender, seller, id, amount, price);
    }


    /**
    @notice Cancela una oferta de activo realizada por el inversor
    @param id (uint256) Identificador del activo
        @dev La oferta debe existir y debe ser del inversor que llama a la función
        @dev Los activos correspondientes a la oferta se añaden al balance disponible para retirar del inversor
    */
    function cancelSupply(uint256 id) external {
        Asset storage asset = offers[id][msg.sender];
        if (asset.amount == 0) revert ErrorAssetNotExist(id);

        withdrawableAssets[msg.sender][id] = asset.amount;
        asset.amount = 0;
        asset.price = 0;
        asset.approved = false;

        emit SupplyCancelled(msg.sender, id);
    }

    /**
    @notice Retira los activos disponibles del inversor (en caso de cancelación de oferta)
        @dev Los activos disponibles deben ser positivos
        @dev Los activos disponibles se transfieren del contrato al inversor
    */
    function withdrawAssets(uint256 id) external whenNotPaused nonReentrant {
        uint56 withdrawable = withdrawableAssets[msg.sender][id];
        if (withdrawable <= 0) revert ErrorNotEnoughBalance(withdrawable);

        delete withdrawableAssets[msg.sender][id];

        // Devolver activos al inversor
        digitalAssets.safeTransferFrom(address(this), msg.sender, id, withdrawable, "");

        emit AssetsWithdrawn(msg.sender, id, withdrawable); 
    }
}