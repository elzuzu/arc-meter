// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title ArcMeter
 * @notice A permissionless on-chain record of what EVM operations actually cost on Arc, in dollars.
 *
 * @dev Arc's gas token is USDC, carried at the EVM level with 18 decimals. `gasUsed * tx.gasprice`
 *      is therefore a dollar amount directly — there is no price feed anywhere in that expression.
 *
 *      That is the whole premise, and it is worth stating precisely because it is not true anywhere
 *      else. On a chain whose gas token is volatile, a contract that wants to know what it just
 *      cost in dollars has to consult an oracle, and it inherits that oracle's update threshold,
 *      its staleness window, and its failure modes. On Arc the unit of gas *is* the unit of
 *      account, so a contract can price its own execution from inside the transaction that runs it,
 *      with no trust assumption added.
 *
 *      ArcMeter measures a fixed set of operations with `gasleft()` deltas and writes the result to
 *      chain. Anyone may refresh any sample at any time; there is no owner, no admin, and no way to
 *      delete or edit a recorded sample.
 */
contract ArcMeter {
    /// @notice Arc's USDC ERC-20 predeploy. Used as the target of the external-call benchmark.
    address public constant USDC_ERC20 = 0x3600000000000000000000000000000000000000;

    /// @notice Decimals of the native gas asset at the EVM level. Eighteen, not six.
    uint8 public constant NATIVE_DECIMALS = 18;

    /// @notice Factor between the native representation and the ERC-20 predeploy's six decimals.
    uint256 public constant SCALE = 1e12;

    bytes32 public constant OP_BASELINE = "baseline";
    bytes32 public constant OP_SSTORE_COLD = "sstore.cold";
    bytes32 public constant OP_SSTORE_WARM = "sstore.warm";
    bytes32 public constant OP_SLOAD_COLD = "sload.cold";
    bytes32 public constant OP_SLOAD_WARM = "sload.warm";
    bytes32 public constant OP_KECCAK256 = "keccak256.32b";
    bytes32 public constant OP_ECRECOVER = "ecrecover";
    bytes32 public constant OP_STATICCALL_ERC20 = "staticcall.balanceOf";

    /**
     * @notice One measurement.
     * @dev Packed into two slots. `gasUsed` is the raw `gasleft()` delta, including the harness
     *      around the operation — see `OP_BASELINE`, which measures that harness alone so a reader
     *      can subtract it. Nothing here is adjusted or smoothed before being written.
     */
    struct Sample {
        uint64 timestamp;
        uint64 gasUsed;
        uint128 gasPrice;
        address reporter;
    }

    /// @dev Every sample ever recorded, per operation. Append-only.
    mapping(bytes32 op => Sample[]) private _samples;

    /// @dev Bumped before each cold measurement so the derived slot is genuinely untouched.
    uint256 private _nonce;

    /// @dev Warmed on purpose by the warm benchmarks. Its value carries no meaning.
    uint256 private _warmSlot = 1;

    event Measured(bytes32 indexed op, uint256 gasUsed, uint256 gasPrice, uint256 costNative, address indexed reporter);

    error UnknownOp(bytes32 op);
    error NoSamples(bytes32 op);
    error SampleOutOfRange(uint256 gasUsed, uint256 gasPrice);

    // --------------------------------------------------------------------------- measurement

    /**
     * @notice Run every benchmark once and record all of them.
     * @dev Ordinary transaction, callable by anyone. The samples are attributed to `msg.sender`
     *      purely so a reader can tell independent measurements apart; it grants nothing.
     */
    function measureAll() external {
        _record(OP_BASELINE, _measureBaseline());
        _record(OP_SSTORE_COLD, _measureSstoreCold());
        _record(OP_SSTORE_WARM, _measureSstoreWarm());
        _record(OP_SLOAD_COLD, _measureSloadCold());
        _record(OP_SLOAD_WARM, _measureSloadWarm());
        _record(OP_KECCAK256, _measureKeccak());
        _record(OP_ECRECOVER, _measureEcrecover());
        _record(OP_STATICCALL_ERC20, _measureStaticcall());
    }

    /**
     * @dev The harness alone: two `gasleft()` reads with nothing between them. Published as its own
     *      operation rather than silently subtracted, because a number the contract quietly
     *      "corrects" is a number a reader cannot check.
     */
    function _measureBaseline() private view returns (uint256 used) {
        uint256 start = gasleft();
        used = start - gasleft();
    }

    function _measureSstoreCold() private returns (uint256 used) {
        uint256 slot = uint256(keccak256(abi.encode(++_nonce, OP_SSTORE_COLD)));
        uint256 start = gasleft();
        assembly {
            sstore(slot, 1)
        }
        used = start - gasleft();
    }

    /// @dev `_warmSlot` is already non-zero and already touched, so this is the warm path.
    function _measureSstoreWarm() private returns (uint256 used) {
        uint256 warm = _warmSlot;
        uint256 start = gasleft();
        _warmSlot = warm + 1;
        used = start - gasleft();
    }

    function _measureSloadCold() private returns (uint256 used) {
        uint256 slot = uint256(keccak256(abi.encode(++_nonce, OP_SLOAD_COLD)));
        uint256 start = gasleft();
        assembly {
            pop(sload(slot))
        }
        used = start - gasleft();
    }

    function _measureSloadWarm() private view returns (uint256 used) {
        uint256 warmed = _warmSlot;
        uint256 start = gasleft();
        warmed = _warmSlot;
        used = start - gasleft();
        warmed;
    }

    function _measureKeccak() private view returns (uint256 used) {
        uint256 seed = _nonce;
        assembly {
            mstore(0x00, seed)
            let start := gas()
            pop(keccak256(0x00, 0x20))
            used := sub(start, gas())
        }
    }

    /**
     * @dev A fixed, valid secp256k1 signature so the precompile does the full recovery rather than
     *      failing early. The message and key are arbitrary and public; nothing is secret here.
     */
    function _measureEcrecover() private view returns (uint256 used) {
        bytes32 digest = 0x15fa4e0a41f4e0b6e3f0a8e3e5a6d0dd6b5c1b6b4e78e5f6ab0b0a1b2c3d4e5f;
        uint8 v = 28;
        bytes32 r = 0xef4d1418765ba1c2f40957bd2cea828aea016337671d00d9cfc95f4205454137;
        bytes32 s = 0x53a867d5723c7fda0f19a1c1ec454b31a00661e0fe8472efe6982ce3299ccc2c;
        uint256 start = gasleft();
        ecrecover(digest, v, r, s);
        used = start - gasleft();
    }

    /// @dev External staticcall to the USDC predeploy. Measures a real cross-contract read on Arc.
    function _measureStaticcall() private view returns (uint256 used) {
        address token = USDC_ERC20;
        address who = address(this);
        uint256 start = gasleft();
        (bool ok,) = token.staticcall(abi.encodeWithSignature("balanceOf(address)", who));
        used = start - gasleft();
        ok;
    }

    /**
     * @dev The two narrowing casts are checked rather than assumed. A sample is packed to keep a
     *      long history cheap, and the ranges are far above anything Arc can produce — a block gas
     *      limit of 30,000,000 against a `uint64`, and a gas price that has moved between 20 and
     *      225 gwei against a `uint128`. Checking them anyway costs a comparison and removes the
     *      one way this contract could ever record a number that is quietly wrong.
     */
    function _record(bytes32 op, uint256 used) private {
        if (used > type(uint64).max || tx.gasprice > type(uint128).max) {
            revert SampleOutOfRange(used, tx.gasprice);
        }
        Sample memory sample = Sample({
            // Safe until year 584942417355; the EVM has no wider timestamp to offer.
            timestamp: uint64(block.timestamp),
            // Checked by the `SampleOutOfRange` guard above; the lint does not follow that flow.
            // forge-lint: disable-next-line(unsafe-typecast)
            gasUsed: uint64(used),
            // forge-lint: disable-next-line(unsafe-typecast)
            gasPrice: uint128(tx.gasprice),
            reporter: msg.sender
        });
        _samples[op].push(sample);
        emit Measured(op, used, tx.gasprice, used * tx.gasprice, msg.sender);
    }

    // -------------------------------------------------------------------------------- views

    /// @notice Every operation this contract measures, in a stable order.
    function allOps() public pure returns (bytes32[] memory ops) {
        ops = new bytes32[](8);
        ops[0] = OP_BASELINE;
        ops[1] = OP_SSTORE_COLD;
        ops[2] = OP_SSTORE_WARM;
        ops[3] = OP_SLOAD_COLD;
        ops[4] = OP_SLOAD_WARM;
        ops[5] = OP_KECCAK256;
        ops[6] = OP_ECRECOVER;
        ops[7] = OP_STATICCALL_ERC20;
    }

    function sampleCount(bytes32 op) external view returns (uint256) {
        return _samples[op].length;
    }

    function latest(bytes32 op) public view returns (Sample memory) {
        uint256 n = _samples[op].length;
        if (n == 0) revert NoSamples(op);
        return _samples[op][n - 1];
    }

    function sampleAt(bytes32 op, uint256 index) external view returns (Sample memory) {
        return _samples[op][index];
    }

    /**
     * @notice Cost of the latest sample of `op`, in native units — which on Arc is dollars.
     * @dev 1e18 native units is one USDC. Divide by `SCALE` for the six-decimal representation the
     *      ERC-20 predeploy reports.
     */
    function costNative(bytes32 op) external view returns (uint256) {
        Sample memory s = latest(op);
        return uint256(s.gasUsed) * uint256(s.gasPrice);
    }

    /// @notice The same cost expressed in the predeploy's six decimals, truncated as it truncates.
    function costErc20(bytes32 op) external view returns (uint256) {
        Sample memory s = latest(op);
        return (uint256(s.gasUsed) * uint256(s.gasPrice)) / SCALE;
    }

    /// @notice Convenience read: the latest sample of every operation in `allOps()` order.
    function latestAll() external view returns (bytes32[] memory ops, Sample[] memory samples) {
        ops = allOps();
        samples = new Sample[](ops.length);
        for (uint256 i = 0; i < ops.length; i++) {
            uint256 n = _samples[ops[i]].length;
            if (n != 0) samples[i] = _samples[ops[i]][n - 1];
        }
    }
}
