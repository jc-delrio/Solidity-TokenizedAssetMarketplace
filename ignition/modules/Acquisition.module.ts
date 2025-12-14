import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import CurrencyModule from "./DigitalCurrency.module.js";
import AssetsModule  from "./DigitalAssets.module.js";

const AcquisitionModule = buildModule("AcquisitionModule", (m) => {
    const {currency} = m.useModule(CurrencyModule);
    const {assets} = m.useModule(AssetsModule);

    const adquisition = m.contract("Acquisition", [currency, assets]);

    return { adquisition, currency, assets };
});

export default AcquisitionModule;