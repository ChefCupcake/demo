import { formatUnits, parseEther } from "ethers/lib/utils";
import { artifacts, contract } from "hardhat";
import { assert, expect } from "chai";
import { BN, constants, expectEvent, expectRevert, time } from "@openzeppelin/test-helpers";

const OneSwapView = artifacts.require('OneSwapView');
const OneSwapViewWrap = artifacts.require('OneSwapViewWrap');
const OneSwap = artifacts.require('OneSwap');
const OneSwapWrap = artifacts.require('OneSwapWrap');

const DISABLE_ALL = new BN('20000000', 16).add(new BN('40000000', 16));
const CURVE_ALL = new BN('200000000000', 16);
const PANCAKESWAP_V2_ALL = new BN('400000000000', 16);

contract("OneSwap", ([alice, bob, carol, david, erin]) => {
    let subOneSwapView;
    let oneSwapView;
    let subOneSwap;
    let oneSwap;

    before(async () => {
        subOneSwapView = await OneSwapView.new();
        oneSwapView = await OneSwapViewWrap.new(subOneSwapView.address);
        subOneSwap = await OneSwap.new(oneSwapView.address);
        oneSwap = await OneSwapWrap.new(oneSwapView.address, subOneSwap.address);
    });

    describe('OneSwap', async () => {
        it('should work with Pancakeswap BUSD => HAY', async () => {
            const res = await oneSwap.getExpectedReturn(
                '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56', // BUSD
                '0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5', // HAY
                '1000000000000000000000000', // 1,000,000.00
                10, // parts
                0//DISABLE_ALL.add(CURVE_ALL) // enable only CURVE
            );

            console.log('Swap: 1,000,000 HAY');
            console.log('returnAmount:', res.returnAmount.toString() / 1e6 + ' USDC');
            console.log('distribution:', res.distribution.map(a => a.toString()));
            // console.log('raw:', res.returnAmount.toString());
            //expect(res.returnAmount).to.be.bignumber.above('390000000');
        });
    });
});
