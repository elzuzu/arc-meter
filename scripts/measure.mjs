#!/usr/bin/env node
/**
 * Run one round of measurements against the deployed ArcMeter and print what it recorded.
 *
 * Anyone can call this; the samples are attributed to whoever paid for the transaction. Without
 * --execute it only reads back the latest round.
 */
import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { createPublicClient, createWalletClient, fallback, http, formatUnits, hexToString } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

const RPCS = ['https://rpc.mainnet.arc.io', 'https://rpc.drpc.mainnet.arc.io', 'https://rpc.quicknode.mainnet.arc.io'];
const arc = {
  id: 5042,
  name: 'Arc Mainnet',
  nativeCurrency: { name: 'USDC', symbol: 'USDC', decimals: 18 },
  rpcUrls: { default: { http: RPCS } },
};
const EXECUTE = process.argv.includes('--execute');

const label = (b32) => hexToString(b32).replace(/\0+$/, '');

async function main() {
  const [{ contractAddress }, artifact] = await Promise.all([
    readFile(new URL('../deployment.json', import.meta.url), 'utf8').then(JSON.parse),
    readFile(new URL('../contracts/out/ArcMeter.sol/ArcMeter.json', import.meta.url), 'utf8').then(JSON.parse),
  ]);
  const abi = artifact.abi;
  const publicClient = createPublicClient({ chain: arc, transport: fallback(RPCS.map((u) => http(u))) });

  if (EXECUTE) {
    const raw = execFileSync('security', ['find-generic-password', '-s', 'arc-grant-wallet', '-a', 'deploy', '-w'], {
      encoding: 'utf8',
    }).trim();
    const account = privateKeyToAccount(raw.startsWith('0x') ? raw : `0x${raw}`);
    const wallet = createWalletClient({ account, chain: arc, transport: fallback(RPCS.map((u) => http(u))) });
    const hash = await wallet.writeContract({ address: contractAddress, abi, functionName: 'measureAll' });
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`[+] measureAll ${receipt.status} in block #${receipt.blockNumber}`);
    console.log(`[+] tx ${hash}`);
    console.log(`[+] this round itself cost ${formatUnits(receipt.gasUsed * receipt.effectiveGasPrice, 18)} USDC\n`);
  }

  const [ops, samples] = await publicClient.readContract({ address: contractAddress, abi, functionName: 'latestAll' });
  console.log(`ArcMeter ${contractAddress}\n`);
  console.log('operation              gas      cost (USDC, 18 dec)   cost (6 dec)');
  for (let i = 0; i < ops.length; i++) {
    const s = samples[i];
    const native = BigInt(s.gasUsed) * BigInt(s.gasPrice);
    console.log(
      `${label(ops[i]).padEnd(22)} ${String(s.gasUsed).padStart(7)}   ${formatUnits(native, 18).padStart(18)}   ${formatUnits(native / 10n ** 12n, 6)}`,
    );
  }
}

main().catch((e) => { console.error(`[x] ${e.message}`); process.exit(1); });
