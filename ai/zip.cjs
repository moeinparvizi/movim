// ZIP creation using npm's existing tar-free pure-JS zip dependency is deliberately
// avoided: use Windows tar to write a portable ZIP with Unix executable metadata.
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const source = path.resolve(process.argv[2]);
const destination = path.resolve(process.argv[3]);
execFileSync('tar', ['-a', '-cf', destination, '-C', path.dirname(source), path.basename(source)]);
const bytes = fs.readFileSync(destination);
let eocd = -1;
for (let i = bytes.length - 22; i >= Math.max(0, bytes.length - 65557); i--) {
  if (bytes.readUInt32LE(i) === 0x06054b50 && i + 22 + bytes.readUInt16LE(i + 20) === bytes.length) { eocd = i; break; }
}
if (eocd < 0) throw Error('ZIP end record missing');
let offset = bytes.readUInt32LE(eocd + 16);
for (let i = 0; i < bytes.readUInt16LE(eocd + 10); i++) {
  if (bytes.readUInt32LE(offset) !== 0x02014b50) throw Error('ZIP entry invalid');
  const length = bytes.readUInt16LE(offset + 28);
  const name = bytes.subarray(offset + 46, offset + 46 + length).toString();
  bytes[offset + 5] = 3;
  const mode = name.endsWith('/') ? 0o40755 : name.endsWith('Install.command') ? 0o100755 : 0o100644;
  bytes.writeUInt32LE((mode * 65536) >>> 0, offset + 38);
  offset += 46 + length + bytes.readUInt16LE(offset + 30) + bytes.readUInt16LE(offset + 32);
}
fs.writeFileSync(destination, bytes);
console.log('Created ' + destination);
