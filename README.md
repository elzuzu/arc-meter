# ArcMeter

**What computation costs on Arc, in dollars, measured on chain.**

Live on Arc Mainnet at [`0x1f4e93ccc63efe4b3edf8a7dc93f57d7132ca9ba`](https://explorer.arc.io/address/0x1f4e93ccc63efe4b3edf8a7dc93f57d7132ca9ba) · [dashboard](https://elzuzu.github.io/arc-meter/)

## The one fact this is built on

Arc's gas token is USDC, carried at the EVM level with **18 decimals**. So `gasUsed * tx.gasprice`
is a dollar amount, directly. There is no price feed anywhere in that expression.

That is not true anywhere else. On a chain whose gas token floats, a contract that wants to know
what it just cost in dollars has to consult an oracle, and it inherits that oracle's update
threshold, its staleness window, and its failure modes. On Arc the unit of gas *is* the unit of
account, so a contract can price its own execution from inside the transaction that runs it,
adding no trust assumption at all.

ArcMeter is the smallest useful thing built on that observation: a permissionless, append-only
record of what specific EVM operations actually cost on Arc — measured, not copied out of a table.

## What it measures, live

| Operation | Gas on Arc | Cost |
|---|---|---|
| `baseline` (the harness itself) | 7 | 0.00000014 USDC |
| `sstore.cold` | 22,113 | 0.00044226 USDC |
| `sstore.warm` | 2,985 | 0.00005970 USDC |
| `sload.cold` | 2,115 | 0.00004230 USDC |
| `sload.warm` | 115 | 0.00000230 USDC |
| `keccak256` of one word | 48 | 0.00000096 USDC |
| `ecrecover` | 3,331 | 0.00006662 USDC |
| `staticcall` → `balanceOf` on the USDC predeploy | 10,761 | 0.00021522 USDC |

Recorded in block #21302857 at 20 gwei. Anyone can refresh any of these by calling `measureAll()`;
there is no owner, no admin, and no way to edit or delete a sample once written.

## Two design decisions worth stating

**The measurement harness is published, not subtracted.** `baseline` measures two `gasleft()` reads
with nothing between them, so a reader can subtract it themselves. A number the contract quietly
corrects is a number nobody can check.

**Cold benchmarks derive their slot from a counter**, so every run genuinely touches an untouched
slot rather than one warmed by the previous run. Storage refunds do not distort the readings:
refunds settle at the end of a transaction, while `gasleft()` deltas are observed as execution
proceeds.

## A bug worth documenting, because it invalidated the first version

The cold SLOAD benchmark reported **7 gas**. The specified cost is 2,100, and 7 is exactly what the
harness costs on its own — so the measurement was returning pure overhead. At 200 optimizer runs,
`pop(sload(slot))` has no observable effect and was removed outright. The same applied to the
keccak, ecrecover and staticcall benchmarks.

Each result is now assigned to a storage sink *after* the measurement window closes, which makes the
work mandatory without adding anything to the reading. The readings then landed on the
specification: 22,113 against a specified 22,100 for a cold SSTORE, 2,115 against 2,100 for a cold
SLOAD, 3,331 against a 3,000 precompile.

**This is why the numbers are measured rather than asserted.** A test that only checked "it does not
revert" would have passed the broken version.

## Local numbers differ from Arc numbers, and that is the point

`staticcall.balanceOf` costs 2,816 gas in a local EVM and **10,761 on Arc**, because locally there
is no code at `0x3600…0000` and on Arc the predeploy does real work. Anyone estimating Arc costs
from a local run is out by a factor of four on that operation.

## Verify it yourself

```bash
# the latest recorded round, straight from the chain
cast call 0x1f4e93ccc63efe4b3edf8a7dc93f57d7132ca9ba "latestAll()" --rpc-url https://rpc.mainnet.arc.io

# the cost of a cold SSTORE in native units (1e18 = 1 USDC)
cast call 0x1f4e93ccc63efe4b3edf8a7dc93f57d7132ca9ba \
  "costNative(bytes32)(uint256)" $(cast format-bytes32-string "sstore.cold") \
  --rpc-url https://rpc.mainnet.arc.io
```

```bash
git clone https://github.com/elzuzu/arc-meter && cd arc-meter
cd contracts && forge test        # 13 tests
node ../scripts/measure.mjs       # read the live registry
```

## Layout

- `contracts/src/ArcMeter.sol` — the contract
- `contracts/test/ArcMeter.t.sol` — 13 tests asserting the claims, not the absence of reverts
- `scripts/deploy.mjs` — dry-run by default, `--execute` to broadcast; the key is read from the
  macOS keychain at the moment of use and never written anywhere
- `scripts/measure.mjs` — run a round, or just read the last one
- `index.html` — the dashboard, reading the registry live

## License

MIT.

## Tip jar

Built by one person, with a lot of help from Claude. If this was useful to you, USDC on Arc to
**`0xd3fb4e6479749100D876584e7F5c5cC1EEAE51A5`** goes straight towards the subscription that helped write it.

No tiers, no perks, no expectations — it is just nice to receive something.
