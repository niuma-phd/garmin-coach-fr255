# 把表盘装进 Forerunner 255（侧载指南 · 含国行注意事项）

本指南讲三件事：① 在 Linux 上编出 `.prg`；② USB 侧载到表上；③ 国行（中国区）有哪些坑。
所有结论都经过核实，时间点为 **2026-06**；佳明会随固件收紧 CIQ 文件处理，重大固件更新后请复测。

---

## 0. 先认清两条不同的路

| 你想做的事 | 走哪条路 | 备注 |
|---|---|---|
| 把**自编表盘**装上表 | **USB 侧载**（本指南） | 离线、不需账号、不需商店、**与区服无关** |
| 把别人商店里的表盘装上表 | Connect IQ 手机 App | 国行走 `apps.garmin.cn`，目录滞后、偶尔卡"安装已排队" |
| 用云端 API（`garminconnect`）装表盘 | ❌ **此路不通** | 云端 API 根本没有 CIQ/表盘端点。它只能推训练/读数据 |

> 一句话：**表盘只能 USB 侧载或走商店**，你那个已登录的云端 session 装不了表盘，但能推结构化训练（见 `coach-tools/`）。

---

## 1. 一次性准备：在 Linux 上装 SDK

**账号到底卡在哪（已实测核实，2026-06）：**

| 你要的东西 | 要不要 Garmin 账号 | 实证 |
|---|---|---|
| SDK 工具（`monkeyc`/`connectiq`/`monkeydo`） | ❌ **不要** | zip 在 `developer.garmin.com/.../sdks/` 公开直下（204MB，匿名 200/206） |
| **`fr255` 设备 profile**（编译这块表必需） | ✅ **要登录一次** | `api.gcs.garmin.com/ciq-product-onboarding/devices` 匿名返回 **401** |
| 把 `.prg` 装上表（USB 侧载） | ❌ **不要** | 固件级文件拷贝，离线、与区服无关 |

> 结论：**只有"下那一份 fr255 设备 profile"需要一次 Garmin 登录**，其余全程零账号。
> 这个登录走**国际区** SSO（`connect.garmin.com`），跟你 `~/减肥机制` 的国行消费账号是**两套、不通用**。
> 国行账号若登不上，去 [developer.garmin.com](https://developer.garmin.com) 免费注册一个国际账号专用（下 profile 不要审核/不要钱）。

本仓库用 [`lindell/connect-iq-sdk-manager-cli`](https://github.com/lindell/connect-iq-sdk-manager-cli)
拉那份设备 profile（已装在 `~/.local/bin/connect-iq-sdk-manager`，设备落在 `~/.Garmin/ConnectIQ/Devices/fr255/`，monkeyc 正好从这里读）。

```bash
# 1) 一次性登录（交互式，密码只进你的终端）。在 Claude Code 里用 ! 前缀自己跑：
!  connect-iq-sdk-manager login

# 2) 之后 build.sh 自动：（缓存/直下公开 SDK）→ 下 fr255 profile → 编译：
./build.sh                # 产物：build/CoachFace.prg
```

### Linux 已知坑
- **`libwebkit2gtk-4.0` 缺失**：官方 GUI SDK 管理器和**模拟器**依赖它，Ubuntu 24.04+ 不再自带。
  纯命令行 `monkeyc` 编译**基本不受影响**，受影响的是模拟器 GUI。要跑模拟器就用 pcolby 的
  AppImage / 补 Jammy 库 / Docker；只为出 `.prg` 可以不管它。
- **签名密钥**：每个 app 必须用你自己的 RSA-4096 私钥签名。本仓库已生成在
  `~/.garmin_dev/developer_key.der`（**永不进 git**，已被 `.gitignore` 挡掉）。丢了它你就再也无法
  更新已上架的同一个 app——**备份它**。别人 fork 本仓库要自己生成：
  ```bash
  openssl genrsa -out k.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in k.pem -out developer_key.der -nocrypt
  ```
- **SDK 版本下限**：近年固件要求侧载的 `.prg` 必须用 **Connect IQ SDK ≥ 7.4.3** 编译，否则报
  `signature check failed`。`build.sh` 永远下最新 SDK，自动满足。

---

## 2. USB 侧载到表上

1. 用数据线把 **FR255 插上电脑**，表会作为 **U 盘（USB 大容量存储）** 挂载。
2. 把 `build/CoachFace.prg` **拷进表根目录的 `GARMIN/Apps/` 文件夹**
   （大小写不敏感，`APPS` 也行；**只拷 `.prg`，别拷 `.zip`/别的**）。
3. **安全弹出**，拔线，**重启手表**。
4. 表上：**长按 UP → 表盘（Watch Face）→** 找到 **Coach Face → START → 应用（Apply）**。

### 必然会遇到、但属于正常的现象
- **拷进去后 `.prg` 文件"消失"了**：现代固件会把它**搬进隐藏的内部存储**，所以重新插 USB 看不到它了。
  **这是正常的、不是失败**——去表上"表盘"菜单确认即可。
- **想卸载**：因为文件被藏起来了，**删文件删不掉**；要卸载用电脑上的 **Garmin Express**
  （不是手机 App）。建议装着 Garmin Express 以备清理。
- **侧载的表盘没有商店设置页**：本表盘把可调项（服务器 URL、步数目标、目标体重、强调色）做成了
  `properties.xml` 默认值，侧载即生效；要改就改源码里的默认值再重编。

### 容易翻车的点
- **必须按你的具体型号编译**。本仓库默认目标 `fr255`（普通版 46mm，260×260）。编错型号**装不上**
  （现代固件会静默拒绝）。其它型号见 `docs/design.md` 的"扩展到其他型号"。
- **别在写入中途拔线**：务必先安全弹出、等缓存刷完再拔，否则可能损坏安装或表的文件系统。

---

## 3. 国行（中国区）专门说明

**结论：国行 FR255 能跑自编侧载表盘。** 侧载是固件/文件系统级机制，**与账号区服无关**——它绕开了
云、商店、佳速度 App。下面是据实的边界：

| 项 | 国行情况 |
|---|---|
| USB 侧载本身 | ✅ 通。机理上与区服无关；佳明的固件接受任何**用当前 SDK 正确签名、且按本机型编译**的 `.prg` |
| 需要绑国行 App 吗 | ❌ 不需要。只要一根 USB 线 |
| 商店这条路 | ⚠️ 走 `apps.garmin.cn` / 佳速度，独立且目录滞后；2025-11 后佳明关了 Web 商店、只能用手机 App |
| 卸载侧载表盘 | 用电脑 Garmin Express（国行手机 App 管不了隐藏存储里的它） |
| 你的云端 session | 已是 `is_cn=True`（`connect.garmin.cn`），与侧载完全无关，互不影响 |

> **唯一需要你亲手坐实的一点**：我没找到一篇"在国行 FR255 上实测侧载成功"的公开记录——上面的结论
> 是**按机理 + 国行 FR255 支持 Connect IQ 的官方手册**推出来的，可信但属"机理确认"。**第一次请拿一个
> 编好的 `fr255` `.prg` 实测一遍**，长按 UP → 表盘 看能不能选中应用，坐实后再大胆迭代。

---

## 4. 一页速查

```text
准备(一次):  ! connect-iq-sdk-manager login        # 国际区 Garmin 账号
编译:        ./build.sh                            # -> build/CoachFace.prg
侧载:        插USB → 拷 .prg 到 GARMIN/Apps/ → 弹出 → 重启
选用:        长按 UP → Watch Face → Coach Face → Apply
卸载:        Garmin Express (PC/Mac)
排错:        .prg"消失"=正常；装不上→多半型号编错或SDK太旧
```
