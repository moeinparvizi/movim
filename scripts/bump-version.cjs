const fs = require('node:fs');
const file = 'lua/config/version.lua';
const source = fs.readFileSync(file,'utf8');
const match = source.match(/return ['"](\d+)\.(\d+)\.(\d+)['"]/);
if (!match) throw Error('Invalid version');
const releaseMajor = 2;
const next = Number(match[1]) < releaseMajor
  ? releaseMajor + '.0.0'
  : match[1] + '.' + match[2] + '.' + (Number(match[3])+1);
fs.writeFileSync(file, source.replace(match[0], "return '" + next + "'"));
for (const file of ['site/package.json','site/package-lock.json']) {
  const data = JSON.parse(fs.readFileSync(file,'utf8')); data.version = next;
  if (data.packages && data.packages['']) data.packages[''].version = next;
  fs.writeFileSync(file, JSON.stringify(data,null,2) + '\n');
}
console.log(next);
