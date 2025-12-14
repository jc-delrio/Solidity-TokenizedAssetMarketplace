import { network } from "hardhat";

import assert from "node:assert/strict";
import { describe, it } from "node:test";

const { viem, networkHelpers } = await network.connect();

describe("Bateria Test Digital Currency:", () => {
    async function deployCurrencyFixture() {
        const [fund, investor1] = await viem.getWalletClients();

        const currency = await viem.deployContract("DigitalCurrency");

        return { currency, fund, investor1 };
    }

    it("TEST 1 - Verificación de minteos)", async () => {
        const {currency, fund, investor1} = await networkHelpers.loadFixture(deployCurrencyFixture);

        console.log("Se asignan 100.000 tokens al Fondo de Inversión");
        await currency.write.mint([fund.account.address, 100000n]);

        console.log("Se asignan 10.000 tokens al Inversor 1");
        await currency.write.mint([investor1.account.address, 10000n]);

        const fundBalanceCurrency = await currency.read.balanceOf([fund.account.address]);
        const investor1BalanceCurrency = await currency.read.balanceOf([investor1.account.address]);

        assert.equal(fundBalanceCurrency, 100000n);
        assert.equal(investor1BalanceCurrency, 10000n);
    });

    it("TEST 2 - Pause bloquea funciones críticas (mint, burn)", async () => {
        const {currency, fund} = await networkHelpers.loadFixture(deployCurrencyFixture);
        const increment = 100n;

        // Pausar contrato
        await currency.write.pause();
        const isPaused = await currency.read.paused();
        assert.equal(isPaused, true);

        // REVERT: Intento de minteo y quema mientras el contrato está pausado
        await assert.rejects(async () => {
            await currency.write.mint([fund.account.address, increment]);
        });

        await assert.rejects(async () => {
            await currency.write.burn([fund.account.address, increment]);
        });
    });

    it("TEST 3 - pause -> unpause: desbloquea las funciones críticas (mint, burn)", async () => {
        const {currency, fund} = await networkHelpers.loadFixture(deployCurrencyFixture);
        const initialBalance = await currency.read.balanceOf([fund.account.address]);
        const increment = 100n;

        // Pausar contrato
        await currency.write.pause();
        let isPaused = await currency.read.paused();
        assert.equal(isPaused, true);

        // Reanudar contrato
        await currency.write.unpause();
        isPaused = await currency.read.paused();
        assert.equal(isPaused, false);

        // Funcionalidad de minteo y quema desbloqueada
        await assert.doesNotReject(async () => {
            await currency.write.mint([fund.account.address, increment]);
        }, async ()=>{
            const mintedBalance = await currency.read.balanceOf([fund.account.address]);
            assert.equal(mintedBalance, initialBalance + increment);
        });

        await assert.doesNotReject(async () => {
            await currency.write.burn([fund.account.address, increment]);
        }, async ()=>{
            const burnedBalance = await currency.read.balanceOf([fund.account.address]);
            assert.equal(burnedBalance, initialBalance);
        });
    });

    it("TEST 4 - Solo el Fondo puede desplegar/quemar tokens", async () => {
        const {currency, investor1} = await networkHelpers.loadFixture(deployCurrencyFixture);

        // REVERT: Intento de minteo y quema por parte de un inversor
        await assert.rejects(async () => {
            await currency.write.mint([investor1.account.address, 100n], {account: investor1.account});
        });

        await assert.rejects(async () => {
            await currency.write.burn([investor1.account.address, 100n], {account: investor1.account});
        })
    });
});