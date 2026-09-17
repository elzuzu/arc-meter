// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ArcMeter} from "../src/ArcMeter.sol";

/**
 * The contract makes claims — that cold access costs more than warm, that the published cost is
 * exactly gas times price, that the harness overhead is small enough to be worth publishing
 * separately. These tests check the claims, not merely that nothing reverts.
 */
contract ArcMeterTest is Test {
    ArcMeter internal meter;

    uint256 internal constant GAS_PRICE = 20 gwei;

    function setUp() public {
        meter = new ArcMeter();
        vm.txGasPrice(GAS_PRICE);
    }

    function _latest(bytes32 op) internal view returns (ArcMeter.Sample memory) {
        return meter.latest(op);
    }

    // ------------------------------------------------------------------ recording

    function test_MeasureAllRecordsOneSamplePerOperation() public {
        meter.measureAll();
        bytes32[] memory ops = meter.allOps();
        assertEq(ops.length, 8, "the published operation list should cover every benchmark");
        for (uint256 i = 0; i < ops.length; i++) {
            assertEq(meter.sampleCount(ops[i]), 1, "each operation records exactly one sample");
        }
    }

    function test_SamplesAreAppendOnly() public {
        meter.measureAll();
        meter.measureAll();
        assertEq(meter.sampleCount(meter.OP_KECCAK256()), 2, "a second run appends rather than replaces");
    }

    function test_ReporterAndTimestampAreRecorded() public {
        address alice = makeAddr("alice");
        vm.warp(1_700_000_000);
        vm.prank(alice);
        meter.measureAll();
        ArcMeter.Sample memory s = _latest(meter.OP_SSTORE_COLD());
        assertEq(s.reporter, alice, "the sample is attributed to whoever paid for it");
        assertEq(s.timestamp, 1_700_000_000);
        assertEq(s.gasPrice, uint128(GAS_PRICE));
    }

    function test_LatestRevertsWhenNothingHasBeenMeasured() public {
        // The operation id is resolved first: `expectRevert` applies to the very next call, and a
        // getter in the argument list would consume it and pass.
        bytes32 op = meter.OP_ECRECOVER();
        vm.expectRevert(abi.encodeWithSelector(ArcMeter.NoSamples.selector, op));
        meter.latest(op);
    }

    function test_LatestAllReturnsEveryOperationInOrder() public {
        meter.measureAll();
        (bytes32[] memory ops, ArcMeter.Sample[] memory samples) = meter.latestAll();
        assertEq(ops.length, samples.length);
        for (uint256 i = 0; i < ops.length; i++) {
            assertGt(samples[i].gasUsed, 0, "every operation produced a non-zero reading");
        }
    }

    // ---------------------------------------------------------- the claims themselves

    /// @dev The headline claim of the whole project: published cost is gas times price, exactly.
    function test_CostNativeIsExactlyGasTimesPrice() public {
        meter.measureAll();
        bytes32 op = meter.OP_SSTORE_COLD();
        ArcMeter.Sample memory s = _latest(op);
        assertEq(meter.costNative(op), uint256(s.gasUsed) * GAS_PRICE, "no rounding, no oracle, no adjustment");
    }

    /// @dev And the six-decimal view truncates exactly as the ERC-20 predeploy does.
    function test_CostErc20IsTheNativeCostDividedByScale() public {
        meter.measureAll();
        bytes32 op = meter.OP_SSTORE_COLD();
        assertEq(meter.costErc20(op), meter.costNative(op) / meter.SCALE());
        assertEq(meter.SCALE(), 1e12, "the factor between Arc's two USDC representations");
    }

    function test_ColdStorageAccessCostsMoreThanWarm() public {
        meter.measureAll();
        assertGt(
            _latest(meter.OP_SSTORE_COLD()).gasUsed,
            _latest(meter.OP_SSTORE_WARM()).gasUsed,
            "a first write to an untouched slot must be dearer than a repeat write"
        );
        assertGt(
            _latest(meter.OP_SLOAD_COLD()).gasUsed,
            _latest(meter.OP_SLOAD_WARM()).gasUsed,
            "a first read of an untouched slot must be dearer than a repeat read"
        );
    }

    /**
     * @dev The harness is published rather than subtracted, which is only defensible if it is small.
     *      If the two `gasleft()` reads ever cost more than the cheapest real operation, the
     *      readings would be mostly harness and the design would need rethinking.
     */
    function test_BaselineIsCheaperThanEveryRealOperation() public {
        meter.measureAll();
        uint64 baseline = _latest(meter.OP_BASELINE()).gasUsed;
        bytes32[] memory ops = meter.allOps();
        for (uint256 i = 1; i < ops.length; i++) {
            assertLt(baseline, _latest(ops[i]).gasUsed, "harness overhead must stay below the signal");
        }
    }

    /// @dev Each cold measurement must reach a genuinely untouched slot, run after run.
    function test_ColdCostStaysColdAcrossRuns() public {
        meter.measureAll();
        uint64 first = _latest(meter.OP_SSTORE_COLD()).gasUsed;
        meter.measureAll();
        uint64 second = _latest(meter.OP_SSTORE_COLD()).gasUsed;
        assertEq(first, second, "a counter-derived slot means the cold path never warms up");
    }

    /**
     * @dev The contract documents its ecrecover benchmark as exercising a full recovery rather than
     *      failing early. That is only true if the signature is valid, so it is checked here with
     *      the same constants the contract uses.
     */
    function test_EcrecoverBenchmarkUsesAValidSignature() public pure {
        bytes32 digest = 0x15fa4e0a41f4e0b6e3f0a8e3e5a6d0dd6b5c1b6b4e78e5f6ab0b0a1b2c3d4e5f;
        address signer = ecrecover(
            digest,
            28,
            0xef4d1418765ba1c2f40957bd2cea828aea016337671d00d9cfc95f4205454137,
            0x53a867d5723c7fda0f19a1c1ec454b31a00661e0fe8472efe6982ce3299ccc2c
        );
        assertEq(signer, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, "the benchmark signature must recover");
    }

    /// @dev `uint64` because that is the ceiling `vm.txGasPrice` accepts, and far above any real one.
    function testFuzz_CostNativeScalesWithGasPrice(uint64 price) public {
        vm.assume(price > 0);
        vm.txGasPrice(price);
        meter.measureAll();
        bytes32 op = meter.OP_KECCAK256();
        ArcMeter.Sample memory s = _latest(op);
        assertEq(meter.costNative(op), uint256(s.gasUsed) * uint256(price));
    }

    function test_ConstantsMatchArc() public view {
        assertEq(meter.NATIVE_DECIMALS(), 18, "Arc's native gas asset is 18 decimals, not 6");
        assertEq(meter.USDC_ERC20(), 0x3600000000000000000000000000000000000000);
    }
}
