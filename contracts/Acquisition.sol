// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Adquisición de activos
 * @notice Compra inicial de activos ERC1155 al fondo de inversión.
 */
contract Acquisition is Ownable, Pausable, ReentrancyGuard {

    error ErrorAddressNotAllowed();
    error ErrorAssetNotAvailable(uint256 id);
    error ErrorAssetAlreadyListed(uint256 id);
    error ErrorAllAssetsAlreadyListed(uint56 supply);
    error ErrorInsufficientBalance(uint128 value, uint256 balance);
    error ErrorInsufficientAssets(uint56 available, uint56 requested);
    error ErrorAssetNotMarketable(uint256 id);
    error ErrorInvalidInput(uint data);

    IERC20 private immutable digitalCurrency;
    IERC1155 private immutable digitalAssets;

    struct Asset { // Ajustado para usar 1 Slot
        uint128 value; // Valor del activo
        uint56 listed; // Cantidad ofertada
        uint56 available; // Cantidad aun disponible
        bool marketable; // Para determinar si el activo puede negociarse (vender de vuelta al fondo)
    }

    mapping(uint256 => Asset) public assetList;

    event AssetListed(uint256 indexed id, uint56 supply, uint128 value);
    event AssetDelisted(uint256 indexed id, uint56 supply, uint128 value);
    event AssetRestocked(uint256 indexed id, uint56 listed);
    event AssetUpdated(uint256 indexed id, uint128 value, bool marketable);
    event AssetBought(address indexed buyer, uint256 indexed id, uint56 amount, uint128 value);
    event AssetSold(address indexed seller, uint256 indexed id, uint56 amount, uint128 value);

    constructor(address _digitalCurrency, address _digitalAssets) Ownable(msg.sender) {
        digitalCurrency = IERC20(_digitalCurrency);
        digitalAssets = IERC1155(_digitalAssets);
    }

    // Modificador para comprobar entrada de datos positiva (Uso repetido en varias funciones)
    modifier inputIsPositive(uint data) {
        if (data <= 0) revert ErrorInvalidInput(data);
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
    @notice Suministra activos a la plataforma para su negociación
    @param id (uint256) Identificador del activo
    @param supply (uint56) Cantidad a suministrar
    @param value (uint128) Valor unitario del activo
    @param marketable (bool) Si el activo es negociable o no
        @dev Solo el Fondo de Inversión puede suministrar activos
        @dev La cantidad a suministrar y el valor del activo deben ser positivos
        @dev El activo NO debe estar suministrado previamente
        @dev El fondo debe poseer la cantidad que desea suministrar
    */
    function listNewAsset(uint256 id, uint56 supply, uint128 value, bool marketable) external onlyOwner inputIsPositive(supply) inputIsPositive(value) {
        Asset storage asset = assetList[id];
        // El activo no debe estar suministrado
        if (asset.listed > 0) revert ErrorAssetAlreadyListed(id);

        uint56 balance = uint56(digitalAssets.balanceOf(owner(), id));
        // El fondo debe poseer la cantidad que desea suministrar
        if(supply > balance) revert ErrorInsufficientAssets(balance, supply);

        // Se añade nuevo activo
        assetList[id] = Asset({
            value: value,  
            listed: supply, 
            available: supply, 
            marketable: marketable 
        });
        
        emit AssetListed(id, supply, value);  
    }

    /**
    @notice Aumenta la cantidad de activos ya existentes para su negociación
    @param id (uint256) Identificador del activo
    @param supply (uint56) Cantidad a suministrar
        @dev Solo el Fondo de Inversión puede suministrar activos
        @dev La cantidad a suministrar debe ser positiva
        @dev El activo DEBE estar suministrado previamente
        @dev No debe superar la cantidad máxima de activos disponibles
        @dev El fondo debe poseer la cantidad que desea suministrar
    */
    function restockAsset(uint256 id, uint56 supply) external onlyOwner inputIsPositive(supply) {
        Asset storage asset = assetList[id];
        // El activo debe estar suministrado
        if (asset.listed == 0) revert ErrorAssetNotAvailable(id);

        uint56 balance = uint56(digitalAssets.balanceOf(owner(), id));
        // No hay mas activos disponibles para suministrar
        if (asset.listed == balance) revert ErrorAllAssetsAlreadyListed(balance);

        uint56 rest = balance - asset.available;
        // El fondo debe poseer la cantidad que desea suministrar
        if (supply > rest) revert ErrorInsufficientAssets(rest, supply);

        // Se actualizan las cantidades del activo
        asset.listed += supply;
        asset.available += supply;

        emit AssetRestocked(id, supply);  
    }

    /**
    @notice Desabastece una cantidad de activos ya existentes
    @param id (uint256) Identificador del activo
    @param desupply (uint56) Cantidad a desabastecer
        @dev Solo el Fondo de Inversión puede desabastecer activos
        @dev La cantidad a desabastecer debe ser positiva
        @dev El activo DEBE estar suministrado previamente
        @dev No debe superar la cantidad de activos disponibles (suministrados y aún sin vender)
    */
    function delistAsset(uint256 id, uint56 desupply) external onlyOwner inputIsPositive(desupply) {
        Asset storage asset = assetList[id];
        // El activo debe estar suministrado previamente
        if (asset.listed == 0) revert ErrorAssetNotAvailable(id);

        // La cantidad de activos disponibles debe ser mayor o igual que la cantidad a desabastecer
        if(desupply > asset.available) revert ErrorInsufficientAssets(asset.available, desupply);

        // Se actualizan las cantidades del activo. Comprobaciones anteriores garantizan que no será negativo
        unchecked {
            asset.listed -= desupply;
            asset.available -= desupply;
        }

        emit AssetDelisted(id, asset.listed, asset.value);
    }

    /**
    @notice Actualiza los datos de un activo suministrado (Solo afectará a los activos aún sin vender)
    @param id (uint256) Identificador del activo
    @param value (uint128) Valor unitario del activo
    @param marketable (bool) Si el activo es negociable o no
        @dev Solo el Fondo de Inversión puede actualizar activos
        @dev El valor unitario del activo debe ser positivo
        @dev El activo DEBE estar suministrado previamente
    */
    function updateAsset(uint256 id, uint128 value, bool marketable) external onlyOwner inputIsPositive(value) {
        Asset storage asset = assetList[id];
        // Asset debe estar suministrado previamente
        if (asset.listed == 0) revert ErrorAssetNotAvailable(id);

        asset.value = value;
        asset.marketable = marketable;

        emit AssetUpdated(id, value, marketable);
    }

    /**
    @notice Compra de activos
    @param id (uint256) Identificador del activo
    @param amount (uint56) Cantidad de activos a comprar
        @dev La cantidad de activos a comprar debe ser positiva
        @dev No se permite la compra por parte del Fondo de Inversion (Ya posee los activos)
        @dev Los activos solicitados deben estar disponibles
        @dev El balance de tokens del comprador debe ser suficiente
        @dev El comprador y el Fondo de Inversion deben aprobar al contrato (Marketplace) para el intercambio
    */
    function buyAsset(uint256 id, uint56 amount) external nonReentrant inputIsPositive(amount) whenNotPaused {
        // No esta permitido que el fondo adquiera activos (ya los posee)
        if (msg.sender == owner()) revert ErrorAddressNotAllowed();

        Asset storage asset = assetList[id];
        // Debe estar suministrados activos suficientes
        if (amount > asset.available) revert ErrorInsufficientAssets(asset.available, amount);

        uint128 totalValue = asset.value * amount;
        uint256 balance = digitalCurrency.balanceOf(msg.sender);
        // El comprador debe tener suficientes tokens para la compra
        if (balance < totalValue) revert ErrorInsufficientBalance(totalValue, balance);

        // Se actualiza disponiblididad de activos. Comprobaciones anteriores garantizan que no será negativo
        unchecked{
            asset.available -= amount;
        }

        //**digitalCurrency: Vendedor debe aprobar totalValue a Marketplace**
        digitalCurrency.transferFrom(msg.sender, owner(), totalValue);

        //**digitalAssets: Fondo debe aprobar All a Marketplace**
        digitalAssets.safeTransferFrom(owner(), msg.sender, id, amount, "");

        emit AssetBought(msg.sender, id, amount, totalValue);
    }

    /**
    @notice Venta de activos hacia el Fondo de Inversión
    @param id (uint256) Identificador del activo
    @param amount (uint56) Cantidad de activos a vender
        @dev La cantidad de activos a vender debe ser positiva
        @dev El activo debe estar marcado como negociable (marketable)
        @dev El vendedor debe disponer de los activos ofrecidos
        @dev El balance de tokens del Fondo de Inversión debe ser suficiente
        @dev El comprador y el Fondo de Inversion deben aprobar al contrato (Marketplace) para el intercambio
    */
    function sellAsset(uint256 id, uint56 amount) external nonReentrant inputIsPositive(amount) whenNotPaused {
        Asset storage asset = assetList[id];
        // El activo debe estar marcado como negociable
        if(!asset.marketable) revert ErrorAssetNotMarketable(id);

        uint56 assetBalance = uint56(digitalAssets.balanceOf(msg.sender, id));
        // El vendedor debe poseer la cantidad ofrecida
        if (assetBalance < amount) revert ErrorInsufficientAssets(assetBalance, amount);

        // Se actualiza disponiblididad de activos
        asset.available += amount;

        //**digitalAssets: Vendedor debe aprobar All a Marketplace**
        digitalAssets.safeTransferFrom(msg.sender, owner(), id, amount, "");

        //**digitalCurrency: Fondo debe aprobar totalValue a Marketplace**
        uint128 totalValue = asset.value * amount;
        digitalCurrency.transferFrom(owner(), msg.sender, totalValue);

        emit AssetSold(msg.sender, id, amount, totalValue);
    }
}