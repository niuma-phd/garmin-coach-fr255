# Coach Face & Checkin — 佳明 FR255 教练表盘 + 腕上打卡 App

一套**开源**的 Garmin Forerunner 255 客制化方案,三件套互补:

- **教练表盘 `watchface/`**(Coach Face)— 极简「禅意」中文表盘,主角是一个超大的绿色**坚持天数**;
- **打卡 App `watchapp/`**(Coach Checkin)— 腕上一键打卡:忍住 / 撑一下 / 抽了 / 喝水,离线排队、联网回传;
- **客制化工具包 `coach-tools/`** — 用云端账号把结构化训练(Zone-2 心率跑)推到表上。

为 MIP 屏(260×260 / 64 色 / 常显)量身设计,**USB 侧载即用,不依赖商店、与区服无关**。

> 设备:Forerunner 255 家族(`fr255` / `fr255m` / `fr255s` / `fr255sm`,默认在普通版 `fr255` 上构建测试)
> 平台:Connect IQ 4 / System 7(manifest `minApiLevel 3.1.0`) · 语言:简体中文 + English · 许可:MIT

---

## 这是什么

```
┌─ 表盘 Coach Face (watchface/) ──────────── Monkey C · USB 侧载 ─┐
│  rim 步数环 + 6 点钟久坐楔形    ← Garmin 原生、实时、离线           │
│  顶部时间(数字,无标签)                                            │
│  「坚持」 128 「天」           ← 主角:超大绿色天数(后台每 5min 拉) │
│  ♥ 62   ⚡ 78   ▮ 84%         ← 心率 / Body Battery / 电量          │
│                                  (图标用代码画,不依赖字体,永不方块)│
│  6月20日 周五                  ← 中文日期页脚                       │
└────────────────────────────────────────────────────────────────┘
┌─ 打卡 App Coach Checkin (watchapp/) ─────── Monkey C · USB 侧载 ─┐
│  主菜单「教练」: 忍住 · 撑一下 · 抽了 · 喝水                        │
│  · 撑一下 → 90 秒倒计时挺过烟瘾   · 久坐交给手表原生 Move Alert(见下)│
│  · 全部事件离线入队 → 联网时按 Bearer 幂等回传到你的 ingest 后端    │
└────────────────────────────────────────────────────────────────┘
┌─ 客制化工具包 (coach-tools/) ───────────────── Python · 云端 API ─┐
│  push_workout.py  把 Zone-2 心率目标跑步推成结构化训练 → 表        │
└────────────────────────────────────────────────────────────────┘
```

**三条路要分清**:表盘和 App 都走 **USB 侧载**(离线、零账号);训练计划走**云端 API**。
云端账号**装不了**表盘/App,表盘/App 也碰不到云端——它们互补,不互相替代。

---

## 目录结构

```
.
├─ watchface/                       # 教练表盘(type=watchface,app id 764b137b…)
│  ├─ manifest.xml                  # 目标 fr255 家族;权限 Communications + Background + SensorHistory;语言 eng+zhs
│  ├─ monkey.jungle                 # sourcePath = source;source-secret
│  ├─ source/
│  │  ├─ CoachFaceApp.mc            # AppBase:注册后台、收后台数据存 Storage
│  │  ├─ CoachFaceView.mc           # 禅意中文布局 + 代码画的图标
│  │  └─ CoachBackground.mc         # 后台每 5min GET 教练 JSON
│  └─ resources/                    # strings(教练表盘) / drawables / settings(properties)
├─ watchapp/                        # 打卡 App(type=watch-app,app id a9f48c4e…)
│  ├─ manifest.xml                  # 权限 Communications + Background + UserProfile;语言 eng+zhs
│  ├─ source/
│  │  ├─ CoachCheckinApp.mc         # AppBase:入口落主菜单 / 注册后台
│  │  ├─ Menus.mc                   # 主菜单(忍住/撑一下/抽了/喝水)+ 确认框 + Toast
│  │  ├─ Countdown.mc               # 90 秒烟瘾倒计时
│  │  ├─ CoachService.mc            # 后台:仅离线队列补传(睡眠模式跳过)
│  │  └─ CoachNet.mc                # 离线事件队列 + 幂等批量回传
│  ├─ resources/                    # strings(教练打卡) / drawables
│  └─ source-secret/Secret.mc.example  # token 模板(真 Secret.mc 由构建注入、gitignored)
├─ coach-tools/                     # 云端侧脚本(Python)
│  └─ push_workout.py               # 推结构化训练到表
├─ docs/
│  ├─ sideload-guide.md             # ★ 编译 + 侧载 + 国行注意事项
│  └─ design.md                     # 平台/MIP 约束(注:部分内容描述旧英文布局,待更新)
├─ build.sh                         # 一键编表盘 → build/CoachFace.prg
├─ build-app.sh                     # 一键编打卡 App → build/CoachCheckin.prg
├─ .github/workflows/build.yml      # CI:有 secrets 才编译,否则优雅跳过
└─ LICENSE                          # MIT
```

---

## 表盘 Coach Face

**禅意 / 极简、中文优先**。一块小圆屏上只让一个数字称王:连续**坚持天数**(默认=戒烟天数)。

| 区域 | 内容 | 说明 |
|---|---|---|
| 边缘 | 步数进度环 + 久坐楔形 | 绿色环从 12 点顺时针走 `步数/目标`;6 点钟橙/红楔形随 move bar 等级增长 |
| 顶部 | 时间数字 | 无标签,12/24 小时跟随系统 |
| 中央 | 「坚持」+ 超大数字 + 「天」 | 数字用 `NUMBER_HOT` 绿色;无数据时显示 **「同步中」+ `--`**(不显示破碎大字) |
| 下部 | ♥ 心率 · ⚡ Body Battery · ▮ 电量% | **图标全部用 dc 代码绘制**(心形/闪电/电池),不依赖字体 → 任何语言都不会变方块;数值用数字字体 |
| 页脚 | `M月D日 周X` | 确定性构造,不依赖 locale;教练数据超 36h 未刷新会加「旧」橙色标记 |

**主显切换**:`HeroMetric` 属性 `0` = 戒烟天数(默认,绿)、`1` = 距目标体重(显示「减重 N 公斤」,橙,取 `toGoalKg`)。

**属性(`resources/settings/properties.xml`,侧载时即默认值)**:

| 属性 | 类型 | 默认 | 用途 |
|---|---|---|---|
| `CoachApiUrl` | string | (空) | 教练数据 JSON 端点;空则当作纯原生表盘(不发后台请求) |
| `StepGoal` | number | 8000 | 步数环目标(ActivityMonitor 有目标时优先用系统的) |
| `TargetWeightKg` | float | 73.5 | 目标体重(配合体重数据计算 `toGoalKg`) |
| `HeroMetric` | number | 0 | 中央主显:0=戒烟天数 / 1=距目标体重 |
| `AccentColor` | number | 4259648(绿) | 强调色(环 / 主数字) |

### 教练数据怎么来

后台服务(`CoachBackground`)每 **5 分钟** `GET` 一次 JSON,**只带 `Accept: application/json` 头、不带 Authorization**——鉴权放在 URL 查询串里(见下)。拿到就存进 `Storage["coach"]` 并重绘;拉不到就保留上次值/降级为「同步中」。**需要手机在蓝牙范围内**(请求经手机 GCM 中继发出)。

表盘读取的字段(都可选,**值必须是 JSON number**):

```json
{ "smokeFreeDays": 8, "toGoalKg": -9.2 }
```

> 当前布局只用 `smokeFreeDays`(主显 0)或 `toGoalKg`(主显 1);其余健康指标(心率/BB/电量/步数/日期)全部走 Garmin 原生、离线可用。

### 侧载表盘没有手机设置页 → URL 编译期烧录

USB 侧载的表盘/App 在佳明手机里**没有设置界面**,所以 `CoachApiUrl` 无法在手机上填。解决办法:`build.sh` 在编译时把完整 URL(含**只读** summary token)写进一个 **gitignored 的 `watchface/source-secret/Secret.mc`**(`Secret.FACE_URL`)。运行时 `coachUrl()` 的优先级:**用户设过的 `CoachApiUrl` 属性 > 编译期烧录的 `Secret.FACE_URL` > 空(纯原生表盘)**。token 永不进仓库。

---

## 打卡 App Coach Checkin

一个交互式 CIQ **设备 App**(非表盘),腕上即点即记。主菜单标题「教练」:

| 菜单项 | 副标题 | 行为 | 回传事件 |
|---|---|---|---|
| 忍住 | 扛过去了 | 立即记一次「忍住」+ Toast「已记录」 | `{action:smoke, value:resisted}` |
| 撑一下 | 倒计时 | 进入 **90 秒倒计时**挺过烟瘾;到 0 = 胜利震动 | 进入即乐观记 `resisted`(放弃也保留,不发取消) |
| 抽了 | 记一支 | 确认框「记一支？」→ 是 | `{action:smoke, value:smoked}` |
| 喝水 | 加一杯 | 记一杯 +1 + Toast | `{action:checkin, item:water, value:1}` |

### 设计原则:能从手表数据分析到的,不在 App 里重复做

主菜单只保留**手表自己分析不出来**的打卡——抽烟(忍住/撑一下/抽了)和喝水。起床、晨跑、久坐这类**手表原生就有数据**的,一律不做手动打卡项,改由后端从 Garmin Connect 的睡眠 / 活动 / move-bar 数据推导,避免让用户在表上再点一遍。

**久坐为什么不在 App 里做(2+1)**:CIQ 后台**拿不到震动权限**(`Toybox.Attention` 在 Background 不可用,调用会抛 `Module 'Toybox.Attention' not available to 'Background'`),表盘 / 数据字段也不会全天跑自定义计时——所以「久坐到点自动震一下」**手表 App 实现不了**。久坐拆成两条:

- **+1 手表原生 Move Alert(实时那一下)**:静止满 1 小时震动提醒,走动 1–2 分钟清除。开启:长按 **UP → Notifications & Alerts → System Alerts → Health & Wellness → Move Alert → On**;白天别开勿扰(**DND 会压掉震动**)。
- **2 后端读数据(复盘补刀)**:后端读 Connect 同步上来的 move-bar / 久坐数据,发现久坐过久就推一条**回顾式**提醒(「你刚才坐了 X 分钟,起来动动吧」)。受 Connect 同步延迟影响、非实时,定位为补刀 + 日终汇总,不追求秒级。

> **Move Alert 间隔不可改**:那 1 小时触发是固件写死的——手表本机、Garmin Connect App、Connect IQ API 三处**都只有开/关**,没有任何修改间隔的官方途径(`ActivityMonitor.Info.moveBarLevel` 只读、全 API 面无 setter,Garmin 官方:「There isn't a way to modify the move alert with Connect IQ」)。想要自定义间隔只能走上面「后端读数据」那条。

**离线优先 + 幂等回传**(`CoachNet`):每个事件带 `event_id`(设备盐 + 持久自增计数,跨重启不撞)、`ts_local`(ISO-8601 带 UTC 偏移)、`tz_offset_min`、`device_id`、`value`,入队(上限 60,超了丢最旧)。联网时 `POST {events:[…]}` 到 `Secret.COACH_URL`,头带 `Authorization: Bearer <Secret.COACH_TOKEN>`。后端按三桶应答 `{applied, duplicates, rejected}`——**任一桶命中即从队列删除**(幂等、重发安全);`-104`(离线)/`401`/超时/`5xx` 则保留重发。后台 `CoachService` 现在**只做离线队列补传**(每 ~5 分钟一次,**睡眠模式下跳过、不出网**),10 分钟内不重复 POST——不再做任何久坐唤醒(见上「设计原则」)。token 同样**编译期注入** gitignored 的 `watchapp/source-secret/Secret.mc`,源码树只放 `Secret.mc.example` 占位。

---

## 客制化工具包 coach-tools

表盘/App 走 USB,云端 API 碰不到它们;但同一个佳明账号可以脚本化**把结构化训练推上表**。

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r coach-tools/requirements.txt

python coach-tools/push_workout.py --dry-run                         # 只打印训练 JSON,不上传
python coach-tools/push_workout.py --cn --zone2-low 136 --zone2-high 150   # 推一个 10/30/5 分钟 Zone-2 跑(国行加 --cn)
python coach-tools/push_workout.py --cn --schedule 2026-06-22        # 上传并排期
```

依赖一份**已保存的佳明 token**(`garmin_tokens.json`,自己在能输密码+MFA 的机器上生成一次,用 `--tokens` 指过去);本仓库不替你登录。详见 [coach-tools/README.md](coach-tools/README.md)。

---

## 构建

```bash
# 一次性:仅为下载 fr255 设备 profile 登录一次(SDK 工具是公开直下、零账号的)
#         走国际区 Garmin 账号,密码只进你的终端 —— 在 Claude Code 里用 ! 前缀自己跑:
!  connect-iq-sdk-manager login

./build.sh        # → build/CoachFace.prg     (表盘)
./build-app.sh    # → build/CoachCheckin.prg  (打卡 App)
```

- **只有「下那份 fr255 设备 profile」需要一次 Garmin 登录**,SDK 工具和侧载全程零账号。
- 默认编 `fr255`;其它型号设 `GARMIN_DEVICE=fr255s ./build.sh`。
- **签名密钥**:每个 app 用你自己的 RSA-4096 私钥签名(默认 `~/.garmin_dev/developer_key.der`,**永不进 git**,fork 者自行生成)。
- **密钥注入**:`build.sh` 从 `$COACH_FACE_URL` 或 `$COACH_PROJECT_DIR`(默认 `~/减肥机制`)的配置合成表盘 URL;`build-app.sh` 从 `$COACH_INGEST_TOKEN` 或 `~/减肥机制/config/secrets.toml [ingest].token` 取回传 token。两个 `source-secret/Secret.mc` 都 gitignored。

**CI**(`.github/workflows/build.yml`):监听 `watchface/**`、`watchapp/**` 改动。配齐三个仓库 secret(`GARMIN_USERNAME` / `GARMIN_PASSWORD` / `SIGNING_KEY_B64`)就在云端编 `CoachFace.prg` 并上传产物;**没配 secret 则优雅跳过、不报红**(本项目主要靠本地 `build.sh` 出包)。

---

## 侧载到表上

1. USB 连接 FR255(挂载为 U 盘),把 `build/CoachFace.prg` 和/或 `build/CoachCheckin.prg` 拷进表根目录 `GARMIN/Apps/`(**只拷 `.prg`**)。
2. **安全弹出 → 拔线 → 重启手表**(刷缓存)。
3. 表盘:长按 **UP → 表盘 → Coach Face → START → 应用**。
4. App:在**活动与应用 / App 列表**里打开「教练打卡」。

> 拷进去后 `.prg`「消失」是正常的(固件搬进隐藏内部存储);卸载用电脑版 **Garmin Express**。完整步骤与国行注意事项见 **[docs/sideload-guide.md](docs/sideload-guide.md)**。

---

## 中文显示说明

FR255 在**简体中文系统语言**下加载内置的 Noto Sans SC 字形,**内联 UTF-8 中文字面量可以正常渲染**(已在真机上确认:坚持/天/日期/菜单都显中文,非方块)。两个 manifest 都声明了 `zhs`。要点:

- 若把表的系统语言切成英文,所有中文会变成方块 □(数字、图标、环不受影响)。
- 表盘的指标**用代码画的图标**(心形/闪电/电池)而非中文标签——既省小圆屏空间(一个汉字宽约等于字高,比 "HR" 宽 2–3 倍),又**与语言/字体无关、永不方块**。中文只花在最值得的地方:主显标签和日期。

---

## 诚实的注意事项

- **国行侧载**:USB 侧载与区服无关(绕开云/商店),机理成立且已真机验证表盘渲染;首次仍建议自己拿编好的 `.prg` 坐实一遍。
- **签名密钥别进仓库**:`*.der`/`*.pem` 已被 `.gitignore` 挡掉;丢了密钥就无法再更新同一个 app,**备份它**。
- **云端 token 在「借来的时间」上**:`garth`/`garminconnect` 自 ~2026-03 起新登录被 Cloudflare 挡(国行 SSO 还硬编码 `.com`),`coach-tools` 全靠你手里没过期的 token——**备份 `garmin_tokens.json`、别反复重登**(会触发封禁)。
- **64 色 MIP 美学 + 内存墙**:纯色块、高对比、无渐变/照片;表盘约 98 KB(128 KB 预算内)、App 约 104 KB(768 KB 预算内),别塞大位图/整套字体。
- **密钥模型**:真实 token 仅在构建期注入 gitignored 的 `source-secret/Secret.mc`,**绝不进公开仓库**;`Secret.mc.example` 是占位模板。

---

## 参考的开源项目(均 MIT/Apache,避开 GPL 传染)

- [ahuggel/SwissRailwayClock](https://github.com/ahuggel/SwissRailwayClock)(MIT)— 局部刷新、表内设置、明确支持 FR255
- [fevieira27/MoveToBeActive](https://github.com/fevieira27/MoveToBeActive)(MIT)— 富数据 + 健康指标(图标化),含 FR255
- [aguilarguisado/JSONFace](https://github.com/aguilarguisado/JSONFace)(MIT)— 小而干净,含 FR255
- [garmin/connectiq-apps](https://github.com/garmin/connectiq-apps)(Apache-2.0)— 官方样例
- [bombsimon/awesome-garmin](https://github.com/bombsimon/awesome-garmin) · [Likenttt 的中文注解样例](https://github.com/Likenttt/garmin-connectiq-samples-brief-explanations)

> 排除:Crystal / warmsound 等 **GPLv3** 项目(copyleft 传染),不作参考底座。

---

## 许可 / 致谢

MIT。本项目与佳明(Garmin)无任何官方关系;`coach-tools` 依赖**非官方逆向** API,仅供个人学习自用。
