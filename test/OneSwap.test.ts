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
const UNISWAP_V2_ALL = new BN('400000000000', 16);

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
        it('should work with Uniswap DAI => USDC', async () => {
            const res = await oneSwap.getExpectedReturn(
                '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI
                '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
                '1000000000000000000000000', // 1,000,000.00
                10, // parts
                DISABLE_ALL.add(CURVE_ALL) // enable only CURVE
            );

            console.log('Swap: 1,000,000 DAI');
            console.log('returnAmount:', res.returnAmount.toString() / 1e6 + ' USDC');
            console.log('distribution:', res.distribution.map(a => a.toString()));
            // console.log('raw:', res.returnAmount.toString());
            //expect(res.returnAmount).to.be.bignumber.above('390000000');
        });
    });
});
