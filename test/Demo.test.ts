import { formatUnits, parseEther } from "ethers/lib/utils";
import { artifacts, contract } from "hardhat";
import { assert, expect } from "chai";
import { BN, constants, expectEvent, expectRevert, time, balance, ether, send } from "@openzeppelin/test-helpers";

const Demo = artifacts.require('Demo');

const DISABLE_ALL = new BN('20000000', 16).add(new BN('40000000', 16));
const DISABLE_CURVE_ALL = new BN('200000000000', 16);
const DISABLE_PANCAKESWAP_V2_ALL = new BN('400000000000', 16);

contract("Demo", ([alice, bob, carol, david, erin]) => {
    let demo;

    before(async () => {
        demo = await Demo.new();
    });

    describe('Demo', async () => {
        it('calculateCurve', async () => {
            const res = await demo.calculateCurve(
                '0x6B175474E89094C44Da98b954EedeAC495271d0F',
                '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
                '1000000000000000000000000', // 1,000,000.00
                1, // parts
                0 // DISABLE_ALL.add(DISABLE_CURVE_ALL) // enable only CURVE
            );

            for (let i = 0; i < res['rets'].length; i++) {
                console.log(res['rets'][i].toString());
            }
        });
    });
});
