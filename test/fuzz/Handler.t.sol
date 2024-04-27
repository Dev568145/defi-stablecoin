// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Handler is going to narrow down the way we call functions

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Handler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    DSCEngine engine;
    DecentralizedStableCoin dsc;

    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintCalled;
    uint256 public timesRedeemCalled;
    uint256 public timesDepositCalled;
    uint256 public timesBurnDscCalled;
    uint256 public timesTransferCalled;
    uint256 public timesLiquidateCalled;
    uint256 public timesUpdatePriceCalled;

    address[] public usersWithCollateralDeposited;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max; // max value for uint96

    // event DscMinted(address indexed to, uint256 amount);

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        engine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(engine.getPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(engine.getPriceFeed(address(wbtc)));
    }

    //////////////////////////
    // DSCEngine            //
    //////////////////////////

    function depositCollateral(uint256 collateralSeed, uint256 amountColateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountColateral = bound(amountColateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountColateral);
        collateral.approve(address(engine), amountColateral);
        engine.depositCollateral(address(collateral), amountColateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
        timesDepositCalled++;
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        uint256 maxCollateral = engine.getCollateralDeposited(msg.sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateral);

        if (amountCollateral == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        engine.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        timesRedeemCalled++;
    }

    // function mintDsc(uint256 amountDsc, uint256 addressSeed) public {
    //     if (usersWithCollateralDeposited.length == 0) {
    //         return;
    //     }

    //     address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];

    //     (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);
    //     int256 maxDscMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);

    //     if (maxDscMint < 0) {
    //         return;
    //     }
    //     amountDsc = bound(amountDsc, 0, uint256(maxDscMint));

    //     if (amountDsc == 0) {
    //         return;
    //     }

    //     vm.startPrank(sender);
    //     engine.mintDsc(amountDsc);
    //     vm.stopPrank();
    //     timesMintCalled++;

    //     emit DscMinted(sender, amountDsc);
    // }

    // function burnDsc(uint256 amountDsc) public {
    //     if (usersWithCollateralDeposited.length == 0) {
    //         return;
    //     }
    //     address userCollateral = usersWithCollateralDeposited[0];
    //     amountDsc = bound(amountDsc, 0, dsc.balanceOf(userCollateral));

    //     if (amountDsc == 0) {
    //         return;
    //     }

    //     vm.startPrank(userCollateral);
    //     dsc.approve(address(engine), amountDsc);
    //     engine.burnDsc(amountDsc);
    //     vm.stopPrank();
    //     timesBurnDscCalled++;
    // }

    function burnDsc(uint256 amountDsc) public {
        // Must burn more than 0
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        if (amountDsc == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        dsc.approve(address(engine), amountDsc);
        engine.burnDsc(amountDsc);
        vm.stopPrank();
    }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        uint256 minHealthFactor = engine.getMinimumHealthFactor();
        uint256 userHealthFactor = engine.getHealthFactor(userToBeLiquidated);
        if (userHealthFactor >= minHealthFactor) {
            return;
        }
        debtToCover = bound(debtToCover, 1, uint256(type(uint96).max));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        engine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
        timesLiquidateCalled++;
    }

    ////////////////////////////////
    // DecentralizedStableCoin    //
    ////////////////////////////////

    function transferDsc(uint256 amountDsc, address to) public {
        if (to == address(0)) {
            to = address(1);
        }

        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));

        vm.prank(msg.sender);
        dsc.transfer(to, amountDsc);
        timesTransferCalled++;
    }

    //////////////////////////
    // Aggregator           //
    //////////////////////////

    function updatePrice(uint96 newPrice, uint256 collateralSeed) public {
        int256 newPriceInt = int256(uint256(newPrice));
        if (newPriceInt <= 0) {
            return;
        }
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(engine.getPriceFeed(address(collateral)));
        priceFeed.updateAnswer(newPriceInt);
        timesUpdatePriceCalled++;
    }

    //////////////////////////
    // Helper functions     //
    //////////////////////////

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
