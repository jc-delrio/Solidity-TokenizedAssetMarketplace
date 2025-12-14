import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import CurrencyModule from "./DigitalCurrency.module.js";
import AssetsModule  from "./DigitalAssets.module.js";

const TradingModule = buildModule("TradingModule", (m) => {
    const {currency} = m.useModule(CurrencyModule);
    const {assets} = m.useModule(AssetsModule);

    const trading = m.contract("Trading", [currency, assets]);

    return { trading, currency, assets };
});

export default TradingModule;