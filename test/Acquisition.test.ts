import { network } from "hardhat";

import assert from "node:assert/strict";
import { describe, it } from "node:test";

const { viem, networkHelpers } = await network.connect();

describe("Bateria Test Acquisition", () => {
    async function deployAcquititionFixture() {
        const publicClient = await viem.getPublicClient();
        const [fund, investor1] = await viem.getWalletClients();

        const currency = await viem.deployContract("DigitalCurrency");
        const assets = await viem.deployContract("DigitalAssets");
        const acquisition = await viem.deployContract("Acquisition",[currency.address, assets.address]);

        console.log("Minteo de tokens y assets iniciales");
        await currency.write.mint([fund.account.address, 100000n]);
        await currency.write.mint([investor1.account.address, 10000n]);
        await assets.write.mintBatch([fund.account.address, [1n, 2n], [1n, 10n], "0x"]);

        return { acquisition, currency, assets, fund, investor1, publicClient };
    };

    it("TEST 1 - Pause / Unpause", async () => {
        const {acquisition, fund} = await networkHelpers.loadFixture(deployAcquititionFixture);

        // Pausar contrato
        await acquisition.write.pause({account: fund.account});
        let isPaused = await acquisition.read.paused();
        assert.equal(isPaused, true);

        // Reanudar contrato
        await acquisition.write.unpause({account: fund.account});
        isPaused = await acquisition.read.paused();
        assert.equal(isPaused, false);
    });

    it("TEST 2 - Solo Fondo de Inversión puede suministrar activos", async () => {
        const {acquisition, fund, investor1,  publicClient} = await networkHelpers.loadFixture(deployAcquititionFixture);

        // REVERT: Intento de suministro por parte de un inversor
        await assert.rejects(async () => {
            await acquisition.write.listNewAsset([2n, 5n, 5n, true], {account: investor1.account});
        });

        // Suministro por parte del Fondo de Inversión
        const hash = await acquisition.write.listNewAsset([1n, 1n, 10n, false], {account: fund.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });

        const events = await publicClient.getContractEvents({
            address: acquisition.address,
            abi: acquisition.abi,
            eventName: 'AssetListed',
            fromBlock: receipt.blockNumber,
        }); 
        assert.equal(events.length, 1);
        const args = events[0].args;
        assert.equal(args.id, 1n);
        assert.equal(args.supply, 1n);
        assert.equal(args.value, 10n);
    });

    it("TEST 3 - Solo Fondo de Inversión puede desabastecer activos", async () => {
        const {acquisition, fund, investor1, publicClient} = await networkHelpers.loadFixture(deployAcquititionFixture);

        // Suministro inicial por parte del Fondo de Inversión
        const hashList = await acquisition.write.listNewAsset([1n, 1n, 10n, false], {account: fund.account});
        await publicClient.getTransactionReceipt({ hash: hashList });

        // REVERT: Intento de desabastecimiento por parte de un inversor
        await assert.rejects(async () => {
            await acquisition.write.delistAsset([1n, 1n], {account: investor1.account});
        });

        // Desabastecimiento por parte del Fondo de Inversión
        const hashDelist = await acquisition.write.delistAsset([1n, 1n], {account: fund.account});
        const receiptDelist = await publicClient.getTransactionReceipt({ hash: hashDelist });

        const events = await publicClient.getContractEvents({
            address: acquisition.address,
            abi: acquisition.abi,
            eventName: 'AssetDelisted',
            fromBlock: receiptDelist.blockNumber,
        }); 
        assert.equal(events.length, 1);
        const args = events[0].args;
        assert.equal(args.id, 1n);
        assert.equal(args.supply, 0n);
        assert.equal(args.value, 10n);
    });


    it("TEST 4 - Solo Fondo de Inversión puede modificar activos suministrados", async () => {
        const {acquisition, fund, investor1, publicClient} = await networkHelpers.loadFixture(deployAcquititionFixture);

        // Suministro inicial por parte del Fondo de Inversión
        await acquisition.write.listNewAsset([2n, 10n, 100n, false], {account: fund.account});

        // REVERT: Intento de actualización por parte de un inversor
        await assert.rejects(async () => {
            await acquisition.write.updateAsset([2n, 20n, true], {account: investor1.account});
        });

        // Actualización por parte del Fondo de Inversión
        const hash = await acquisition.write.updateAsset([2n, 20n, true], {account: fund.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });
        const events = await publicClient.getContractEvents({
            address: acquisition.address,
            abi: acquisition.abi,
            eventName: 'AssetUpdated',
            fromBlock: receipt.blockNumber,
        }); 
        assert.equal(events.length, 1);
        const args = events[0].args;

        assert.equal(args.id, 2n);
        assert.equal(args.value, 20n);
        assert.equal(args.marketable, true);
    });

    it("TEST 6 - Copmpra de activos", async () => { 
        const {acquisition, currency, assets, fund, investor1, publicClient} = await networkHelpers.loadFixture(deployAcquititionFixture);

        // Listar activo
        await acquisition.write.listNewAsset([2n, 10n, 100n, true], {account: fund.account});

        // Aprobaciones para compra de activo
        await currency.write.approve([acquisition.address, 200n], {account: investor1.account});
        await assets.write.setApprovalForAll([acquisition.address, true], {account: fund.account});

        // Comprar activos
        const hash = await acquisition.write.buyAsset([2n, 2n], {account: investor1.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });
        const events = await publicClient.getContractEvents({
            address: acquisition.address,
            abi: acquisition.abi,
            eventName: 'AssetBought',
            fromBlock: receipt.blockNumber,
        }); 
        assert.equal(events.length, 1);
        const args = events[0].args as any;

        assert.equal(args.buyer.toLowerCase(), investor1.account.address.toLowerCase());
        assert.equal(args.id, 2n);
        assert.equal(args.amount, 2n);
        assert.equal(args.value, 200n);
    });

    it("TEST 7 - Venta de activos - solo negociables - solo disponibles", async () => { 
        const {acquisition, currency, assets, fund, investor1, publicClient} = await networkHelpers.loadFixture(deployAcquititionFixture);

        // Listar activo no negociable
        await acquisition.write.listNewAsset([2n, 10n, 100n, false], {account: fund.account});

        // Aprobaciones para venta de activo
        await currency.write.approve([acquisition.address, 100n], {account: investor1.account});
        await assets.write.setApprovalForAll([acquisition.address, true], {account: fund.account});

        // Comprar activos
        await acquisition.write.buyAsset([2n, 1n], {account: investor1.account});

        // REVERT: Intentar vender activo NO NEGOCIABLE
        await assert.rejects(async () => {
            await acquisition.write.sellAsset([2n, 1n], {account: investor1.account});
        }, (err: any) => err.message.includes("ErrorAssetNotMarketable"));

        // Actualizar activo a negociable
        const hashBought = await acquisition.write.updateAsset([2n, 100n, true], {account: fund.account});
        await publicClient.getTransactionReceipt({ hash: hashBought });

        // Aprobaciones para venta de activo
        await currency.write.approve([acquisition.address, 100n], {account: fund.account});
        await assets.write.setApprovalForAll([acquisition.address, true], {account: investor1.account});

        // REVERT: Intentar vender activo NO DISPONIBLE
        await assert.rejects(async () => {
            await acquisition.write.sellAsset([2n, 2n], {account: investor1.account});
        }, (err: any) => err.message.includes("ErrorInsufficientAssets"));

        // Vender activo
        const hashSold = await acquisition.write.sellAsset([2n, 1n], {account: investor1.account});
        const receipt = await publicClient.getTransactionReceipt({ hash: hashSold });

        // Comprobar evento AssetSold
        const events = await publicClient.getContractEvents({
            address: acquisition.address,
            abi: acquisition.abi,
            eventName: 'AssetSold',
            fromBlock: receipt.blockNumber,
        }); 
        assert.equal(events.length, 1);
        const args = events[0].args as any;

        assert.equal(args.seller.toLowerCase(), investor1.account.address.toLowerCase());
        assert.equal(args.id, 2n);
        assert.equal(args.amount, 1n);
        assert.equal(args.value, 100n);
    });
})