const fs = require('fs');
const file = 'telegram/miniapp/src/components/WalletConnect.tsx';
let content = fs.readFileSync(file, 'utf8');

const isConnectedStr = "const { address, isConnected: starknetConnected } = useAccount();";
if (content.includes(isConnectedStr)) {
  content = content.replace(isConnectedStr, "const { address, isConnected: starknetConnected, chainId } = useAccount();");
}

const checkNetworkStr = `  if (starknetConnected && address) {
    return (
      <div className="w-full max-w-md mx-auto">`;

const expectedChainIdStr = `    const expectedChainStr = import.meta.env.VITE_STARKNET_CHAIN_ID || 'SN_MAIN';
    const expectedChainId = expectedChainStr === 'SN_MAIN' ? BigInt('0x534e5f4d41494e') : BigInt('0x534e5f5345504f4c4941');
    const isWrongNetwork = chainId && chainId !== expectedChainId;

    if (isWrongNetwork) {
      return (
        <div className="w-full max-w-md mx-auto">
          <div className="bg-destructive/10 border border-destructive rounded-lg p-6">
            <div className="text-center mb-4">
              <h3 className="text-lg font-semibold text-destructive">Wrong Network</h3>
              <p className="text-sm text-destructive/80 mt-2">Please switch to {expectedChainStr === 'SN_MAIN' ? 'Mainnet' : 'Sepolia'} to continue.</p>
            </div>
            <button onClick={handleDisconnect} className="w-full px-4 py-2 bg-destructive text-destructive-foreground rounded-md hover:bg-destructive/90 transition-colors">
              Disconnect Wallet
            </button>
          </div>
        </div>
      );
    }
`;

if (content.includes(checkNetworkStr) && !content.includes("isWrongNetwork")) {
  content = content.replace(
    `  if (starknetConnected && address) {
    return (`,
    `  if (starknetConnected && address) {
${expectedChainIdStr}
    return (`
  );
}

fs.writeFileSync(file, content);
