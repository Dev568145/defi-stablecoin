//  SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// // Have our invariant aka properties

// // What are our invariants?
// // 1. The total supply of DSC should always be less than the total value of the collateral
// // 2. The getter view functions should never revert <- evergreen invariant

// contract OpenInvariantsTest is StdInvariant, Test {
//     DeployDSC deployer;
//     DSCEngine engine;
//     DecentralizedStableCoin dsc;
//     HelperConfig config;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, engine, config) = deployer.run();
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         targetContract(address(engine));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         // Get the total value of the collateral
//         // Compare it to all debt (DSC)
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
//         uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(engine));

//         uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
//         uint256 btcValue = engine.getUsdValue(wbtc, totalBtcDeposited);

//         console.log("weth value: ", wethValue);
//         console.log("btc value: ", btcValue);
//         console.log("total supply: ", totalSupply);

//         assert(wethValue + btcValue >= totalSupply);
//     }
// }
