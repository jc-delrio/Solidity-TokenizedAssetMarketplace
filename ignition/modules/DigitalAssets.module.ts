import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AssetsModule = buildModule("AssetsModule", (m) => {
    const assets =  m.contract("DigitalAssets");
    return { assets }
});

export default AssetsModule;