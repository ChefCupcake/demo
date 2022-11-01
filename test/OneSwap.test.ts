import { formatUnits, parseEther } from "ethers/lib/utils";
import { artifacts, contract } from "hardhat";
import { assert, expect } from "chai";
import { BN, constants, expectEvent, expectRevert, time } from "@openzeppelin/test-helpers";

const OneSwapView = artifacts.require('OneSwapView');
const OneSwapViewWrap = artifacts.require('OneSwapViewWrap');
const OneSwap = artifacts.require('OneSwap');
const OneSwapWrap = artifacts.require('OneSwapWrap');
const Demo = artifacts.require('Demo');

const DISABLE_ALL = new BN('20000000', 16).add(new BN('40000000', 16));
const STABLESWAP_ALL = new BN('200000000000', 16);
const PANCAKESWAP_V2_ALL = new BN('400000000000', 16);

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
        demo = await Demo.new();
    });

    describe('OneSwap', async () => {
        it('should work with Pancakeswap BUSD => HAY', async () => {
            const res = await oneSwap.getExpectedReturn(
                '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56', // BUSD
                '0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5', // HAY
                '1000000000000000000000000', // 1,000,000.00
                10, // parts
                0 // DISABLE_ALL.add(STABLESWAP_ALL) // enable only STABLESWAP
            );

            console.log('Swap: 1,000,000 BUSD');
            console.log('returnAmount:', res.returnAmount.toString() / 1e6 + ' HAY');
            console.log('distribution:', res.distribution.map(a => a.toString()));

            // console.log('raw:', res.returnAmount.toString());
            //expect(res.returnAmount).to.be.bignumber.above('390000000');

            // console.log('#### balances:');
            // const res = await demo.getStableSwapPoolInfo();
            // for (let i = 0; i < res['balances'].length; i++) {
            //     console.log(res['balances'][i].toString());
            // }
            // console.log('#### precisions:');
            // for (let i = 0; i < res['precisions'].length; i++) {
            //     console.log(res['precisions'][i].toString());
            // }
            // console.log('#### rates:');
            // for (let i = 0; i < res['rates'].length; i++) {
            //     console.log(res['rates'][i].toString());
            // }
            // console.log('#### amp:');
            // console.log(res['amp'].toString());
            // console.log('#### fee:');
            // console.log(res['fee'].toString());
        });
    });
});
