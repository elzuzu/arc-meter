#!/usr/bin/env node
/**
 * Re-derive the whole deployment from the chain, given nothing but the contract address.
 *
 * Nothing here trusts deployment.json beyond reading the address out of it: every assertion is
 * checked against Arc Mainnet. It exits non-zero on the first failure, so it is usable as a gate.
 */
import { readFile } from 'node:fs/promises';

const RPC = 'https://rpc.mainnet.arc.io';
const OPS = ['baseline', 'sstore.cold', 'sstore.warm', 'sload.cold', 'sload.warm', 'keccak256.32b', 'ecrecover', 'staticcall.balanceOf'];
// Computed with `cast sig`, never guessed: a wrong selector returns empty data, which a lenient
// reader turns into a silent zero rather than an error.
const SEL = { latest: '0x79feb107', sampleCount: '0xc23134fc', allOps: '0x34d3117a', scale: '0xeced5526' };

const toBytes32 = (s) => '0x' + [...s].map((c) => c.charCodeAt(0).toString(16).padStart(2, '0')).join('').padEnd(64, '0');

let pass = 0;
let fail = 0;
const ok = (cond, name, detail = '') => {
  if (cond) { pass++; console.log(`  ok    ${name}${detail ? '  ' + detail : ''}`); }
  else { fail++; console.log(`  FAIL  ${name}${detail ? '  ' + detail : ''}`); }
};

async function rpc(method, params) {
  const r = await fetch(RPC, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'user-agent': 'arc-meter-verify' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
  });
  const j = await r.json();
  if (j.error) throw new Error(j.error.message);
  return j.result;
}

const call = (to, data) => rpc('eth_call', [{ to, data }, 'latest']);

async function main() {
  const { contractAddress } = JSON.parse(await readFile(new URL('../deployment.json', import.meta.url), 'utf8'));
  console.log('======================================================');
  console.log(`  verifying ${contractAddress} against ${RPC}`);
  console.log('======================================================');

  ok(Number(await rpc('eth_chainId', [])) === 5042, 'chain is Arc Mainnet', '5042');

  const code = await rpc('eth_getCode', [contractAddress, 'latest']);
  ok(code && code !== '0x', 'address carries bytecode', `${code.length / 2 - 1} bytes`);

  const scale = BigInt(await call(contractAddress, SEL.scale));
  ok(scale === 10n ** 12n, 'SCALE is 1e12', 'the factor between Arc\'s two USDC representations');

  let measured = 0;
  for (const op of OPS) {
    const res = await call(contractAddress, SEL.latest + toBytes32(op).slice(2));
    if (!res || res === '0x') { ok(false, `${op} has a sample`); continue; }
    const word = (i) => BigInt('0x' + res.slice(2 + i * 64, 66 + i * 64));
    const [ts, gas, price] = [word(0), word(1), word(2)];
    const cost = gas * price;
    ok(gas > 0n && ts > 0n, `${op} has a sample`, `${gas} gas, ${Number(cost) / 1e18} USDC`);
    measured++;
  }
  ok(measured === OPS.length, 'every published operation has been measured', `${measured}/${OPS.length}`);

  // The claims the readings are supposed to demonstrate, checked against the chain.
  const gasOf = async (op) => {
    const res = await call(contractAddress, SEL.latest + toBytes32(op).slice(2));
    return BigInt('0x' + res.slice(2 + 64, 66 + 64));
  };
  const [coldS, warmS, coldL, warmL, base] = await Promise.all(
    ['sstore.cold', 'sstore.warm', 'sload.cold', 'sload.warm', 'baseline'].map(gasOf),
  );
  ok(coldS > warmS, 'cold SSTORE costs more than warm', `${coldS} > ${warmS}`);
  ok(coldL > warmL, 'cold SLOAD costs more than warm', `${coldL} > ${warmL}`);
  ok(base < warmL, 'the harness baseline stays below the cheapest real reading', `${base} < ${warmL}`);
  ok(coldS >= 22000n && coldS < 23000n, 'cold SSTORE matches the EVM specification', `${coldS} vs a specified 22,100`);
  ok(coldL >= 2100n && coldL < 2300n, 'cold SLOAD matches the EVM specification', `${coldL} vs a specified 2,100`);

  console.log('======================================================');
  console.log(fail === 0 ? `  ALL ${pass} CHECKS PASSED` : `  ${fail} CHECK(S) FAILED (${pass} passed)`);
  console.log('======================================================');
  process.exit(fail === 0 ? 0 : 1);
}

main().catch((e) => { console.error(`[x] ${e.message}`); process.exit(1); });
