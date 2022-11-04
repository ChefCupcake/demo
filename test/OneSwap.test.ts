import { formatUnits, parseEther } from "ethers/lib/utils";
import { artifacts, contract } from "hardhat";
import { assert, expect } from "chai";
import { BN, constants, expectEvent, expectRevert, time, balance, ether, send } from "@openzeppelin/test-helpers";

const OneSwapView = artifacts.require('OneSwapView');
const OneSwapViewWrap = artifacts.require('OneSwapViewWrap');
const OneSwap = artifacts.require('OneSwap');
const OneSwapWrap = artifacts.require('OneSwapWrap');
const ERC20 = artifacts.require('IERC20');
const Demo = artifacts.require('Demo');

const DISABLE_ALL = new BN('20000000', 16).add(new BN('40000000', 16));
const DISABLE_CURVE_ALL = new BN('200000000000', 16);
const DISABLE_PANCAKESWAP_V2_ALL = new BN('400000000000', 16);

contract("OneSwap", ([alice, bob, carol, david, erin]) => {
    let subOneSwapView;
    let oneSwapView;
    let subOneSwap;
    let oneSwap;
    let demo;

    before(async () => {
        subOneSwapView = await OneSwapView.new();
        oneSwapView = await OneSwapViewWrap.new(subOneSwapView.address);
        subOneSwap = await OneSwap.new(oneSwapView.address);
        oneSwap = await OneSwapWrap.new(oneSwapView.address, subOneSwap.address);
    });

    describe.skip('getExpectedReturn()', async () => {
        it('should work for DAI => USDC in PancakeSwap', async () => {
            const res = await oneSwap.getExpectedReturn(
                '0x6B175474E89094C44Da98b954EedeAC495271d0F',
                '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
                '1000000000000000000000000',
                10,
                DISABLE_CURVE_ALL
            );

            console.log('Swap: 1,000,000 DAI');
            console.log('returnAmount:', res.returnAmount.toString() / 1e6 + ' USDC');
            console.log('distribution:', res.distribution.map(a => a.toString()));
        });

        it('should work for DAI => USDC in Curve', async () => {
            const res = await oneSwap.getExpectedReturn(
                '0x6B175474E89094C44Da98b954EedeAC495271d0F', 
                '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', 
                '1000000000000000000000000',
                10, 
                DISABLE_PANCAKESWAP_V2_ALL
            );

            console.log('Swap: 1,000,000 DAI');
            console.log('returnAmount:', res.returnAmount.toString() / 1e6 + ' USDC');
            console.log('distribution:', res.distribution.map(a => a.toString()));
        });

        it('should work for DAI => USDC in all', async () => {
            const res = await oneSwap.getExpectedReturn(
                '0x6B175474E89094C44Da98b954EedeAC495271d0F',
                '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
                '1000000000000000000000000',
                10,
                0
            );

            console.log('Swap: 1,000,000 DAI');
            console.log('returnAmount:', res.returnAmount.toString() / 1e6 + ' USDC');
            console.log('distribution:', res.distribution.map(a => a.toString()));
        });

        it('should not return anything when disabling all', async () => {
            const res = await oneSwap.getExpectedReturn(
                '0x6B175474E89094C44Da98b954EedeAC495271d0F',
                '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
                '1000000000000000000000000',
                10,
                DISABLE_ALL
            );

            console.log('Swap: 1,000,000 DAI');
            console.log('returnAmount:', res.returnAmount.toString() / 1e6 + ' USDC');
            console.log('distribution:', res.distribution.map(a => a.toString()));

            expect(res.returnAmount.toString()).to.equal('0');
        });
    });

    describe.skip('getExpectedReturnWithGasMulti()', async () => {
        it('should work for ETH => DAI => USDC in any specified swaps', async () => {
            const res = await oneSwap.getExpectedReturnWithGasMulti(
                ['0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', '0x6B175474E89094C44Da98b954EedeAC495271d0F', '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'],
                ether('1'), // 1 ETH
                [100, 10], // divide ETH => DAI into 100 parts, divide DAI => USDC into 10 parts
                [DISABLE_CURVE_ALL, DISABLE_PANCAKESWAP_V2_ALL], // ETH => DAI in PancakeSwap, DAI => USDC in Curve
                [0, 0]
            );

            console.log('Swap: 1 ETH');
            console.log('DAI amount:', res.returnAmounts[0].toString() / 1e18 + ' DAI');
            console.log('USDC amount:', res.returnAmounts[1].toString() / 1e6 + ' USDC');
            console.log('distribution:', res.distribution.map(a => a.toString()));
        });

        it('should not return anything when disabling all', async () => {
            const res = await oneSwap.getExpectedReturnWithGasMulti(
                ['0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', '0x6B175474E89094C44Da98b954EedeAC495271d0F', '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'],
                ether('1'),
                [100, 10],
                [DISABLE_ALL, DISABLE_ALL], // disable all
                [0, 0]
            );

            console.log('Swap: 1 ETH');
            console.log('DAI amount:', res.returnAmounts[0].toString() / 1e18 + ' DAI');
            console.log('USDC amount:', res.returnAmounts[1].toString() / 1e6 + ' USDC');
            console.log('distribution:', res.distribution.map(a => a.toString()));

            expect(res.returnAmounts[0].toString()).to.equal('0');
            expect(res.returnAmounts[1].toString()).to.equal('0');
        });
    });
});
