# 深渊回响 · Abyss Echo

原创俯视角像素 Roguelike 射击游戏。全部美术由代码绘制、全部音效由 WebAudio 实时合成，无任何外部素材、无内购、无广告、可完全离线运行。

- 可玩入口：`index.html`（双击即玩，无需服务器）
- 移动端：Capacitor 包装，云端 GitHub Actions 构建 APK
- 包名 `com.abyssecho.game`，最低 Android 6.0（API 23）

## 玩法

**核心循环**：选角 → 进地牢 → 清房间 → 开门 → 打 Boss → 结算 → 用金币在局外解锁永久成长 → 再来一局。

- **5 层主题地牢**（苔石地牢 / 熔火矿区 / 霜封回廊 / 血肉温室 / 星陨深渊）+ 1 个隐藏层
- 每层 12–16 个房间，包含普通、精英、宝箱、商店、事件、Boss 六类
- 每层 Boss 拥有多阶段与独立招式组；集齐 3 枚回响碎片可进入隐藏层挑战隐藏 Boss
- 房间清空后开门，Boss 房清空后出现传送门，隐藏层需击败守卫才会开启回响之门

### 操作

| 平台 | 移动 | 瞄准/射击 | 技能 | 其他 |
| --- | --- | --- | --- | --- |
| 触屏 | 左半屏浮动摇杆 | 右半屏拖动即瞄准并自动开火 | 右下技能球 | 点击武器槽切枪 |
| 键鼠 | WASD | 鼠标瞄准 + 左键 | Space | Q 切枪 / 1·2 换槽 / Esc·P 暂停 / M 静音 |

### 内容量

- 13 个角色：各自独立被动、主动技能与专属初始武器，冷却 8–15 秒，定位分输出/控场/生存/召唤/爆发
- 59 把武器：覆盖 single / spread / auto / pierce / bounce / laser / charge / explosive / homing / melee / summon / chain / boomerang / flame / rail 共 15 个弹道族
- 30 种敌人：chase / ranged / charger / stationary / suicide / burrow / dash / fly / spawner / stalker / teleport / orbit / mirror / support / juggernaut / splitter 共 16 个 AI 族
- 8 种精英词缀：狂暴 / 吸血 / 分裂 / 护盾 / 加速 / 反弹 / 召唤 / 毒性
- 7 个 Boss：每层一个 + 1 个隐藏 Boss，26 种招式原语
- 40 件遗物：可叠加、可联动（tag 体系），形成构筑
- 12 个局外永久成长节点：金币消费，含前置依赖
- 5 类随机事件房

## 美术

全部为**程序化像素美术**，没有任何图片文件：

- **像素渲染层**：世界先绘制到 480×270 的低分辨率画布，再以 `imageSmoothingEnabled = false` 最近邻放大到屏幕，像素格严格对齐整数坐标
- **地砖**：哈希驱动的错缝砖（两行交错、逐砖色差、砖缝、裂纹、苔痕），每层独立配色
- **墙体**：错缝砖纹 + 顶部受光边 + 墙脚投影；门洞分"未清房栅栏"与"清房后呼吸发光"两种状态
- **角色**：四向朝向（正面双眼 / 背面后脑 / 侧面单眼）+ 两帧走路 + 披风反向飘动 + 沿瞄准方向的武器
- **敌人**：按 shape 分为 blob / wisp / beast / 方块护甲 四类像素剪影，带描边、眼睛、精英角标与血条贴片
- **HUD**：3×5 点阵数字字体（`pxNum`），血量/能量/护盾条带图标、刻度与像素倒角；小地图为锐角方框
- **界面**：标题页、角色选择、局外成长、图鉴、商店、天赋三选一、结算页统一使用黑描边 + 双色边框 + 顶部色带的像素卡片语言
- **字体**：数字与英文符号使用内置 3×5 点阵；中文使用系统字体 + 黑色投影，保持块状观感

## 音效

全部由 WebAudio 程序化合成，无音频文件：

- 振荡器（square/saw/sine/triangle）+ 白噪声缓冲 + 双二阶滤波器组合出射击、命中、暴击、拾取、开门、技能、受击、Boss 吼叫等音色
- 经过 `DynamicsCompressor` 压缩，避免同屏多音叠加爆音
- 同名音效有最小间隔节流；支持静音开关（`save.sound`），设置写入 localStorage

## 性能

- 固定 60Hz 步进逻辑（单帧最多 4 步）+ hitstop 冻帧
- 同屏硬上限：敌人 26 / 玩家子弹 200 / 敌方子弹 220 / 粒子 320 / 飘字 40
- 敌人分离检测只处理 320px 内配对
- 低分辨率渲染使填充率降到原来的约 1/7
- 实测（1280×760 视口，普通房 3–4 敌 + 弹幕）：60 FPS

## 目录

```
index.html                 # 单文件游戏（全部逻辑、渲染、音效）
docs/spec.md               # 玩法规格与全部数值表
docs/shots/                # 各界面截图
docs/BUILD-MOBILE.md       # 双端构建与安装说明
mobile/                    # Capacitor 工程与 Android/iOS 原生覆盖层
.github/workflows/         # 云端构建（Android APK + iOS 未签名 ipa）
```

## 存档

`localStorage['abyss_echo_save_v1']` 保存金币、局外节点等级、威胁等级、最佳层数、通关次数、音效设置。旧版 `upgrades` 字段会自动迁移。

## 构建

见 `docs/BUILD-MOBILE.md`。Android 走 GitHub Actions 的 `ubuntu-latest`，iOS 走 `macos-latest` 产出未签名 ipa，二者均由 `workflow_dispatch` 手动触发。
