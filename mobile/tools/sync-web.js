// 把根目录的单文件游戏同步到 www/ 与 iOS 工程资源目录，保证三端内容完全一致。
// 用法: node tools/sync-web.js
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const src = path.resolve(__dirname, '..', '..', 'index.html');
const targets = [
  path.resolve(__dirname, '..', 'www', 'index.html'),
  path.resolve(__dirname, '..', 'ios', 'App', 'www', 'index.html')
];

if (!fs.existsSync(src)) {
  console.error('[sync-web] 找不到源文件: ' + src);
  process.exit(1);
}

const buf = fs.readFileSync(src);
const sha = crypto.createHash('sha256').update(buf).digest('hex').slice(0, 16);

for (const t of targets) {
  fs.mkdirSync(path.dirname(t), { recursive: true });
  fs.writeFileSync(t, buf);
  console.log(`[sync-web] ${path.relative(process.cwd(), t)}  ${(buf.length / 1024).toFixed(1)} KB  sha256:${sha}`);
}
