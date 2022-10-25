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
        it('should work with Uniswap ETH => COMP', async () => {
            const res = await oneSwap.getExpectedReturn(
                '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', // ETH
                '0xc00e94Cb662C3520282E6f5717214004A7f26888', // COMP
                '1000000000000000000', // 1.0
                10, // parts
                DISABLE_ALL.add(UNISWAP_V2_ALL) // enable only Uniswap V2
            );

            console.log('Swap: 1 ETH');
            console.log('returnAmount:', res.returnAmount.toString() / 1e18 + ' COMP');
            console.log('distribution:', res.distribution.map(a => a.toString()));
            // console.log('raw:', res.returnAmount.toString());
            //expect(res.returnAmount).to.be.bignumber.above('390000000');
        });
    });
});
