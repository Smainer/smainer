const fs = require('fs');
const file = 'frontend/src/hooks/use-escrow.ts';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(
  "address: COMPUTE_CONTRACT,",
  "address: COMPUTE_CONTRACT === '0x0' ? undefined : COMPUTE_CONTRACT,"
);
// In case it's using TOKEN_CONTRACT or similar
content = content.replace(
  "address: TOKEN_CONTRACT,",
  "address: TOKEN_CONTRACT === '0x0' ? undefined : TOKEN_CONTRACT,"
);

fs.writeFileSync(file, content);
