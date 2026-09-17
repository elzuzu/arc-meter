# ArcMeter — what computation costs on Arc, in dollars, measured on chain

## Why this exists

Arc's gas token is USDC with 18 decimals at the EVM level. That single fact makes
`gasUsed * tx.gasprice` a **dollar amount directly**, with no price oracle anywhere in the path.

On Ethereum, a contract that wants to know what it just cost in dollars needs an ETH/USD feed, and
inherits that feed's latency, its update threshold, and its failure modes. On Arc that whole
dependency disappears: the unit of gas *is* the unit of account. A contract can price its own
execution, exactly, from inside the transaction that runs it.

ArcMeter is the smallest useful thing built on that observation: a permissionless on-chain registry
of what specific EVM operations actually cost on Arc, measured from inside transactions rather than
copied out of the yellow paper.

## Scope

- [ ] `ArcMeter.sol` — measures a fixed set of operations with `gasleft()` deltas and records
      `(opId, gasUsed, gasPrice, timestamp, reporter)` on chain. Anyone may refresh any sample.
- [ ] Operations: cold SSTORE, warm SSTORE, cold SLOAD, warm SLOAD, `keccak256` of 32 bytes,
      `ecrecover`, and an external `staticcall` to `balanceOf` on the USDC predeploy.
- [ ] Views: `latest(opId)`, `sampleCount(opId)`, `costNative(opId)`, `allOps()`.
- [ ] Tests, including a fork test that runs the measurements against live Arc and asserts the
      recorded cost equals `gasUsed * tx.gasprice`.
- [ ] Deploy to Arc mainnet from the existing payout wallet.
- [ ] A one-page dashboard reading the registry live.
- [ ] Public repo, MIT, README stating the method and its limits honestly.

## Method, and what it does not claim

A `gasleft()` delta measures the operation **plus the measurement harness around it**. The harness
overhead is itself measured (`OP_BASELINE`, an empty measured block) and published alongside, so a
reader can subtract it. The raw numbers are recorded unadjusted — the contract does not silently
"correct" them.

Storage refunds do not distort this: refunds are applied at the end of a transaction, while
`gasleft()` deltas are observed as execution proceeds. A cold SSTORE is measured against a slot
derived from a monotonically increasing counter, so every measurement genuinely hits a zero slot
rather than an already-warm one.

Gas price on Arc moved between 20 and 225 gwei within a single session, so a single sample is a
snapshot, not a constant. That is exactly why the registry keeps a history and lets anyone add to
it.

## Distinctness from ArcPay

Different artifact, different purpose: ArcPay is a payment and escrow rail, ArcMeter is
instrumentation. They share only the underlying fact about Arc's decimals, which is a property of
the chain rather than of either project.

## Review
