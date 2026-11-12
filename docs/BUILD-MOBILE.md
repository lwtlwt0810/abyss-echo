# 手机端打包说明（Android APK / iOS）

本工程的游戏本体是**单文件** [index.html](../index.html)，可直接双击在浏览器里玩。
手机端只是用 WebView 容器把它装成 App，**不修改任何游戏逻辑**，因此三端内容完全一致。

## 1. 统一配置（两端共用）

| 项目 | 值 |
| --- | --- |
| 应用名 | 深渊回响 |
| 包名 / Bundle ID | `com.abyssecho.game` |
| 版本 | 1.0.0 (versionCode / build 1) |
| 最低系统 | Android 6.0 (API 23) / iOS 13.0 |
| 目标 SDK | Android 34 |
| 屏幕方向 | 横屏（`sensorLandscape` / LandscapeLeft+Right） |
| 全屏 | 沉浸式，隐藏状态栏与导航栏，刘海区延伸 |
| 缩放手势 | 关闭（WebView 缩放、双指捏合、双击缩放、长按菜单全部禁用） |
| 图标 / 启动图 | `mobile/resources/`，由 `tools/make-icons.ps1` 程序化生成 |
| 网络 | 完全离线，运行时不发起任何网络请求 |

## 2. Android：云端构建（推荐，本地零安装）

工作流文件：[.github/workflows/mobile-build.yml](../.github/workflows/mobile-build.yml)

### 2.1 首次推仓库

```powershell
cd C:\Users\lwtlw\Documents\Trae-CN\temp_20261110_02
git init
git add .
git commit -m "Abyss Echo: game + mobile packaging"
git branch -M main
git remote add origin https://github.com/<你的账号>/<仓库名>.git
git push -u origin main
```

或直接用现成脚本（支持把 token 藏在环境变量里）：

```powershell
$env:GITHUB_TOKEN="ghp_xxx"
powershell -ExecutionPolicy Bypass -File scripts\push-to-github.ps1 -RepoUrl "https://github.com/<你的账号>/<仓库名>.git"
```

### 2.2 触发构建

仓库页面 → **Actions** → 左侧 **Mobile Build (Android APK / iOS unsigned ipa)** → **Run workflow**：

- `build_release`：同时产出签名 release APK（默认开）
- `build_ios`：同时产出未签名 iOS ipa（默认开）

### 2.3 取产物

构建完成后，在该次运行的 **Artifacts** 区域下载：

- `abyss-echo-debug-apk` → `app-debug.apk`（调试签名，可直接安装）
- `abyss-echo-release-apk` → `app-release.apk`（签名 release）

### 2.4 安装到手机

1. 把 apk 拷到手机（USB / 微信文件传输 / 网盘均可）
2. 系统提示"未知来源应用"，允许后安装
3. 打开后横屏即玩，首次点击屏幕会解锁音频

### 2.5 关于签名

- 未配置 Secret 时，CI 会用 `keytool` **临时生成**一个 keystore，`release` 包之间无法覆盖升级（仅用于试装）。
- 需要稳定升级时，配置两个仓库 Secret：
  - `ANDROID_KEYSTORE_BASE64`：keystore 的 base64（`base64 -w0 release.keystore`）
  - `ANDROID_KEYSTORE_PASSWORD`：keystore 密码
- keystore **不要提交进仓库**（`.gitignore` 已排除 `*.keystore / *.jks`）。

### 2.6 本地构建（可选，不推荐）

需要自行安装 Node 20、JDK 17、Android SDK（platform 34 + build-tools 34.0.0），然后：

```bash
cd mobile
npm install
npm run sync:web
npx cap add android
node tools/apply-android.js
cd android && ./gradlew assembleDebug
```

## 3. iOS

> **Windows 上无法编译 `.ipa`**：iOS 编译链只能在 macOS + Xcode 上运行。以下不假称能出包。

工程位置：[mobile/ios/AbyssEcho.xcodeproj](../mobile/ios/AbyssEcho.xcodeproj)（手写 Xcode 工程，**不依赖 CocoaPods**）

### 3.1 在 Mac 上跑起来

1. 克隆仓库，进入 `mobile/`，执行 `node tools/sync-web.js`（把 `index.html` 复制到 `ios/App/www/`）
2. 双击 `mobile/ios/AbyssEcho.xcodeproj`
3. 选中 **AbyssEcho** target → **Signing & Capabilities** → Team 选你的 Apple ID
4. 如 Bundle ID 冲突，把 `com.abyssecho.game` 改成 `com.<你的名字>.abyssecho`
5. 连上 iPhone，选真机 → Run

### 3.2 免费 Apple ID 的限制

| 限制 | 说明 |
| --- | --- |
| 有效期 7 天 | 到期后 App 打不开，需重新用 Xcode 装一次 |
| 同时在装 3 个 | 免费账号最多 3 个自签名 App |
| 每周 10 个 App ID | 频繁改 Bundle ID 会更快耗尽 |
| 无法上架 | 需要付费开发者账号（$99/年）才能 TestFlight / App Store |

### 3.3 没有 Mac 的可行路径

`mobile-build.yml` 里的 `ios` job 跑在 GitHub 的 `macos-14` runner 上，用 `CODE_SIGNING_ALLOWED=NO` 编出**未签名 ipa**：

- 作用一：证明 Xcode 工程可编译（CI 就是编译验证）
- 作用二：在 Windows 上用 **Sideloadly / AltStore** 打开该 ipa，用你的 Apple ID 重签后装到 iPhone（同样是 7 天有效期）
- 局限：未签名 ipa **不能直接安装**，也不能上架；且 CI 无法验证真机运行

### 3.4 已预置好的配置

- Bundle ID `com.abyssecho.game`、版本 1.0.0(1)、显示名「深渊回响」
- 横屏锁定、隐藏状态栏、Home 指示条自动隐藏、刘海区安全区避让
- 禁用滚动/回弹/捏合缩放/长按菜单/外链跳转
- 图标（1024 AppIcon）与启动图（LaunchLogo + LaunchBackground）已填好
- 离线：直接加载 bundle 内 `www/index.html`

## 4. 重新生成图标

```powershell
powershell -ExecutionPolicy Bypass -File mobile\tools\make-icons.ps1
```

会重写 `mobile/resources/`（含 Android 各密度图标）与 `mobile/ios/App/Assets.xcassets/`。

## 5. 回归验证

```powershell
# 需要本地 8123 端口静态服务器（tools/abyss_server 等价实现）与 Chrome
powershell -ExecutionPolicy Bypass -File mobile\tools\qa-touch.ps1
```

用 CDP 真实触摸事件 + 页面内 PointerEvent 验证：双摇杆、自动开火、60 FPS、无 JS 异常。
