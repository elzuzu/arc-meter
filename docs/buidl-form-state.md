# What was actually entered in the DoraHacks forms

Recorded because a DoraHacks draft lives only in the open browser tab until it is submitted, and
because a field filled from memory is a field nobody can check afterwards.

**BUIDL id `48824`** — <https://dorahacks.io/buidl/48824>. Submitted to Arc Microgrants on
2026-09-17 and shown as under review. This is the second distinct project from the same builder;
ArcPay is BUIDL 48819 and was not touched.

## Step 1 — Profile

| Field | Value |
|---|---|
| Name | `ArcMeter` |
| Vision (one-line pitch) | `What computation costs on Arc, in dollars, measured on chain.` |
| Logo | `docs/logo.png`, 197 kB, accepted without a crop prompt |
| Category (required) | `Crypto / Web3` — the only coherent option among Crypto/Web3, Quantum Computing, Space, AI/Robotics, Other |
| GitHub | `https://github.com/elzuzu/arc-meter` |
| Project website | `https://elzuzu.github.io/arc-meter/` |
| Social link 1 | `https://github.com/elzuzu` |
| Social links 2 and 3, demo video, sub-categories, L1s/L2s/appchains | left empty |

## Step 2 — Details

The `### Description` section of [`../SUBMISSION.md`](../SUBMISSION.md), pasted as raw markdown in
the legacy editor and checked in the preview: paragraphs intact, backticks rendered as code,
`0x3600…0000` unaltered.

## Step 3 — Team information

[`team-information.txt`](team-information.txt) verbatim, 1,697 characters. "Invite new members"
left empty.

## Step 4 — Contact

Telegram `elzuzu0` entered **without the `@`** — the prefix is rendered outside the input, so
typing it produces `@@elzuzu0`. Backup contact: Discord `lextulhor`. Terms of Use accepted.

## The hackathon entry form

Reached from the hackathon page: Manage Submission → Submit new BUIDL → organiser disclaimer →
I Agree & Continue → Use existing BUIDL → ArcMeter → track `All BUIDLs` (the only option) →
"Need teammates: No".

| Question | Answer |
|---|---|
| Project name | `ArcMeter` |
| Name / alias | `elzuzu` |
| Contact email | `arc@elzuzu.ch.eu.org` |
| Public builder profiles | `https://github.com/elzuzu` |
| Live deployment | `https://elzuzu.github.io/arc-meter/` |
| Contract address | `0x1f4e93ccc63efe4b3edf8a7dc93f57d7132ca9ba` |
| Public repo | `https://github.com/elzuzu/arc-meter` |
| Deployed to Arc before this project? | **Mainnet** — the menu is Mainnet / Testnet / No, not yes/no |
| Received a Circle or Arc grant, bounty or prize? | `No` |
| What does it use Arc for? | [`arc-usage-960.txt`](arc-usage-960.txt) verbatim, 882 characters, diffed byte-for-byte before entry |
| Anything else we should see? | the `Verify it yourself` block of `SUBMISSION.md`, plus the deploy and seeding transaction hashes |

## What the form would not accept

- **No free tags.** The nearest field, "Key innovation domains", is a closed vocabulary:
  `Solidity` returns "No available options". The "Layer-1s" field does not list `Arc` either. Both
  were left empty, so the stack list in `SUBMISSION.md` went nowhere.
- **No cover image field**, in either the creation flow or "Edit BUIDL profile". `docs/cover.png`
  was produced and never used.

## Two things to know for next time

The **macOS clipboard was overwritten by another process** between copying a field value and
pasting it. Long values were typed directly into the fields afterwards and re-read on screen. Do
not trust `pbcopy` to survive a round trip during a form session.

A sub-category, "Chain Abstraction", was **selected by accident** when a click landed on a dropdown
that had stayed open. It was removed and the edit modal closed without saving; the public page
carries only `Crypto / Web3`.
