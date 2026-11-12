// 在 `npx cap add android` 之后执行：铺设原生配置覆盖层 + 图标资源 + 最小 SDK 版本。
// 用法: node tools/apply-android.js
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const AND = path.join(ROOT, 'android');
if (!fs.existsSync(AND)) {
  console.error('[apply-android] 缺少 android/ 目录，请先执行 npx cap add android');
  process.exit(1);
}

function copyDir(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const e of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, e.name);
    const d = path.join(dst, e.name);
    if (e.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

// 1. 原生覆盖层（Manifest / MainActivity / 主题 / 自适应图标）
const overlay = path.join(ROOT, 'android-overlay');
if (fs.existsSync(overlay)) {
  copyDir(overlay, AND);
  console.log('[apply-android] 已铺设 android-overlay');
}

// 2. 预渲染图标（避免 CI 里依赖图像处理工具）
const resAndroid = path.join(ROOT, 'resources', 'android');
if (fs.existsSync(resAndroid)) {
  copyDir(resAndroid, path.join(AND, 'app', 'src', 'main', 'res'));
  console.log('[apply-android] 已铺设图标与启动图');
}

// 3. 最低 SDK -> 23 (Android 6.0)
const vars = path.join(AND, 'variables.gradle');
if (fs.existsSync(vars)) {
  let v = fs.readFileSync(vars, 'utf8');
  const before = v;
  v = v.replace(/minSdkVersion\s*=\s*\d+/, 'minSdkVersion = 23');
  if (v !== before) fs.writeFileSync(vars, v);
  console.log('[apply-android] minSdkVersion = 23');
}

// 3.1 版本号与 iOS 对齐：1.0.0 (versionCode 1)
const gradle = path.join(AND, 'app', 'build.gradle');
if (fs.existsSync(gradle)) {
  let g = fs.readFileSync(gradle, 'utf8');
  const before = g;
  g = g.replace(/versionCode\s+\d+/, 'versionCode 1');
  g = g.replace(/versionName\s+"[^"]*"/, 'versionName "1.0.0"');
  if (g !== before) fs.writeFileSync(gradle, g);
  const m = g.match(/versionCode\s+\d+[\s\S]{0,40}versionName\s+"[^"]*"/);
  console.log('[apply-android] ' + (m ? m[0].replace(/\s+/g, ' ') : 'version patch applied'));
}

// 4. 校验关键文件确实存在
const must = [
  'app/src/main/AndroidManifest.xml',
  'app/src/main/java/com/abyssecho/game/MainActivity.java',
  'app/src/main/res/values/styles.xml',
  'app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
  'app/src/main/res/drawable/splash.png'
];
let ok = true;
for (const f of must) {
  const p = path.join(AND, f);
  const exists = fs.existsSync(p);
  console.log(`[apply-android] ${exists ? 'OK  ' : 'MISS'} ${f}`);
  if (!exists) ok = false;
}
if (!ok) process.exit(2);
console.log('[apply-android] 完成');
