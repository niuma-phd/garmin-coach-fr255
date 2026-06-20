# Coach Face — 设计文档

## 概述

**Coach Face** 是一个开源表盘应用，为 Garmin Forerunner 255 (FR255) 设计。结合 Garmin 原生的运动数据（步数环、心率、Body Battery、压力）与自定义的教练层（连续天数、无烟天数、体重目标进度），在显示面积有限的 Memory-In-Pixel (MIP) 屏幕上实现数据密集但可读的设计。

**目标设备**：
- Forerunner 255 (fr255): 260×260 px, 64 色 MIP
- 连接IQ 4 / 系统 7 / API Level 5.2
- 代码+数据内存：128 KB（可选后台进程额外 64 KB）

---

## 硬件与平台约束

### 显示技术：Memory-In-Pixel (MIP)

FR255 采用 **transflective MIP**，而非 AMOLED：
- **分辨率**：260×260 px（FR255S "小屏"版本为 218×218）
- **色深**：64 色（定性指南：8 种基础色 × 8 种亮度；无光滑渐变或照片）
- **刷新特性**：常显屏（无熄灭），最后一帧低功耗绘制后保持显示
- **功耗模式**：
  - 高功耗（用户抬腕后 ~10 秒）：`onUpdate()` 每秒调用一次
  - 低功耗（之后）：`onUpdate()` 每分钟一次，`onPartialUpdate()` 每秒一次

### 内存预算

| 资源 | 限制 | 用途 |
|------|------|------|
| 代码+数据 | 128 KB | 主要应用 |
| 后台进程 | 64 KB | 可选 HTTP 请求服务 |

**设计原则**：
- 使用系统字体（`FONT_SYSTEM_*`），不自定义或内嵌字体
- 位图必须调色板索引，避免全色
- 避免大型资源文件或动态内存分配

### 时间更新模型

表盘在以下场景下触发绘制：

1. **用户抬腕**（高功耗，~10 秒）
   - `onUpdate()` 每秒调用 → 整屏重绘
   - 显示秒数及所有实时数据

2. **低功耗模式**（之后）
   - `onUpdate()` 每分钟调用一次（整屏，时间/日期变化）
   - `onPartialUpdate()` 每秒调用一次（秒数，必须用 `setClip()` 限制小矩形）
   - 如果 `onPartialUpdate()` 超出功耗预算，系统调用 `onPowerBudgetExceeded()` 并跳过该帧

**关键实现**：`drawSeconds()` 方法在 `usePartial=true` 时设置 32×20 px 裁剪框，防止功耗超限。

---

## 视觉设计：三层结构

### 第一层：时间与日期（始终存在）

| 元素 | 位置 | 样式 | 数据源 |
|------|------|------|--------|
| 时间 (HH:MM) | 屏幕中心 (_cx, _cy - 6) | 白色、粗体、中等字号 | `System.getClockTime()` |
| 日期 (周几 MM 日) | 时间上方 (_cx, _cy - 46) | 浅灰色、极小字号 | `Gregorian.info()` |
| 秒数 (SS) | 时间下方 (_cx, _cy + 30) | 强调色、极小字号、32×20 px 裁剪框 | `System.getClockTime().sec` |

### 第二层：Garmin 原生数据（内置传感器）

#### 步数环
- **位置**：屏幕边缘（半径 = _w/2 - 6）
- **样式**：8 px 笔宽，从 12 点钟方向顺时针
  - 背景轨道：深灰色
  - 进度：强调色（可配置，默认绿色）
- **数据**：当前步数 / 步数目标
- **计算**：`pct = min(steps / stepGoal, 1.0)`，角度 = `90° - 360° × pct`

#### 顶部电池百分比
- **位置**：屏幕顶部中央 (_cx, 18)
- **样式**：极小字号
  - ≤ 10%：红色
  - ≤ 25%：橙色
  - > 25%：绿色
- **数据**：`System.getSystemStats().battery`

#### 侧边瓷贴（3 块）

| 标签 | 位置 | 颜色 | 数据源 | 格式 |
|------|------|------|--------|------|
| HR（心率） | 左 (_cx - 70, _cy - 4) | 红色 | `Activity.getActivityInfo().currentHeartRate` 或 `ActivityMonitor.getHeartRateHistory()` | `%d` |
| BB（Body Battery） | 右上 (_cx + 70, _cy - 22) | 蓝色 | `Toybox.SensorHistory.getBodyBatteryHistory()` | `%d` |
| ST（压力评分） | 右下 (_cx + 70, _cy + 14) | 黄色 | `Toybox.SensorHistory.getStressHistory()` | `%d` |

心率、Body Battery 和压力评分在数据不可用时显示 "--"。

### 第三层：教练层（底部，后台可选）

三个等宽单元格，高度在屏幕底部 (_h - 30)：

| 标签 | 含义 | 位置 | 颜色 | JSON 键 | 格式 |
|------|------|------|------|--------|------|
| STRK | 连续天数 | 左 (_cx - 74, y) | 强调色 | `streak` | `%d` |
| SF | 无烟天数 | 中 (_cx, y) | 绿色 | `smokeFreeDays` | `%d` |
| dKG | 目标体重差 (kg) | 右 (_cx + 74, y) | 橙色 | `toGoalKg` | `%.1f` |

**后台 JSON 预期格式**：
```json
{
  "streak": 12,
  "smokeFreeDays": 8,
  "toGoalKg": -9.2,
  "deficitKcal": 380
}
```

键都是可选的；缺失或后台不可用时显示 "--"。

---

## 架构

### 应用入口：`CoachFaceApp.mc`

- **扩展**：`Application.AppBase`
- **主要方法**：
  - `getInitialView()` → 返回 `CoachFaceView` 实例
  - `getServiceDelegate()` → 返回 `CoachBackground` 后台服务
  - `onBackgroundData(data)` → 接收后台 JSON，存储到 `Application.Storage.setValue("coach", data)`，触发 `WatchUi.requestUpdate()`
  - `onSettingsChanged()` → 用户改变配置时重新注册后台定时器并请求更新
  - `registerBackground()` → 每 5 分钟（最小间隔）注册一次后台定时事件；如果未设置 CoachApiUrl 则禁用

### 表盘视图：`CoachFaceView.mc`

- **扩展**：`WatchUi.WatchFace`
- **核心绘制方法**：
  - `onUpdate(dc)` → 清屏、绘制所有图层、若高功耗则绘制秒数
  - `onPartialUpdate(dc)` → 仅绘制秒数（使用 32×20 px 裁剪框）
  - `onEnterSleep()` / `onExitSleep()` → 切换 `_isAwake` 标志，触发完整更新

- **数据读取器**：
  - `readStepGoal(am)` → 从 ActivityMonitor 或属性 "StepGoal"（默认 8000）
  - `readHeartRate()` → 尝试 `Activity.getActivityInfo()` 再试 `ActivityMonitor.getHeartRateHistory()`
  - `readSensorLatest(:which)` → 通过 `Toybox.SensorHistory` 获取最新 Body Battery / 压力样本（需要系统 5+）
  - `readAccent()` → 从属性 "AccentColor"（默认绿色）

- **坐标计算**：`_cx, _cy` 从 `dc.getWidth() / dc.getHeight()` 动态计算，支持不同屏幕尺寸

### 后台服务：`CoachBackground.mc`

- **扩展**：`System.ServiceDelegate`
- **方法**：
  - `onTemporalEvent()` → 每 5 分钟被调用一次
    1. 检查属性 "CoachApiUrl"；如果为空则 `Background.exit(null)`
    2. `Communications.makeWebRequest(url, {}, {...}, method(:onReceive))` → GET 请求
    3. 头部设置 `Accept: application/json`，响应类型为 JSON
  - `onReceive(responseCode, data)` → 处理响应
    - 若 `responseCode == 200 && data != null`，调用 `Background.exit(data)` 将 JSON 回传给主应用
    - 否则 `Background.exit(null)`（失败降级）

**网络前提**：手机必须在 BLE 范围内；如果离线或无网，请求失败，表盘保持显示最后一次成功数据或 "--"。

---

## 配置与属性

### `resources/settings/properties.xml`

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `CoachApiUrl` | string | （空） | 教练层后台服务的端点 URL；为空则禁用后台 |
| `StepGoal` | number | 8000 | 每日步数目标 |
| `TargetWeightKg` | float | 73.5 | 目标体重（kg）；当前未在表盘直接使用，预留扩展 |
| `AccentColor` | number | 4259648 (绿色) | 强调色（步数环、秒数、STRK 单元格） |

用户通过表盘配置界面或 Monkey Studio 编辑这些属性。

---

## 权限与清单

`watchface/manifest.xml` 声明：
- **类型**：watchface
- **目标设备**：fr255（及未来的 fr255m, fr255s, fr255sm）
- **API 最低版本**：3.1.0
- **权限**：
  - `Communications` → 后台 HTTP 请求
  - `Background` → 后台定时事件

---

## 为什么是表盘而不是数据字段 / Glance

Connect IQ 平台提供多种应用表面：

| 表面 | 特点 | 用途 |
|------|------|------|
| **Watch Face** | 持续显示，最高视觉优先级，支持后台服务 | Coach Face 的选择 |
| Data Field | 嵌入其他表盘或运动应用，专用于一个数据点 | 适合单一指标（如实时心率） |
| Glance | 快速滑动查看，非持续 | 适合定期检查的信息快照 |
| Widget | 专用应用 launcher 内的卡片 | 复杂交互 |
| App | 前台应用 | 完全控制，但用户需要主动打开 |

**Coach Face 选择表盘的理由**：
1. 用户希望在日常生活中持续看到自己的进度（步数、连续天数、体重进度）
2. 表盘获得最高优先级的屏幕实时更新，支持秒级精度
3. 可集成后台服务，自动轮询教练数据而无需用户干预
4. 一屏呈现多种数据类型，符合健身教练/追踪的完整体验

未来可扩展为数据字段或 Glance，但表盘是最符合核心需求的载体。

---

## 性能与内存预算

### 128 KB 硬限制的设计考量

| 资源 | 预期消耗 | 策略 |
|------|---------|------|
| 表盘代码 | ~15–20 KB | 使用系统字体、系统颜色，避免嵌入资源 |
| 后台服务代码 | ~3–5 KB | 精简，仅处理 HTTP 和 JSON 解析 |
| 字符串/常量 | ~2–3 KB | 英文标签（"STRK", "SF", "dKG", "HR"），避免冗长文本 |
| 动态数据 | ~2 KB | Dictionary 缓存 coach JSON、活动数据 |

**避免的陷阱**：
- ❌ 嵌入 PNG/JPG 位图（一张 32×32 索引图即占 1 KB）
- ❌ 加载完整 CJK 字体（汉字字体 > 500 KB）
- ❌ 运行时生成图像或复杂几何
- ❌ 全屏 onPartialUpdate（功耗超限，系统跳帧）

### 部分更新的正确用法

**秒数绘制**（低功耗模式，每秒一次）：
```monkey
function drawSeconds(dc, usePartial) {
    if (usePartial) {
        dc.setClip(x, y, bw, bh);      // 32×20 px 裁剪框
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();                      // 清空裁剪区
    }
    // 绘制秒数文本
    dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
    dc.drawText(_cx, y, Graphics.FONT_SYSTEM_XTINY, sec, Graphics.TEXT_JUSTIFY_CENTER);
    if (usePartial) {
        dc.clearClip();                  // 移除裁剪
    }
}
```

**关键点**：
- 必须 `setClip()` 限制重绘区域，否则系统触发 `onPowerBudgetExceeded()` 并跳过该帧
- 裁剪框越小，功耗越低；28×20 px 是一个安全范围

---

## 扩展到其他型号

### 当前支持

`watchface/manifest.xml` 目前仅声明 `<iq:product id="fr255"/>`。

### 扩展步骤

添加以下行到 `<iq:products>` 块：
```xml
<iq:product id="fr255m"/>   <!-- FR255 Music -->
<iq:product id="fr255s"/>   <!-- FR255 Small (218×218) -->
<iq:product id="fr255sm"/>  <!-- FR255 Small Music -->
```

### 分辨率适配

代码已支持动态屏幕尺寸：
```monkey
function onLayout(dc) {
    _w = dc.getWidth();      // 260 或 218
    _h = dc.getHeight();     // 260 或 218
    _cx = _w / 2;
    _cy = _h / 2;
}
```

所有坐标计算都基于 `_cx, _cy` 和百分比偏移（如 `_cx - 70`），自动缩放。唯一需要调整的是：
- **较小屏幕上的字号**：FR255S 的 218×218 可能需要调整某些极小字号以保持可读性
- **裁剪框大小**：秒数裁剪框可保持 32×20，但若显示不足可微调为 28×18

建议测试后再发布多型号版本。

---

## 数据可用性与降级

### 数据源可用性

| 数据 | API 最低版本 | 无法读取时 | 笔记 |
|------|-------------|----------|------|
| 时间/日期 | 1.0 | N/A（系统级） | 始终可用 |
| 步数/步数目标 | 1.0 | `ActivityMonitor.Info` 为 null | 回退默认 8000 步 |
| 心率（实时） | 3.3（Activity.getActivityInfo） | 尝试 `getHeartRateHistory` | 无法读取时显示 "--" |
| Body Battery | 5.0（SensorHistory） | `Toybox.SensorHistory` 不存在 | FR255 支持；较旧设备显示 "--" |
| 压力评分 | 5.0（SensorHistory） | 同上 | 同上 |
| 电池百分比 | 1.0 | 不太可能 | 系统级，几乎总是可用 |
| 教练数据（STRK/SF/dKG） | N/A | 后台未运行或无网 | 显示 "--"，保留最后成功数据 |

### 故障模式

1. **CoachApiUrl 未配置** → 后台服务不注册，教练层始终显示 "--"（纯 Garmin 表盘）
2. **手机不在 BLE 范围** → HTTP 请求失败，教练层显示上次缓存或 "--"
3. **API 响应非 200** → 教练层显示上次缓存或 "--"
4. **运动中尚无心率数据** → 显示 "--"
5. **设备未支持 SensorHistory** → Body Battery / 压力显示 "--"

**设计理念**：优雅降级，不崩溃。所有外部数据缺失时表盘仍正常运行，只是某些单元格变为 "--"。

---

## 中文标签与字体限制

### 当前限制

FR255 的英文固件不包含预装的汉字字形。要显示中文标签（如 "心率"、"压力"），需要：

1. **捆绑 CJK 字体子集** → 将常用汉字（10–50 个）提取为专用字体文件
   - 完整 CJK 字体：500 KB+（超过 128 KB 预算）
   - 子集字体（10 个汉字）：~30–50 KB（可行但占用预算 25–40%）

2. **权衡：英文标签 vs. 中文标签**
   - **当前**：使用英文缩写（"STRK", "SF", "dKG", "HR", "BB", "ST"）
   - **优点**：无需额外字体，内存节省
   - **缺点**：对非英文用户不友好

### 未来改进方案

如果项目目标包含 Chinese UX：

1. **最小化字体子集**：仅保留表盘上需要的汉字（如 "心", "压", "步", "电", "连")
2. **条件编译**：针对中文地区的设备构建版本
3. **配置化标签**：在 `resources/strings/strings.xml` 中定义，支持多语言

现阶段，英文标签是最实际的选择。

---

## 开发与测试清单

### 本地构建

1. **安装 Monkey Studio** 或配置 VS Code + Connect IQ SDK
2. **构建命令**：`monkeyc -o build/Coach.prg -w -r 10 -d fr255 -f monkey.jungle`
3. **侧载到设备**：通过 USB 或 Garmin Connect App

### 功能测试

- [ ] 时间/日期显示（12/24 小时制）
- [ ] 秒数更新（高功耗 1 次/秒，低功耗部分更新）
- [ ] 步数环进度（多个步数值测试，包括超过目标）
- [ ] 电池百分比颜色变化（>25%, ≤25%, ≤10%）
- [ ] 侧边瓷贴数据（HR/BB/ST 可用 & 不可用）
- [ ] 后台服务（设置 CoachApiUrl，验证 5 分钟轮询）
- [ ] 教练层显示（验证 JSON 解析和格式化）
- [ ] 配置更改（修改属性后表盘更新）
- [ ] 抬腕/睡眠转换（`onEnterSleep()` / `onExitSleep()` 正确触发）
- [ ] 不同屏幕尺寸（FR255 260×260，FR255S 218×218 的布局）

### 性能检查

- 使用 Monkey Studio 的内存/CPU 分析工具
- 确保低功耗模式的 `onPartialUpdate()` 不超功耗
- 后台服务在网络失败时不锁死 UI

---

## 许可与贡献

Coach Face 采用开源许可（待定）。贡献者请遵循标准 PR 流程：
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/xyz`)
3. 提交变更并编写测试
4. 发起 Pull Request

---

## 参考资源

- **Garmin Connect IQ 文档**：https://developer.garmin.com/connect-iq/
- **FR255 硬件规格**：https://www8.garmin.com/manuals/type_a/
- **Monkey Language 参考**：Connect IQ SDK 随附
- **示例表盘**：Garmin 官方示例库

---

*最后更新：2026-06-19 | 兼容 Connect IQ 4, System 7, API Level 5.2+*
