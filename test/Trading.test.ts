import { network } from "hardhat";

import assert from "node:assert/strict";
import { describe, it } from "node:test";

const { viem, networkHelpers } = await network.connect();

describe("Bateria Test Trading", () => {
    async function deployTradingFixture() {
        const publicClient = await viem.getPublicClient();
        const [fund, investor1, investor2] = await viem.getWalletClients();

        const currency = await viem.deployContract("DigitalCurrency");
        const assets = await viem.deployContract("DigitalAssets");
        const trading = await viem.deployContract("Trading",[currency.address, assets.address]);

        console.log("Minteo de tokens y assets iniciales a Inversores");
        await currency.write.mint([investor1.account.address, 250n]);
        await assets.write.mintBatch([investor2.account.address, [1n, 2n], [1n, 10n], "0x"]);

        return { trading, currency, assets, fund, investor1, investor2, publicClient };
    };

    it("TEST 1 - Pause / Unpause", async () => {
        const {trading} = await networkHelpers.loadFixture(deployTradingFixture);

        // Pausar contrato
        await trading.write.pause();
        let isPaused = await trading.read.paused();
        assert.equal(isPaused, true);

        // Reanudar contrato
        await trading.write.unpause();
        isPaused = await trading.read.paused();
        assert.equal(isPaused, false);
    });

    it("TEST 2 - Inversor solicita activos", async () => {
        const {trading, currency, investor1, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);

        // Inversor 1 aprueba el balance a custodiar por el contrato
        await currency.write.approve([trading.address, 250n], {account: investor1.account});

        // Inversor 1 solicita 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hash = await trading.write.request([2n, 5n, 50n], {account: investor1.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'AssetRequested',
            fromBlock: receipt.blockNumber,
        });

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.buyer.toLowerCase(), investor1.account.address.toLowerCase());
        assert.equal(args.id, 2n);
        assert.equal(args.amount, 5n);
        assert.equal(args.price, 50n);

        // Contrato indica los activos solicitados
        const demand = await trading.read.demands([2n,investor1.account.address]);
        assert.equal(demand[0], 5n);
        assert.equal(demand[1], 50n);
        assert.equal(demand[2], false);

        // Contrato custodia el balance ofrecido por el inversor
        const balance = await currency.read.balanceOf([trading.address]);
        assert.equal(balance, 250n);
    });

    it("TEST 3 - Inversor cancela la solicitud)", async () => {
        const {trading, currency, investor1, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);

        // Inversor 1 aprueba el balance a custodiar por el contrato
        await currency.write.approve([trading.address, 250n], {account: investor1.account});

        // Inversor 1 solicita 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hashRequested = await trading.write.request([2n, 5n, 50n], {account: investor1.account});
        await publicClient.getTransactionReceipt({ hash: hashRequested });

        // Inversor 1 cancela la solicitud
        const hash = await trading.write.cancelRequest([2n], {account: investor1.account});
        const receipt = await publicClient.getTransactionReceipt({ hash }); 

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'RequestCancelled',
            fromBlock: receipt.blockNumber,
        });

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.buyer.toLowerCase(), investor1.account.address.toLowerCase());
        assert.equal(args.id, 2n);

        // Solicitud eliminada
        const demand = await trading.read.demands([2n,investor1.account.address]);
        assert.equal(demand[0], 0n);
        assert.equal(demand[1], 0n);
        assert.equal(demand[2], false);

        // Balance a disposición del inversor tras la cancelación
        const withdrawable = await trading.read.withdrawableBalances([investor1.account.address]);
        assert.equal(withdrawable, 250n);
    });

    it("TEST 4 - Fondo aprueba la solicitud)", async () => {
        const {trading, currency, fund, investor1, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);

        // Inversor 1 aprueba el balance a custodiar por el contrato
        await currency.write.approve([trading.address, 250n], {account: investor1.account});

        // Inversor 1 solicita 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hashRequested = await trading.write.request([2n, 5n, 50n], {account: investor1.account});
        await publicClient.getTransactionReceipt({ hash: hashRequested });

        // Fondo aprueba la solicitud del Inversor 1
        const hash = await trading.write.approveDemand([investor1.account.address, 2n], {account: fund.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'FundApproved',
            fromBlock: receipt.blockNumber,
        });

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.investor.toLowerCase(), investor1.account.address.toLowerCase());
        assert.equal(args.id, 2n);

        // Comprobación de solicitud aprobada
        const demand = await trading.read.demands([2n,investor1.account.address]);
        assert.equal(demand[2], true);
    });

    it("TEST 5 - Ejecución de Venta)", async () => {
        const {trading, currency, assets, fund, investor1, investor2, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);

        // Inversor 1 aprueba el balance a custodiar por el contrato
        await currency.write.approve([trading.address, 250n], {account: investor1.account});

        // Inversor 1 solicita 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hashRequested = await trading.write.request([2n, 5n, 50n], {account: investor1.account});
        await publicClient.getTransactionReceipt({ hash: hashRequested });

        // Fondo aprueba la solicitud del Inversor 1
        const hashApproved = await trading.write.approveDemand([investor1.account.address, 2n], {account: fund.account});
        await publicClient.getTransactionReceipt({ hash: hashApproved });

        // Aprobaciones para venta
        await assets.write.setApprovalForAll([trading.address, true], {account: investor2.account}); 

        // Ejecución de venta por parte del Inversor 2
        const hash = await trading.write.sellAsset([investor1.account.address, 2n, 5n], {account: investor2.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'AssetSold',
            fromBlock: receipt.blockNumber,
        });

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.seller.toLowerCase(), investor2.account.address.toLowerCase());
        assert.equal(args.buyer.toLowerCase(), investor1.account.address.toLowerCase());
        assert.equal(args.id, 2n);
        assert.equal(args.amount, 5n);
        assert.equal(args.price, 50n);

        // Comprobación de balances tras la venta
        const buyerBalance = await currency.read.balanceOf([investor1.account.address]);
        assert.equal(buyerBalance, 0n);
        const buyerAssetBalance = await assets.read.balanceOf([investor1.account.address, 2n]);
        assert.equal(buyerAssetBalance, 5n);

        const sellerBalance = await currency.read.balanceOf([investor2.account.address]);
        assert.equal(sellerBalance, 250n);
        const sellerAssetBalance = await assets.read.balanceOf([investor2.account.address, 2n]);
        assert.equal(sellerAssetBalance, 5n);
    });

    it("TEST 6 - Retiro de balance tras cancelación de solicitud)", async () => {
        const {trading, currency, investor1, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);

        // Inversor 1 aprueba el balance a custodiar por el contrato
        await currency.write.approve([trading.address, 250n], {account: investor1.account});

        // Inversor 1 solicita 5 unidades del asset ID:2 a un precio de 50 tokens por unidad
        const hashRequested = await trading.write.request([2n, 5n, 50n], {account: investor1.account});
        await publicClient.getTransactionReceipt({ hash: hashRequested });  

        // Inversor 1 cancela la solicitud
        const hashCancelled = await trading.write.cancelRequest([2n], {account: investor1.account});
        await publicClient.getTransactionReceipt({ hash: hashCancelled });

        // Retiro de balance por parte del Inversor 1
        const hash = await trading.write.withdrawBalance({account: investor1.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });     

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'CurrencyWithdrawn',
            fromBlock: receipt.blockNumber,
        });

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.investor.toLowerCase(), investor1.account.address.toLowerCase());
        assert.equal(args.amount, 250n);

        // Comprobación de balance tras el retiro
        const investorBalance = await currency.read.balanceOf([investor1.account.address]);
        assert.equal(investorBalance, 250n);

        // Comprobación de que el contrato ya no custodia los tokens
        const tradingBalance = await currency.read.balanceOf([trading.address]);
        assert.equal(tradingBalance, 0n);

        // Comprobación de que el inversor no tiene balance a retirar
        const withdrawable = await trading.read.withdrawableBalances([investor1.account.address]);
        assert.equal(withdrawable, 0n);
    });

    it("TEST 7 - Inversor ofrece activos", async () => {
        const {trading, assets, investor2, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);

        // Inversor 2 aprueba los activos a custodiar por el contrato
        await assets.write.setApprovalForAll([trading.address, true], {account: investor2.account});

        // Inversor 2 ofrece 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hash = await trading.write.supply([2n, 5n, 50n], {account: investor2.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'AssetSupplied',
            fromBlock: receipt.blockNumber,
        });

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.seller.toLowerCase(), investor2.account.address.toLowerCase());
        assert.equal(args.id, 2n);
        assert.equal(args.amount, 5n);
        assert.equal(args.price, 50n);

        // Contrato indica los activos ofrecidos
        const offer = await trading.read.offers([2n,investor2.account.address]);
        assert.equal(offer[0], 5n);
        assert.equal(offer[1], 50n);
        assert.equal(offer[2], false);

        // Contrato custodia los activos ofrecidos por el inversor
        const assetBalance = await assets.read.balanceOf([trading.address, 2n]);
        assert.equal(assetBalance, 5n);
    });

    it("TEST 8 - Inversor cancela la oferta)", async () => {
        const {trading, assets, investor2, publicClient} = await networkHelpers.loadFixture(deployTradingFixture); 

        // Inversor 2 aprueba los activos a custodiar por el contrato
        await assets.write.setApprovalForAll([trading.address, true], {account: investor2.account});

        // Inversor 2 ofrece 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hashSupplied = await trading.write.supply([2n, 5n, 50n], {account: investor2.account});
        await publicClient.getTransactionReceipt({ hash: hashSupplied });

        // Inversor 2 cancela la oferta
        const hash = await trading.write.cancelSupply([2n], {account: investor2.account});
        const receipt = await publicClient.getTransactionReceipt({ hash });

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'SupplyCancelled',
            fromBlock: receipt.blockNumber,
        });

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.seller.toLowerCase(), investor2.account.address.toLowerCase());
        assert.equal(args.id, 2n);

        // Oferta eliminada
        const offer = await trading.read.offers([2n,investor2.account.address]);
        assert.equal(offer[0], 0n);
        assert.equal(offer[1], 0n);
        assert.equal(offer[2], false);

        // Activos a disposición del inversor tras la cancelación
        const withdrawable = await trading.read.withdrawableAssets([investor2.account.address, 2n]);
        assert.equal(withdrawable, 5n);
    });

    it("TEST 9 - Fondo aprueba la oferta", async () => {
        const {trading, assets, fund, investor2, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);    

        // Inversor 2 aprueba los activos a custodiar por el contrato
        await assets.write.setApprovalForAll([trading.address, true], {account: investor2.account});

        // Inversor 2 ofrece 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hashSupplied = await trading.write.supply([2n, 5n, 50n], {account: investor2.account});
        await publicClient.getTransactionReceipt({ hash: hashSupplied });

        // Fondo aprueba la oferta del Inversor 2
        const hash = await trading.write.approveOffer([investor2.account.address, 2n], {account: fund.account});
        const receipt = await publicClient.getTransactionReceipt({ hash }); 

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'FundApproved',
            fromBlock: receipt.blockNumber,
        }); 

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.investor.toLowerCase(), investor2.account.address.toLowerCase());
        assert.equal(args.id, 2n);  

        // Comprobación de oferta aprobada
        const offer = await trading.read.offers([2n,investor2.account.address]);
        assert.equal(offer[2], true);
    });

    it("TEST 10 - Ejecución de Compra", async () => {
        const {trading, currency, assets, fund, investor1, investor2, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);

        // Inversor 2 aprueba los activos a custodiar por el contrato
        await assets.write.setApprovalForAll([trading.address, true], {account: investor2.account});

        // Inversor 2 ofrece 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hashSupplied = await trading.write.supply([2n, 5n, 50n], {account: investor2.account});
        await publicClient.getTransactionReceipt({ hash: hashSupplied });

        // Fondo aprueba la oferta del Inversor 2
        const hashApproved = await trading.write.approveOffer([investor2.account.address, 2n], {account: fund.account});
        await publicClient.getTransactionReceipt({ hash: hashApproved });

        // Inversor 1 aprueba el balance a custodiar por el contrato
        await currency.write.approve([trading.address, 250n], {account: investor1.account});    

        // Ejecución de compra por parte del Inversor 1
        const hash = await trading.write.buyAsset([investor2.account.address, 2n, 5n], {account: investor1.account});
        const receipt = await publicClient.getTransactionReceipt({ hash }); 

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'AssetBought',
            fromBlock: receipt.blockNumber,
        });     

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.buyer.toLowerCase(), investor1.account.address.toLowerCase());
        assert.equal(args.seller.toLowerCase(), investor2.account.address.toLowerCase());
        assert.equal(args.id, 2n);
        assert.equal(args.amount, 5n);
        assert.equal(args.price, 50n);

        // Comprobación de balances tras la compra
        const buyerBalance = await currency.read.balanceOf([investor1.account.address]);
        assert.equal(buyerBalance, 0n);
        const buyerAssetBalance = await assets.read.balanceOf([investor1.account.address, 2n]);
        assert.equal(buyerAssetBalance, 5n);    

        const sellerBalance = await currency.read.balanceOf([investor2.account.address]);
        assert.equal(sellerBalance, 250n);
        const sellerAssetBalance = await assets.read.balanceOf([investor2.account.address, 2n]);
        assert.equal(sellerAssetBalance, 5n); 
    });

    it("TEST 11 - Retiro de activos tras cancelación de oferta)", async () => {
        const {trading, assets, investor2, publicClient} = await networkHelpers.loadFixture(deployTradingFixture);

        // Inversor 2 aprueba los activos a custodiar por el contrato
        await assets.write.setApprovalForAll([trading.address, true], {account: investor2.account});

        // Inversor 2 ofrece 5 unidades del activo ID:2 a un precio de 50 tokens por unidad
        const hashSupplied = await trading.write.supply([2n, 5n, 50n], {account: investor2.account});
        await publicClient.getTransactionReceipt({ hash: hashSupplied });   

        // Inversor 2 cancela la oferta
        const hashCancelled = await trading.write.cancelSupply([2n], {account: investor2.account});
        await publicClient.getTransactionReceipt({ hash: hashCancelled });

        // Retiro de activos por parte del Inversor 2
        const hash = await trading.write.withdrawAssets([2n], {account: investor2.account});
        const receipt = await publicClient.getTransactionReceipt({ hash }); 

        const events = await publicClient.getContractEvents({
            address: trading.address,
            abi: trading.abi,
            eventName: 'AssetsWithdrawn',
            fromBlock: receipt.blockNumber,
        }); 

        assert.equal(events.length, 1);
        const args = events[0].args as any;
        assert.equal(args.investor.toLowerCase(), investor2.account.address.toLowerCase());
        assert.equal(args.id, 2n);
        assert.equal(args.amount, 5n);

        // Comprobación de activos tras el retiro
        const investorAssetBalance = await assets.read.balanceOf([investor2.account.address, 2n]);
        assert.equal(investorAssetBalance, 10n);

        // Comprobación de que el contrato ya no custodia los activos
        const tradingAssetBalance = await assets.read.balanceOf([trading.address, 2n]);
        assert.equal(tradingAssetBalance, 0n);

        // Comprobación de que el inversor no tiene activos a retirar
        const withdrawable = await trading.read.withdrawableAssets([investor2.account.address, 2n]);
        assert.equal(withdrawable, 0n);
    });
})