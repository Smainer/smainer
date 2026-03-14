const fs = require('fs');
const file = 'frontend/src/components/wallet/connect-button.tsx';
let content = fs.readFileSync(file, 'utf8');

if (!content.includes("getChainConfig")) {
  content = content.replace("import { useToast } from '@/components/ui/toast';", "import { useToast } from '@/components/ui/toast';\nimport { getChainConfig } from '@/lib/contracts';");
}

const isConnectedStr = "export function ConnectButton() {\n  const { address, isConnected";
if (content.includes(isConnectedStr)) {
  content = content.replace(isConnectedStr, "export function ConnectButton() {\n  const { address, isConnected, chainId");
}

const checkNetworkStr = `  if (isConnected && address) {
    return (
      <div className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-1.5">`;

const expectedChainIdStr = `const { chainId: expectedChainStr } = getChainConfig();
    const expectedChainId = expectedChainStr === 'SN_MAIN' ? BigInt('0x534e5f4d41494e') : BigInt('0x534e5f5345504f4c4941');
    const isWrongNetwork = chainId && chainId !== expectedChainId;

    if (isWrongNetwork) {
      return (
        <div className="flex items-center gap-2 rounded-lg border border-destructive bg-destructive/10 px-3 py-1.5">
          <span className="text-xs text-destructive font-bold">Wrong Network</span>
          <button onClick={handleDisconnect} className="p-1 rounded hover:bg-destructive/20 transition-colors" aria-label="Disconnect wallet">
            <LogOut className="h-3 w-3 text-destructive" />
          </button>
        </div>
      );
    }
`;

if (content.includes(checkNetworkStr) && !content.includes("isWrongNetwork")) {
  content = content.replace(
    `  if (isConnected && address) {
    return (`,
    `  if (isConnected && address) {
    ${expectedChainIdStr}
    return (`
  );
}

fs.writeFileSync(file, content);
