// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ethereum.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Vesting is Ownable {
    Ethereum ethereum;

    using SafeMath for uint256;

    uint256 paymentId;

    struct payment {
        address employer;
        address employee;
        uint256 amount;
        uint256 balance;
        uint256 start;
        uint256 duration;
        bool canBeCancelled;
        uint256 released;
        bool cancelled;
        bool paymentComplete;
    }

    mapping(uint256 => payment) public payments; //payments storage by ID

    constructor(address _ethereum) {
        ethereum = Ethereum(_ethereum);
    }

    function newPayment(
        address employee,
        uint256 amount,
        uint256 start,
        uint256 duration,
        bool canBeCancelled
    ) public {
        require(duration > 0); // require duration of payment is longer than 0
        require(start.add(duration) > block.timestamp); // make sure end time is later than current time
        ethereum.transferFrom(msg.sender, address(this), amount); //transfer ethereum from msg.sender to vesting contract
        payments[paymentId].employer = msg.sender; //assign payment initiator as employer
        payments[paymentId].amount = amount; // assign variables into paymentId struct
        payments[paymentId].employee = employee;
        payments[paymentId].canBeCancelled = canBeCancelled;
        payments[paymentId].duration = duration;
        payments[paymentId].start = start;
        paymentId++;
    }

    function release(uint256 _paymentId) public {
        require(
            payments[_paymentId].employee == msg.sender,
            "only assigned empoyee can claim release"
        );
        uint256 unreleased = _releasableAmount(_paymentId); // variable unreleased triggers releasable amount function.
        console.log(unreleased, "unreleased");
        require(unreleased > 0); // require unreleased amount is greater than 0
        payments[_paymentId].released = payments[_paymentId].amount.sub(
            unreleased
        ); // assign changes to paymentId struct.. tokens released equals total payment amount minus unreleased tokens.
        payments[_paymentId].balance = payments[_paymentId].amount.sub(
            payments[_paymentId].released
        ); //balance(remainder of tokens) equals total amount minus tokens released
        console.log(ethereum.balanceOf(address(this)), "balance");
        ethereum.transfer(payments[_paymentId].employee, unreleased); // transfer claimable tokens from vesting contract to employee
    }

    function cancel(uint256 _paymentId) public {
        require(payments[_paymentId].canBeCancelled, "payment not cancellable");
        require(
            !payments[_paymentId].cancelled,
            "payment has already been cancelled"
        ); //
        require(
            payments[_paymentId].employer == msg.sender,
            "only employer can cancel payment"
        );
        uint256 unreleased = _releasableAmount(_paymentId);
        uint256 refund = payments[_paymentId].balance.sub(unreleased);
        payments[_paymentId].cancelled = true;
        ethereum.transfer(msg.sender, refund);
    }

    function _releasableAmount(uint256 _paymentId)
        public
        view
        returns (uint256)
    {
        uint256 vestedAmount = _vestedAmount(_paymentId);
        return vestedAmount.sub(payments[_paymentId].released);
    }

    function _vestedAmount(uint256 _paymentId) public view returns (uint256) {
        uint256 totalBalance = payments[_paymentId].amount;

        if (
            block.timestamp >=
            payments[_paymentId].start.add(payments[_paymentId].duration)
        ) {
            // if start time has not began, return totalbalance.
            return totalBalance;
        } else {
            return
                totalBalance
                    .mul(block.timestamp.sub(payments[_paymentId].start))
                    .div(payments[_paymentId].duration);
        }
    }
}
