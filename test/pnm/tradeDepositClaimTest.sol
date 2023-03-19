// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "../../lib/forge-std/src/Test.sol";
import "../../lib/forge-std/src/console.sol";
import "../../contracts/rate/ChainlinkAdapter.sol";
import "../../contracts/payoff/DigitalPayoffPool.sol";
import "../../contracts/TradePool.sol";
import "../../contracts/utils/ERC20Mock.sol";
import "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import "@pwnednomore/contracts/invariants/DepositWithdrawalFailureTest.sol";

contract TradeDepositClaimTest is DepositWithdrawalFailureTest {
    address payable[] internal users;
    address internal chainlinkAggregator;
    address internal alice = address(uint160(uint256(keccak256(abi.encodePacked("alice")))));
    address internal bob = address(uint160(uint256(keccak256(abi.encodePacked("bob")))));

    ERC20Mock internal mockToken;
    AggregatorV3Interface internal mockChainlinkAggregator;
    ChainlinkAdapter internal chainlinkAdapter;
    DigitalPayoffPool internal payoffPool;
    TradePool public tradePool;

    uint88 depositEnd;
    uint88 settleStart;
    uint128 longRequiredAmount;
    uint128 shortRequiredAmount;
    uint256 payoffID;

    function deploy() public override {
        // create mock erc20 token
        mockToken =
            new ERC20Mock("VyperUSD", "vUSD", address(uint160(uint256(keccak256(abi.encodePacked("god"))))), 1000);

        // creating chainlink adapter over a chainlink mock aggregator
        chainlinkAdapter = new ChainlinkAdapter();
        mockChainlinkAggregator = new MockV3Aggregator(18, 1000);
        chainlinkAdapter.insertOracle(address(mockChainlinkAggregator));

        // creating digital payoff
        payoffPool = new DigitalPayoffPool();
        payoffPool.createDigitalPayoff(1000, true, chainlinkAdapter, 0);

        // crating TradePool
        tradePool = new TradePool();
    }

    function init() public override {
        vm.label(alice, "alice");
        vm.label(bob, "bob");

        depositEnd = uint88(block.timestamp) + 1000;
        settleStart = uint88(block.timestamp) + 2000;

        longRequiredAmount = 10;
        shortRequiredAmount = 100;

        // mint tokens to alice and bob
        deal(address(mockToken), alice, longRequiredAmount);
        deal(address(mockToken), bob, shortRequiredAmount);

        payoffID = 0;
        tradePool.createTrade(
            mockToken, payoffPool, payoffID, depositEnd, settleStart, longRequiredAmount, shortRequiredAmount
        );
        deposit();
    }

    function deposit() public override {
        vm.startPrank(alice);
        mockToken.approve(address(tradePool), longRequiredAmount);
        tradePool.deposit(0, TradePool.Sides.LONG);
        vm.stopPrank();

        vm.startPrank(bob);
        mockToken.approve(address(tradePool), shortRequiredAmount);
        tradePool.deposit(0, TradePool.Sides.SHORT);
        vm.stopPrank();
    }

    function withdraw() public override {}
    function invariantDepositWithdrawalFailure() public override {}

    function invariantDepositClaimFailure() public {
        uint256 aliceBalanceBefore = mockToken.balanceOf(alice);
        uint256 bobBalanceBefore = mockToken.balanceOf(bob);

        vm.warp(settleStart + 1);

        tradePool.settle(0);

        vm.prank(alice);
        tradePool.claim(0, TradePool.Sides.LONG);
        vm.prank(bob);
        tradePool.claim(0, TradePool.Sides.SHORT);
        (
            address _longUser,
            bool _longClaimed,
            bool _longWithdrawn,
            address _shortUser,
            bool _shortClaimed,
            bool _shortWithdrawn,
            uint256 _longPnl,
            uint256 _shortPnl
        ) = tradePool.settleData(0);

        uint256 aliceBalanceAfter = mockToken.balanceOf(alice);
        uint256 bobBalanceAfter = mockToken.balanceOf(bob);
        require(aliceBalanceBefore <= aliceBalanceAfter, "balance should increase after claim");
        require((aliceBalanceAfter - aliceBalanceBefore) + (bobBalanceAfter - bobBalanceBefore) == _longPnl + _shortPnl, 
                    "Profit and losses should be balance between long and short side");
    }
}