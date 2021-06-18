const Ethereum = artifacts.require("Ethereum");
const Vesting = artifacts.require("Vesting");

const {
  expectRevert,
  expectEvent,
  time,
} = require("@openzeppelin/test-helpers");
const { assertion } = require("@openzeppelin/test-helpers/src/expectRevert");
const { assert } = require("hardhat");

contract("Vesting", (accounts) => {
    let vesting;

    before(async function () {
        ethereum = await Ethereum.new()
        vesting = await Vesting.new(ethereum.address);
        await ethereum.mint(accounts[1], 100);
        await ethereum.approve(vesting.address, 100, {from: accounts[1]});
        await ethereum.mint(accounts[7], 100);
        await ethereum.approve(vesting.address, 100, {from: accounts[7]});
    });
    it("should be able to create a new payment", async function() {
        console.log(Number(await ethereum.balanceOf(accounts[1])));
        await vesting.newPayment(accounts[5], 100, 1623408875, 2592000, true, {from: accounts[1]});
        const {amount} = await vesting.payments(0);
        assert.equal(Number(amount), 100);
    });
    it("Player can gradually claim tokens to be released", async function() {
        await time.advanceBlock();
        await time.increase(time.duration.days(15));
        console.log(Number(await vesting._vestedAmount(0, {from: accounts[5]})), "vested amount");
        console.log(Number(await ethereum.balanceOf(vesting.address)));
        await vesting.release(0, {from: accounts[5]});
    });
    it("amount remaining updates after tokens are released", async function() {
        const {amount} = await vesting.payments(0);
        const {released} = await vesting.payments(0);
        _balance = amount - released;
        const {balance} = await vesting.payments(0);
        assert.equal(balance, _balance);
    });
    it("Only playerId's employee can claim tokens to be released", async function() {
        await expectRevert(vesting.release(0, {from: accounts[6]}), "only assigned empoyee can claim release");
        console.log(Number(await vesting._vestedAmount(0, {from: accounts[5]})), "vested amount");
        const {released} = await vesting.payments(0);
        console.log(Number(released), "released amount");
        console.log(Number(await vesting._releasableAmount(0)), "releasable amount");
    });
    it("employee can have more than one payment stream", async function() {
        await vesting.newPayment(accounts[5], 50, 1623408875, 2592000, false, {from: accounts[7]});
        const {amount} = await vesting.payments(1);
        assert.equal(Number(amount), 50);
    });
    it("Only playerId's employer can cancel a payment", async function() {
        await expectRevert(vesting.cancel(0, {from: accounts[6]}), "only employer can cancel payment");
    });
    it("payments intiated without a cancel option cannot be cancelled", async function() {
        await expectRevert(vesting.cancel(1, {from: accounts[7]}), "payment not cancellable");
    });
    
    it("Employer can cancel payment if cancellable", async function() {
        console.log()
        await vesting.cancel(0, {from:accounts[1]});
        const unreleased = await vesting._releasableAmount(0);
        const {balance} = await vesting.payments(0);
        const refund = (balance - unreleased)
        console.log(Number(await ethereum.balanceOf(accounts[1])), "ethereum balance")
        assert.equal(refund, await ethereum.balanceOf(accounts[1]));
    });
    
});