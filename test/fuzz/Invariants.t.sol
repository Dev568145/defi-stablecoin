// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    Handler handler;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        // targetContract(address(engine));
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // Get the total value of the collateral
        // Compare it to all debt (DSC)
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(engine));
        uint256 totalSupply = dsc.totalSupply();

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 btcValue = engine.getUsdValue(wbtc, totalBtcDeposited);

        console.log("weth value: ", wethValue);
        console.log("btc value: ", btcValue);
        console.log("total supply: ", totalSupply);
        console.log("times deposit called: ", handler.timesDepositCalled());
        console.log("times mint called: ", handler.timesMintCalled());
        console.log("times redeem called: ", handler.timesRedeemCalled());
        console.log("times burn dsc called: ", handler.timesBurnDscCalled());
        console.log("times transfer called: ", handler.timesTransferCalled());
        console.log("times liquidate called: ", handler.timesLiquidateCalled());
        console.log("times update price called: ", handler.timesUpdatePriceCalled());

        assert(wethValue + btcValue >= totalSupply);
    }

    function invariant_gettersFunctionShouldNotRevert() public view {
        engine.getUsdValue(weth, 1);
        engine.getUsdValue(wbtc, 1);
        engine.getTokenAmountFromUsd(weth, 1000e8);
        engine.getTokenAmountFromUsd(wbtc, 1000e8);
        engine.getHealthFactor(msg.sender);
        engine.getAccountCollateralValue(msg.sender);
        engine.getAccountInformation(msg.sender);
        engine.getCollateralTokens();
        engine.getCollateralDeposited(weth, msg.sender);
        engine.getCollateralDeposited(wbtc, msg.sender);
        engine.getDscMinted(msg.sender);
        engine.getPriceFeed(weth);
        engine.getPriceFeed(wbtc);
        engine.getDscAddress();
        engine.getMinimumHealthFactor();
        engine.getLiquidationBonus();
    }
}
