// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {Test, console} from "forge-std/Test.sol";
import {OracleLib, AggregatorV3Interface} from "../../src/libraries/OracleLib.sol";

contract OracleLibTest is Test {
    using OracleLib for AggregatorV3Interface;

    MockV3Aggregator public aggregator;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2500 ether;

    function setUp() public {
        aggregator = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
    }

    function testGetTimout() public {
        uint256 expectedTimeOut = 3 hours;
        uint256 actualTimeOut = OracleLib.getTimeout(AggregatorV3Interface(address(aggregator)));
        assertEq(actualTimeOut, expectedTimeOut);
    }

    function testRevertsOnStaleCheck() public {
        vm.warp(block.timestamp + 4 hours + 1 seconds);
        vm.roll(block.number + 1);

        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        AggregatorV3Interface(address(aggregator)).staleCheckLatestRoundData();
    }

    function testRevertsOnBadAnsersInRound() public {
        uint80 _roundId = 0;
        int256 _answer = 0;
        uint256 _startedAt = 0;
        uint256 _updatedAt = 0;
        aggregator.updateRoundData(_roundId, _answer, _startedAt, _updatedAt);

        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        AggregatorV3Interface(address(aggregator)).staleCheckLatestRoundData();
    }
}
