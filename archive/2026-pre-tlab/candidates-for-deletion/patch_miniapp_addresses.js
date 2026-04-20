const fs = require('fs');
const file = 'telegram/miniapp/src/lib/starknet.ts';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(/\|\| '0x01'/g, "|| '0x0'");
content = content.replace(/\|\| '0x02'/g, "|| '0x0'");
content = content.replace(/\|\| '0x03'/g, "|| '0x0'");
content = content.replace(/\|\| '0x04'/g, "|| '0x0'");
content = content.replace(/\|\| '0x05'/g, "|| '0x0'");

fs.writeFileSync(file, content);
