const fs = require('fs');
const file = 'telegram/miniapp/src/lib/starknet.ts';
let content = fs.readFileSync(file, 'utf8');

const chainsRegex = /export const chains: Chain\[\] = \[\s*\{[\s\S]*?\}\s*\];/;
const newChains = `import { mainnet, sepolia } from '@starknet-react/chains';

export const chains = [mainnet, sepolia];
`;

if (content.includes("export const chains: Chain[] = [") && !content.includes("import { mainnet, sepolia }")) {
   // Replace the custom chains definition with standard ones
   content = content.replace(chainsRegex, newChains);
   // Remove Chain import if unused
   content = content.replace("import { Chain } from '@starknet-react/chains';", "");
}

fs.writeFileSync(file, content);
