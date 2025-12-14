import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const CurrencyModule = buildModule("CurrencyModule", (m) => {
    const currency =  m.contract("DigitalCurrency");
    return { currency }
});

export default CurrencyModule;