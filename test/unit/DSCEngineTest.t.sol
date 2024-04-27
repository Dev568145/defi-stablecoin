// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;
    address wbtcUsdPriceFeed;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10e18;
    uint256 public constant STARTING_BALANCE = 10e18;
    uint256 public constant DSC_MINTED = 100 ether;
    uint256 public constant DSC_BURNED = 100 ether;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_BALANCE);
        if (block.chainid == 31337) {
            vm.deal(USER, STARTING_BALANCE);
            vm.deal(liquidator, collateralToCover);
        }
    }

    /////////////////////////////
    // modifiers              //
    /////////////////////////////

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);
        engine.depositCollateral(weth, STARTING_BALANCE);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);
        engine.depositCollateralAndMintDsc(weth, STARTING_BALANCE, DSC_MINTED);
        vm.stopPrank();
        _;
    }

    /////////////////////////////
    // Constructor Tests       //
    /////////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenAddressLengthDoesntMatchPricefeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////////////
    // getter Tests            //
    /////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15 * 2500/ETH = 37500e18
        uint256 expected = 37500e18;
        uint256 actual = engine.getUsdValue(weth, ethAmount);
        assertEq(actual, expected);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        // 100 / 2500/ETH = 0.04 ether
        uint256 expectedWeth = 0.04 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualWeth, expectedWeth);
    }

    function testGetAccountCollateralValue() public depositedCollateral {
        uint256 expected = 25000e18;
        uint256 actual = engine.getAccountCollateralValue(USER);
        assertEq(actual, expected);
    }

    function testGetAccountInformation() public depositedCollateralAndMintDsc {
        (uint256 totalDscMinted, uint256 totalCollateralInUsd) = engine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = DSC_MINTED;
        uint256 expectedTotalCollateralInUsd = 25000e18;
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(totalCollateralInUsd, expectedTotalCollateralInUsd);
    }

    function testGetCollateralTokens() public {
        address[] memory collateralTokens = engine.getCollateralTokens();
        assertEq(collateralTokens.length, 2);
        assertEq(collateralTokens[0], weth);
        assertEq(collateralTokens[1], wbtc);
    }

    function testGetCollateralDeposited() public depositedCollateral {
        uint256 collateralDeposited = engine.getCollateralDeposited(USER, weth);
        assertEq(collateralDeposited, STARTING_BALANCE);
    }

    function testGetDscMinted() public depositedCollateralAndMintDsc {
        uint256 dscMinted = engine.getDscMinted(USER);
        assertEq(dscMinted, DSC_MINTED);
    }

    function testGetPriceFeed() public {
        address priceFeed = engine.getPriceFeed(weth);
        assertEq(priceFeed, ethUsdPriceFeed);
    }

    function testGetDscAddress() public {
        address dscAddress = engine.getDscAddress();
        assertEq(dscAddress, address(dsc));
    }

    ////////////////////////////////////////
    // depositCollateral Tests            //
    ////////////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 totalCollateralInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, totalCollateralInUsd);
        uint256 expectedTotalCollateralInUsd = 25000e18;

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(STARTING_BALANCE, expectedDepositAmount);
        assertEq(totalCollateralInUsd, expectedTotalCollateralInUsd);
    }

    function testRevertsDepositCollateralTransferFromFailed() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom failedTransferFrom = new MockFailedTransferFrom();
        tokenAddresses = [address(failedTransferFrom)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        DSCEngine mockEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedTransferFrom));
        failedTransferFrom.mint(owner, STARTING_BALANCE);

        vm.prank(owner);
        failedTransferFrom.transferOwnership(address(mockEngine));
        vm.startPrank(owner);
        ERC20Mock(address(failedTransferFrom)).approve(address(mockEngine), STARTING_BALANCE);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockEngine.depositCollateral(address(failedTransferFrom), STARTING_BALANCE);
        vm.stopPrank();
    }

    ////////////////////////////////////////
    // depositCollateralAndMintDsc Tests  //
    ////////////////////////////////////////

    function testDepositCollateralAndMintDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);
        engine.depositCollateralAndMintDsc(weth, STARTING_BALANCE, DSC_MINTED);
        vm.stopPrank();
    }

    ////////////////////////////////////////
    // redeemCollateral Tests             //
    ////////////////////////////////////////

    function testRevertsRedeemCollateralWhenHealthFactorBroken() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorIsBroken.selector, 0));
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
    }

    ////////////////////////////////////////
    // redeemCollateralForDsc Tests       //
    ////////////////////////////////////////

    function testRedeemCollateralForDsc() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(engine), DSC_BURNED);
        engine.redeemCollateralForDsc(weth, STARTING_BALANCE, DSC_BURNED);
        vm.stopPrank();
    }

    function testRevertsRedeemCollateralTransferFailed() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer failedTransfer = new MockFailedTransfer();
        tokenAddresses = [address(failedTransfer)];
        priceFeedAddresses = [ethUsdPriceFeed];

        vm.prank(owner);
        DSCEngine mockEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedTransfer));
        failedTransfer.mint(owner, STARTING_BALANCE);
        vm.prank(owner);
        failedTransfer.transferOwnership(address(mockEngine));

        vm.startPrank(owner);
        ERC20Mock(address(failedTransfer)).approve(address(mockEngine), STARTING_BALANCE);
        mockEngine.depositCollateral(address(failedTransfer), STARTING_BALANCE);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockEngine.redeemCollateral(address(failedTransfer), STARTING_BALANCE);
        vm.stopPrank();
    }

    ////////////////////////////////////////
    // mintDsc Tests                      //
    ////////////////////////////////////////

    function testRevertsIfMintDscIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsMintFailed() public {
        MockFailedMintDSC failedMintDsc = new MockFailedMintDSC();
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedMintDsc));
        failedMintDsc.transferOwnership(address(mockEngine));

        vm.startPrank(owner);
        ERC20Mock(weth).mint(owner, STARTING_BALANCE);
        ERC20Mock(weth).approve(address(mockEngine), 1000e18);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        mockEngine.depositCollateralAndMintDsc(weth, STARTING_BALANCE, DSC_MINTED);
        vm.stopPrank();
    }

    function testMintDsc() public depositedCollateral {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);
        engine.mintDsc(DSC_MINTED);
        vm.stopPrank();
    }

    ////////////////////////////////////////
    // burnDsc Tests                      //
    ////////////////////////////////////////

    function testCantBurnMoreThanBalance() public {
        vm.startPrank(USER);
        vm.expectRevert();
        engine.burnDsc(1);
    }

    function testRevertsIfBurnAmountIsZero() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.burnDsc(0);
        vm.stopPrank();
    }

    function testBurnDsc() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(engine), DSC_BURNED);
        engine.burnDsc(DSC_BURNED);
        vm.stopPrank();
    }

    ////////////////////////////////////////
    // liquidate Tests                    //
    ////////////////////////////////////////

    function testRevertsIfHealthFactorIsGood() public depositedCollateralAndMintDsc {
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), collateralToCover);
        engine.depositCollateralAndMintDsc(weth, collateralToCover, DSC_MINTED);
        dsc.approve(address(engine), DSC_MINTED);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, DSC_MINTED);
        vm.stopPrank();
    }

    function testMustImproveHealthfactorOnLiquidation() public {
        // Arrange - setup
        MockMoreDebtDSC moreDebtDsc = new MockMoreDebtDSC(ethUsdPriceFeed);
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;

        vm.prank(owner);
        DSCEngine mockEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(moreDebtDsc));
        moreDebtDsc.transferOwnership(address(mockEngine));

        // Arrange - user
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockEngine), STARTING_BALANCE);
        mockEngine.depositCollateralAndMintDsc(weth, STARTING_BALANCE, DSC_MINTED);
        vm.stopPrank();

        // Arrange - liquidator
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockEngine), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockEngine.depositCollateralAndMintDsc(weth, collateralToCover, DSC_MINTED);
        moreDebtDsc.approve(address(mockEngine), debtToCover);
        // Act
        int256 ethUsdUpdatePrice = 18e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatePrice);
        // Act / Assert
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        mockEngine.liquidate(weth, USER, debtToCover);
        vm.stopPrank();
    }

    function testLiquidate() public depositedCollateralAndMintDsc {
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), collateralToCover);
        engine.depositCollateralAndMintDsc(weth, collateralToCover, DSC_MINTED);
        dsc.approve(address(engine), DSC_MINTED);

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(18e8);
        engine.liquidate(weth, USER, DSC_MINTED);
        vm.stopPrank();
    }

    ////////////////////////////////////////
    // healthFactor Tests                 //
    ////////////////////////////////////////

    function testProperlyCalculatesHealthFactor() public depositedCollateralAndMintDsc {
        // (25000 * 0.5) / 100 = 125
        uint256 expectedHealthFactor = 125e18;
        uint256 actualHealthFactor = engine.getHealthFactor(USER);
        assertEq(expectedHealthFactor, actualHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintDsc {
        int256 ethUsdUpdatePrice = 18e8;

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatePrice);
        uint256 userHealthFactor = engine.getHealthFactor(USER);
        assert(userHealthFactor == 0.9 ether);
    }
}
