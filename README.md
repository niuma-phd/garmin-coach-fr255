# Coach Face — 佳明 FR255 健身教练表盘 + 客制化工具包

一套**开源**的 Garmin Forerunner 255 客制化方案：一个把健康/教练数据展示在手腕上的
**Connect IQ 表盘**，外加一个用云端账号**把结构化训练推到表上**的脚本工具包。
为 MIP 屏（260×260 / 64 色）量身设计，**USB 侧载即用，不依赖商店、与区服无关**。

> 设备：Forerunner 255（`fr255`，普通版 46mm）· 平台：Connect IQ 4 / System 7 / API 5.2 · 许可：MIT

---

## 这是什么

```
┌─ 表盘 Coach Face (watchface/) ──────── Monkey C，USB 侧载 ─┐
│  Layer 1  时间/日期 + 局部刷新走秒                          │
│  Layer 2  步数进度环 · 心率 · Body Battery · 压力 · 电量   │  ← Garmin 原生、实时
│  Layer 3  STRK 连胜 · SF 戒烟天数 · dKG 距目标体重         │  ← 后台每5min拉你的服务器
└────────────────────────────────────────────────────────────┘
┌─ 客制化工具包 (coach-tools/) ───────── Python，云端 API ──┐
│  push_workout.py  把 Zone2 心率目标跑步推成结构化训练 → 表 │
└────────────────────────────────────────────────────────────┘
```

**两条路要分清**：表盘走 **USB 侧载**；训练计划走**云端 API**。
云端账号**装不了**表盘，表盘也碰不到云端——它们互补，不互相替代。

---

## 目录结构

```
.
├─ watchface/              # Connect IQ 表盘（Monkey C）
│  ├─ manifest.xml         # 目标 fr255，type=watchface，权限 Communications+Background
│  ├─ monkey.jungle
│  ├─ source/              # CoachFaceApp / CoachFaceView / CoachBackground
│  └─ resources/           # strings / drawables / settings(properties)
├─ coach-tools/            # 云端侧脚本（Python）
│  └─ push_workout.py      # 推结构化训练到表
├─ docs/
│  ├─ sideload-guide.md    # ★ 怎么编译 + 侧载 + 国行注意事项
│  └─ design.md            # ★ 表盘设计与平台约束
├─ build.sh                # 一键：装SDK → 下设备 → 编出 .prg
├─ .github/workflows/      # CI：用 secrets 在云端编 .prg
└─ LICENSE                 # MIT
```

---

## 快速开始

```bash
# 1) 一次性登录：仅用于下载 fr255 设备 profile（SDK 工具是公开直下、零账号的）。
#    走国际区 Garmin 账号，与国行消费账号不通用；密码只进你的终端，用 ! 前缀自己跑：
!  connect-iq-sdk-manager login

# 2) 一键编译（自动直下公开 SDK + 下 fr255 profile + 用签名密钥编译）
./build.sh                       # 产物：build/CoachFace.prg

# 3) 侧载：插 USB → 拷 CoachFace.prg 到表的 GARMIN/Apps/ → 弹出 → 重启
#    表上：长按 UP → 表盘 → Coach Face → Apply
```

详见 **[docs/sideload-guide.md](docs/sideload-guide.md)**。

### 接上你自己的教练服务器（可选）
表盘的 Layer 3 默认显示 `--`。给它喂数据：把 `watchface/resources/settings/properties.xml`
里的 `CoachApiUrl` 改成你的 JSON 端点（如 `https://api.example.top/coach/face.json`），重编侧载。
端点返回（字段都可选）：

```json
{ "streak": 12, "smokeFreeDays": 8, "toGoalKg": -9.2, "deficitKcal": 380 }
```

后台服务每 ≥5 分钟拉一次，**需要手机在蓝牙范围内**；拉不到就优雅降级为 `--`。

---

## 佳明 FR255 还能客制化什么（菜单）

本仓库目前做了**表盘**和**训练推送**两块；同样的工具链还能做下面这些，欢迎 PR：

| 方向 | 类型 | 怎么做 |
|---|---|---|
| 自定义数据字段（跑步时的目标配速/区间） | CIQ Data Field | 写 Monkey C，侧载（单屏最多 2 个 CIQ 数据字段） |
| 一眼速览 streak/缺口 | CIQ Glance | 写 Monkey C，侧载 |
| 腕上一键打卡（想抽烟/喝水/起身→POST 回服务器） | CIQ Widget/App | 写 Monkey C，侧载 |
| 结构化训练 / 写体重 | 云端 API | `coach-tools/`（`upload_workout` / `add_weigh_in`） |
| 运动档案 / 数据页 / 提醒 / Move Alert | 表上内置设置 | 零代码，表上直接调 |

云端 API 边界：✅ 训练（增/传/排期/删）、✅ 读全部健康数据、✅ 写体重；❌ 建训练计划（只读）、
❌ 传可导航课程、❌ 任何 CIQ/表盘相关。

---

## 诚实的注意事项

- **国行侧载属"按机理确认"**：USB 侧载与区服无关（绕开了云/商店），但缺一篇国行实测公开记录——
  **第一次自己拿编好的 `.prg` 坐实一遍**。
- **签名密钥别进仓库**：`*.der`/`*.pem` 已被 `.gitignore` 挡掉；每个 fork 者自己生成、自己保管。
- **云端 token 在"借来的时间"上**：`garth`/`garminconnect` 自 2026-03 起新登录被 Cloudflare 挡、
  国行 SSO 还硬编码 `.com`。脚本能用全靠你手里没过期的 token——**备份它、别反复重登**。
- **64 色 MIP 美学**：纯色块、高对比、无渐变/照片；128 KB 表盘内存是硬墙，别塞大位图/整套字体。
- **中文显示**：FR 系列英文固件不带中文字形，本表盘标签用 ASCII（`STRK`/`SF`/`HR`…）；要中文得自己
  subset 一个极小 CJK 字体（会吃内存，谨慎）。

---

## 参考的开源项目（均 MIT/Apache，避开 GPL 传染）

- [ahuggel/SwissRailwayClock](https://github.com/ahuggel/SwissRailwayClock)（MIT）— 学习样板：局部刷新走秒、表内设置、明确支持 FR255
- [fevieira27/MoveToBeActive](https://github.com/fevieira27/MoveToBeActive)（MIT）— 富数据 + 健康指标，含 FR255
- [aguilarguisado/JSONFace](https://github.com/aguilarguisado/JSONFace)（MIT）— 小而干净，含 FR255
- [garmin/connectiq-apps](https://github.com/garmin/connectiq-apps)（Apache-2.0）— 官方样例
- [bombsimon/awesome-garmin](https://github.com/bombsimon/awesome-garmin) · [Likenttt/...samples-brief-explanations](https://github.com/Likenttt/garmin-connectiq-samples-brief-explanations)（中文注解）

---

## 致谢 / 许可
MIT。表盘与佳明（Garmin）无任何官方关系；`coach-tools` 依赖**非官方逆向** API，仅供个人学习自用。
