# Arc Microgrants submission — ArcMeter

Portal: **DoraHacks** — <https://dorahacks.io/hackathon/arc-microgrants>

Deadline: **14 October 2026, 23:59 ET**. Reviews are rolling; every decision is issued by
21 October. One submission per project, but a team may submit more than one *distinct* project —
which is what this is, alongside ArcPay (BUIDL 48819).

**Two steps, not one.** Creating a BUIDL publishes a standalone project and enters no competition.
Entering Arc Microgrants is a separate step from the hackathon page: Submit BUIDL → Use existing
BUIDL → ArcMeter. The track selector is the tell that you are in the right flow.

---

## Step 1 — Profile

| Field | Value |
|---|---|
| Name | `ArcMeter` |
| One-line pitch | `What computation costs on Arc, in dollars, measured on chain.` |
| GitHub | `https://github.com/elzuzu/arc-meter` |
| Project website | `https://elzuzu.github.io/arc-meter/` |
| Social link 1 | `https://github.com/elzuzu` |
| Logo | `docs/logo.png` (480×480 — the slot centre-crops anything wider) |
| Cover | `docs/cover.png` (1200×630) |

## Step 2 — Details

### Description

Arc's gas token is USDC, carried at the EVM level with 18 decimals. That makes
`gasUsed * tx.gasprice` a dollar amount directly — there is no price feed anywhere in that
expression.

This is not true on any other chain. Where the gas token floats, a contract that wants to know what
it just cost in dollars must consult an oracle, and it inherits that oracle's update threshold, its
staleness window and its failure modes. On Arc the unit of gas *is* the unit of account, so a
contract can price its own execution from inside the transaction that runs it, adding no trust
assumption at all.

ArcMeter is the smallest useful thing built on that observation: a permissionless, append-only
registry of what specific EVM operations actually cost on Arc — measured from inside transactions,
not copied out of a table. Anyone can refresh any sample by calling `measureAll()`. There is no
owner, no admin, and no way to edit or delete a sample once written.

**Live readings** (block #21302857, 20 gwei): a cold `SSTORE` costs 22,113 gas and 0.00044226 USDC;
a cold `SLOAD` 2,115 and 0.00004230; `ecrecover` 3,331 and 0.00006662; a `staticcall` to
`balanceOf` on the USDC predeploy 10,761 and 0.00021522.

**Two design decisions.** The measurement harness is published as its own operation (`baseline`,
7 gas) rather than subtracted silently — a number the contract quietly corrects is a number nobody
can check. And cold benchmarks derive their storage slot from a counter, so every run genuinely
touches an untouched slot rather than one warmed by the previous run.

**One bug worth reporting, because it invalidated the first version.** The cold `SLOAD` benchmark
reported 7 gas. The specified cost is 2,100, and 7 is exactly what the harness costs alone — the
measurement was returning pure overhead. At 200 optimizer runs `pop(sload(slot))` has no observable
effect and was removed outright. Each result is now assigned to a storage sink after the
measurement window closes. The readings then landed on the specification: 22,113 against a
specified 22,100, 2,115 against 2,100, 3,331 against a 3,000 precompile. A test that only checked
"it does not revert" would have passed the broken version.

**Why the chain matters, not a local EVM.** `staticcall.balanceOf` costs 2,816 gas locally and
10,761 on Arc, because locally there is no code at `0x3600…0000` while on Arc the predeploy does
real work. Anyone sizing Arc costs from a local run is out by a factor of four on that operation.

### Verify it yourself

```bash
cast call 0x1f4e93ccc63efe4b3edf8a7dc93f57d7132ca9ba "latestAll()" --rpc-url https://rpc.mainnet.arc.io
git clone https://github.com/elzuzu/arc-meter && cd arc-meter/contracts && forge test   # 13 tests
node ../scripts/verify-deployment.mjs   # 17 checks, re-derived from the chain
```

### Stack / tags

`Solidity` · `Foundry` · `Arc` · `USDC` · `EVM` · `gas` · `public good` · `no dependencies`

## Step 3 — Team information

See [`docs/team-information.txt`](docs/team-information.txt).

## Step 4 — Contact

Telegram `elzuzu0` (without the `@` — the prefix is rendered outside the input).
Backup: Discord `lextulhor`. Email `arc@elzuzu.ch.eu.org`.

---

## The hackathon entry form — "What does it use Arc for?"

**Capped at 960 characters**, enforced only on submit. The answer is kept verbatim in
[`docs/arc-usage-960.txt`](docs/arc-usage-960.txt).

## Deployment facts

| | |
|---|---|
| Contract | `0x1f4e93ccc63efe4b3edf8a7dc93f57d7132ca9ba` |
| Chain | Arc Mainnet, 5042 |
| Deploy tx | `0x4d07061d226de7ea8dcfc6610a474108c8b9db9b0df6bc548580a9421bd7ffd4` |
| Block | 21302797 |
| Gas used | 950,308 (0.01900616 USDC at 20 gwei) |
| Seeding tx | `0x843c5da7b1d9dad5c1bb843738653e051ba0216cd741fe3e934398ab877caa32`, block 21302857 |
| Tests | 13/13 |
| Deployment checks | 17/17, re-derived from the chain given only the address |
