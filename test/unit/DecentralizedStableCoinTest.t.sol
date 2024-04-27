// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin dsc;

    function setUp() public {
        dsc = new DecentralizedStableCoin();
    }

    /////////////////////////////
    // Minting Tests           //
    /////////////////////////////

    function testMint() public {
        dsc.mint(address(this), 1000e8);
        assertEq(dsc.balanceOf(address(this)), 1000e8);
    }

    function testRevertsIfZeroAddress() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), 1000e8);
    }

    function testRevertsIfZeroAmountMint() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.mint(address(this), 0);
    }

    function testRevertsOnlyOwnerMint() public {
        dsc.renounceOwnership();
        vm.expectRevert();
        dsc.mint(address(this), 1000e8);
    }

    /////////////////////////////
    // Burning Tests           //
    /////////////////////////////

    function testBurn() public {
        dsc.mint(address(this), 1000e8);
        dsc.burn(1000e8);
        assertEq(dsc.balanceOf(address(this)), 0);
    }

    function testRevertsIfZeroAmountBurn() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.burn(0);
    }

    function testRevertsIfAmountExceedsBalance() public {
        dsc.mint(address(this), 1000e8);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(1001e8);
    }

    function testRevertsOnlyOwnerBurn() public {
        dsc.mint(address(this), 1000e8);
        dsc.renounceOwnership();
        vm.expectRevert();
        dsc.burn(1000e8);
    }
}
