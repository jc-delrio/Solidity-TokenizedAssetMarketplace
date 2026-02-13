*Juan Carlos Del Río Ruger*
## Caso Práctico Máster en Ingeniería y Desarrollo Blockchain
# 🛒 Modelización de un Sistema de Compra-Venta de Activos Tokenizados

## 🛠 1. Modificaciones previas
En base a revisiones anteriores, los smart contracts han sido ligeramente actualizados para mejorar la eficiencia de las transacciones:
- Se usan uint256 para evitar problemas en operaciones (ahorro de gas al evitar comprobación de overflow)
- La funcion burn de los tokens ahora puede ser ejecutada por el propietario del token
- Se han eliminado las comprobaciones de valores negativos en las funciones de los smart contracts
- Se añaden eventos en contratos DigitalCurrency y DigitalAssets
- Se añade extension ERC1155Supply a DigitalAssets, implementado mapping para el control de la cantidad máxima de cada token emitido
- Se permite listar activos parcialmente, eliminando la funcion restockAsset

## 🚀 2. Despliegue de smart contracts

- Se añaden las variables de entorno RPC_URL, PRIVATE_KEY y ETHERSCAN_API_KEY a firestore de hardhat
```bash
npx hardhat keystore set ...
```

- Se configura la red Sepolia en hardhat.config.ts
```js
export default defineConfig({
  // ...
  networks: {
    // ... otras redes
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
  }
});
```

- Para que funcione la verificacíon de los smart contracts en etherscan se añade la siguiente configuración a hardhat.config.ts:     
```js
export default defineConfig({
  // ...
  verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    },
  }
});
```

- Despliegue de los smart contracts en la red de pruebas Sepolia.
> Se usa hardhat mediante ignition para el despliegue de los smart contracts:         
```bash
npx hardhat ignition deploy ignition/modules/xxx.ts --network sepolia -verify
```

### License
This project is licensed under the MIT License.
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)




