const fs = require('fs');
const file = 'frontend/src/hooks/use-compute-contract.ts';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(
  "address: COMPUTE_CONTRACT,",
  "address: COMPUTE_CONTRACT === '0x0' ? undefined : COMPUTE_CONTRACT,"
);

fs.writeFileSync(file, content);
