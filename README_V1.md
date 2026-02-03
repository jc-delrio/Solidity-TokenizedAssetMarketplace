*Juan Carlos Del Río Ruger*
## Caso Práctico Máster en Ingeniería y Desarrollo Blockchain V1
### Modelización de un Sistema de Compra-Venta de Activos Tokenizados - Smart Contracts 

# 1. ELECCIÓN DE TOKENS

### 1.1. ERC20
La **moneda digital** (CBDC) a usar en la plataforma seguirá el estándar ERC20.

*Ventajas*:
- **Simple**: Programación `sencilla` y facilidad de integración
- **Fungible**: Los tokens son `intercambiables entre sí`, tienen el mismo valor
- **Compatible**: Ampliamente usado y `aceptado` por wallets y exchanges

*Desventajas*:
- **No regulado**: No existen mecanismos de `control legal` (KYC)

Se ha descartado el uso de security tokens con ERC1400 porque se aleja del objetivo de `prototipo funcional del sistema`.
> En fases posteriores puede estudiarse la necesitad de implementar este token regulado por SEC o CNMV o capas de seguridad adicionales

### 1.2. ERC1155
Los **activos digitales** se definen con el estándar mixto ERC1155.

*Ventajas*
- **Unificado**: Permite contener diferentes activos bajo el mismo contrato, sin necesidad de desplegar un contrato por activo.
- **Versátil**: Permite definir activos `fungibles` (como ERC20), `no fungibles` (como ERC721) o `semi-fungibles`, para adaptarse a las caracteristicas del activo.
- **Ahorro** : Es posible realizar transacciones en `batch` para ahorrar costes (Por ejemplo para ETF's).

*Desventajas*
- **No regulado**: Tampoco contamos con mecanismos de `control legal`. Deben implementarse capas de seguridad.

# 2. INSTRUCCIONES DE COMPILACIÓN

1. Descomprrimir el archivo del caso práctico
2. npm install : Instala dependencias usadas
3. npx hardhat compile : Compilar archivos del proyecto
7. npx hardhat test: Ejecución de baterias de test programadas

# 3. CONTRATOS

## 3.1. Contrato Acquisition
### 3.1.1 Funciones
- **pause / unpause**: Permite habilitar/desabilitar funciones críticas como commprar y vender activos en caso de deteccion de busg.

- **listNewAsset**: Registers a new asset in the catalog (ID, Price, Stock).
- **restockAsset**: Increases the inventory of an existing asset. 
- **delistAsset**: Removes inventory from the market (unsold stock only).   
- **updateAsset**: Updates the price or the marketable status of an asset.   
 
- **buyAsset**: Buys assets. Requires: Prior approve of the ERC20 token.  
- **sellAsset**: Sells assets back to the fund. Requires: Asset marked as marketable and setApprovalForAll of the ERC1155.  

### 3.1.2 Flujo Principal
    Este Contrato permite a los inversores la adquisición inicial de activos disponibles por el fondo de inversión.
    El fondo debe suministrar estos activos a la plataforma para permitir la adquisición, reservandose la estrategia de suministro de activos.

    Una vez el activo está disponible para adquirir, un inversor puede realizar la compra, seleccionando la cantidad de activos deseada.
    Los activos pueden ser de diversas caracteristicas:
        - Activos Unicos (No Fungibles - NFT)
        - Activos Fraccionados (Fungibles / Semi-Fungibles)

    Si los activos son declarados por el fondo de inversion como negocibles (modificable siempre que los activos estén sin adquirir), el inversor
    puede venderlos de vuelta al fondo de inversión.

## 3.2. Contrato Compraventa entre inversores
### 3.1.1 Funciones
- **pause / unpause**: Permite habilitar/desabilitar funciones críticas como commprar y vender activos en caso de deteccion de busg.

- **request**: Un inversor solicita un activo para su compra, cuando no se conoce un vendedor. El inversor deposita el balance necesario en el contrato como garantía.
- **approveDemand**: El Fondo aprueba la solicitud realizada por un inversor.
- **sellAsset**: Un inversor (poseedor del activo) acepta la solicitud y realiza la venta. Ambas partes reciben lo pactado.
- **cancelRequest**: Un inversor cancela una solicitud realizada por él mismo. El balance pasa a su disposición para ser retirado.
- **withdrawBalance**: Un inversor puede retirar su balance de una solicitud cancelada.

- **supply**: Un inversor ofrece un activo para su venta, cuando no se conoce un comprador. El inversor deposita los activos ofrecidos en el contrato como garantía.
- **approveOffer**: El Fondo aprueba la oferta realizada por un inversor.
- **buyAsset**: Un inversor (poseedor del balance necesario) acepta la oferta y realiza la compra. Ambas partes reciben lo pactado.
- **cancelSupply**: Un inversor cancela una oferta realizada por él mismo. Los activos pasan a su disposición para ser retirado.
- **withdrawAssets**: Un inversor puede retirar los activos de una oferta cancelada.

### 3.1.2 Flujo Principal
    Para la compraventa entre inversores se ha implementado la funcionalidad de hacer visibles ofertas y demandas.
    Esto permite exponer las peticiones para que otro interesado ejecute la acción de compra o venta.
    > Es necesario que la solicitud o demanda sea realizada previamente para permitir el intercambio.    

    Lógica de Venta:
    - Un Inversor interesado en comprar un activo demanda dicho activo (ID, Cantidad y Precio). El precio total se deposita en el contrato.
    - El fondo debe aprobar esta solicitud antes de poder ser visible para el resto de inversores.
        - El Inversor que inició la solicitud puede cancelarla en cualquier momento antes de un intercambio (esté aprobada o no).
        - El inversor puede retirar el balance acumulado de cancelar demandas.
    - Otro inversor poseedor del activo y dispuesto a su venta ejecuta la orden. El intercambio se realiza: Vendedor transfiere activos a Copmprador y Contrato transfiere precio total a Vendedor.

    Lógica de Compra:
    - Un Inversor interesado en vender activos oferta dicho activo (ID, Cantidad y Precio). Los activos se deposita en el contrato.
    - El fondo debe aprobar esta oferta antes de poder ser visible para el resto de inversores.
        - El Inversor que inició la oferta puede cancelarla en cualquier momento antes de un intercambio (esté aprobada o no).
        - El inversor puede retirar los activos acumulados de cancelar ofertas.
    - Otro inversor poseedor balance necesario y dispuesto a su comprar ejecuta la orden. El intercambio se realiza: Comprador transfiere balance a Vendedor y Contrato transfiere activos a Comprador.

# 4. REALIZACION DE TEST
Se ha creado una bateria de test independiente para los distintos contratos:
- DigitalCurrency
- DigitalAssets
- Acquisition
- Trading

Entre los test realizados se incluyen:
- Test Pause / UnPause en cada contrato
- Test Permisos Owner en cada contrato
- Test Funcional por funciones
- Test Lógica adquisición inicial
- Test Lógica compraventa entre inversores

# 5. FUTURAS MEJORAS
- Implemetar capas de seguridad para tokens
- Añadir tasas por el uso de la plataforma
- En adquisiciones iniciales, no realizar transferencias directas al fondo. Acumular balance para retirar para ahorro de gas.
- Mejorar mecanismo de cancelación de ofertas/demandas para permiti a los inversores usar balance y activos ya almacenados en el contrato para nuevas ofertas/demandas
