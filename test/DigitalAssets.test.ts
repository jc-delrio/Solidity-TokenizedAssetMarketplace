import { network } from "hardhat";

import assert from "node:assert/strict";
import { describe, it } from "node:test";

const { viem, networkHelpers } = await network.connect();

describe("Bateria Test Digital Assets:", () => {
    async function deployAssetsFixture() {
        const [fund, investor1] = await viem.getWalletClients();

        const assets = await viem.deployContract("DigitalAssets");

        return { assets, fund, investor1 };
    }

    it("TEST 1 - Verificacion de minteos", async () => {
        const { assets, fund } = await networkHelpers.loadFixture(deployAssetsFixture);

        console.log("Se generan assets: (ID:1 - 1 unidad) (ID:2 - 10 unidades) al Fondo de Inversión");
        await assets.write.mintBatch([fund.account.address, [1n, 2n], [1n, 10n], "0x"]);

        const fundAsset1Balance = await assets.read.balanceOf([fund.account.address, 1n]);
        const fundAsset2Balance = await assets.read.balanceOf([fund.account.address, 2n]);

        assert.equal(fundAsset1Balance, 1n);
        assert.equal(fundAsset2Balance, 10n);
    });

    it("TEST 2 - Pause bloquea funciones críticas (mint, burn)", async () => {
        const { assets, fund } = await networkHelpers.loadFixture(deployAssetsFixture);

        // Pausar contrato
        await assets.write.pause();
        const isPaused = await assets.read.paused();
        assert.equal(isPaused, true);

        // REVERT: Intento de minteo y quema mientras el contrato está pausado
        await assert.rejects(async () => {
            await assets.write.mint([fund.account.address, 1n, 1n, "0x"]);
        });

        await assert.rejects(async () => {
            await assets.write.burn([1n, 1n]);
        });
    });

    it("TEST 3 - pause -> unpause: desbloquea las funciones críticas (mint, burn)", async () => {
        const { assets, fund } = await networkHelpers.loadFixture(deployAssetsFixture);
        const initialBalance = await assets.read.balanceOf([fund.account.address, 1n]);

        // Pausar contrato
        await assets.write.pause();
        const isPaused = await assets.read.paused();
        assert.equal(isPaused, true);

        // Reanudar contrato
        await assets.write.unpause();
        const isNotPaused = await assets.read.paused();
        assert.equal(isNotPaused, false);

        // Funcionalidad de minteo y quema desbloqueada
        await assert.doesNotReject(async () => {
            await assets.write.mint([fund.account.address, 1n, 1n, "0x"]);
        }, async () => {
            const mintedBalance = await assets.read.balanceOf([fund.account.address, 1n]);
            assert.equal(mintedBalance, initialBalance + 1n);
        });

        await assert.doesNotReject(async () => {
            await assets.write.burn([1n, 1n]);
        }, async () => {
            const burnedBalance = await assets.read.balanceOf([fund.account.address, 1n]);
            assert.equal(burnedBalance, initialBalance);
        });
    });

    it("TEST 4 - Solo el Fondo puede desplegar/quemar tokens", async () => {
        const { assets, investor1 } = await networkHelpers.loadFixture(deployAssetsFixture);

        // REVERT: Intento de minteo y quema por parte de un inversor
        await assert.rejects(async () => {
            await assets.write.mint([investor1.account.address, 1n, 1n, "0x"], { account: investor1.account });
        });

        await assert.rejects(async () => {
            await assets.write.burn([1n, 1n], { account: investor1.account });
        })
    });
});