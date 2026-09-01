# Classic Mines — 设计计划

## 1. 边界

| 项目 | V1 |
|---|---|
| 平台 | arm64 macOS 13+ |
| 技术 | Swift + AppKit/Core Graphics |
| 分发 | 本机 `.app` + DMG |
| 风格 | Windows XP Classic 视觉语义，资产全部自绘 |
| 隐私 | 零广告、零账号、零遥测、零互联网请求 |
| 排除 | 联网排行、云同步、主题商店、内购、复杂动画 |

## 2. 界面

| 元素 | 规格 |
|---|---|
| 棋盘 | 16×16px 基准格；1×/2×/3×整数缩放 |
| 面板 | `#C0C0C0`；白/灰/深灰三层凹凸边 |
| 计数器 | 三位自绘红色 LED，`-99…999` |
| 笑脸 | 自绘 26×26px；普通/惊讶/死亡/墨镜/按下 |
| 菜单 | Game / Help；与 macOS 菜单共享命令与状态源 |
| 外观 | 固定经典浅色；禁止非整数缩放和自由拉伸 |
| 焦点 | 自绘高对比焦点框，不改变棋盘几何 |

## 3. 规则

| 项目 | 规则 |
|---|---|
| 初级 | 9×9 / 10雷 |
| 中级 | 16×16 / 40雷 |
| 高级 | 30×16 / 99雷 |
| 自定义 | 宽9–30，高9–24，雷数1–`格数-9` |
| 布雷 | 首次有效揭格后；首格及8邻域安全 |
| 胜利 | 全部非雷格揭开 |
| 标记 | 空白 → 旗 → 问号 → 空白 |
| Marks关闭 | 空白 ↔ 旗；切换关闭时所有既有问号立即变为空白 |
| 和弦 | 已揭数字格上同时按住左右键；旗数匹配时，任一键在起点内首次释放触发一次 |
| 可复现 | `seed + 首击坐标 => 唯一棋盘` |

和弦邻域固定按 `row asc → column asc` 揭开；误旗时首个雷终止本局。

- seed固定为`UInt64`；PRNG固定为`SplitMix64`。
- 正式新局使用`SecRandomCopyBytes`生成独立seed；失败则创建失败并显示本地错误，禁止降级为时间戳或固定seed。
- seed注入仅开放给测试入口；注入seed的局永不写入最佳成绩。
- 候选格按row-major排序，排除首击3×3范围内的有效格。
- 无偏有界取样：设`bound > 0`、`threshold = (0 &- bound) % bound`（UInt64溢出运算）；重复取`x = PRNG.next()`直到`x >= threshold`，返回`x % bound`。
- partial Fisher–Yates固定为前向：对`i in 0..<mineCount`，取`j = i + bounded(candidateCount - i)`，交换`candidates[i]`与`candidates[j]`，最终取前`mineCount`格。
- 禁止`Int.random`、`shuffle()`及直接取模。
- PRNG或候选顺序变更视为seed格式变更，必须更新回归夹具。

## 4. 丝滑交互规格

目标：输入立即响应；动效只确认动作，不延迟规则结算。

| 场景 | 响应/动效 | 验收 |
|---|---|---|
| 格子按下 | `mouseDown/rightMouseDown`立即更新视觉状态并请求重绘 | 事件入口→状态提交返回：P95≤4ms、P99≤8ms；最迟下一可用刷新呈现 |
| 格子释放 | 同步结算规则；一次提交最终状态 | 普通操作P95≤4ms；最大洪泛P95≤8ms |
| 洪泛展开 | 单次模型提交；一次批量invalidation | 30×24、1雷、最大连通空区：P95≤8ms、P99≤12ms |
| 和弦预览 | 邻格同步按下；取消时同步复原 | 无残留按下态 |
| 笑脸 | 按下态即时；释放重置棋盘 | 不等待过渡完成 |
| 系统菜单 | 原生 `NSMenu` 与系统动效 | tracking期间暂停棋盘输入；关闭后下一事件正常 |
| 设置/成绩弹窗 | `beginSheet`异步展示；自绘内容淡入淡出 | 禁止`runModal()`；sheet期间按语义禁用棋盘输入 |
| 缩放 | 切换后一次性重绘 | 无非整数插值、无模糊帧 |
| 键盘焦点 | 基础高对比框0ms显示；辅助高亮80ms | 首帧可辨识；Reduced Motion下仅保留基础框 |

### 4.1 Motion Tokens

| Token | 值 | 用途 |
|---|---:|---|
| `instant` | 0ms | 棋盘规则态、旗帜、数字、胜负 |
| `pressTransition` | 0ms | 按下/释放无插值；持续至mouseUp或取消 |
| `focusAccent` | 80ms | 非必要焦点辅助高亮；基础框始终0ms |
| `popoverIn` | 120ms | 菜单/弹窗进入 |
| `popoverOut` | 90ms | 菜单/弹窗退出 |
| `easeOut` | cubic-bezier(0.2, 0.8, 0.2, 1) | 非关键过渡 |

禁止弹簧、回弹、逐格波纹、模糊、阴影动画；Reduced Motion下所有非必要动效归零。
`popoverIn/popoverOut`仅适用于应用自绘sheet内容，不覆盖`NSMenu`系统动画。

### 4.2 性能约束

- 棋盘采用单一自定义绘制视图；禁止每格独立原生控件。
- 鼠标追踪只更新受影响格；洪泛/终局使用单次批量 invalidation。
- 输入处理、布雷、洪泛均不执行磁盘I/O。
- 成绩/偏好在回合结束或设置变更后异步持久化。
- 使用冻结的50-seed语料库，覆盖角/边/中心首击及各难度。
- 普通揭开、标记、和弦、胜利结算、最大洪泛分别预热20次、采样500次；禁止合并分位数。
- 每次样本重建棋盘；seed顺序固定但轮换执行。
- 使用`os_signpost`测量事件入口→状态提交返回；不把等待vblank计入处理耗时。
- UI事件处理门禁：P95≤4ms、P99≤8ms；不使用墙钟Max作为CI门禁。
- 纯内核性能由Release benchmark harness使用`ContinuousClock`采集500个独立样本，排序计算P95/P99：最大洪泛P95≤8ms、P99≤12ms。
- XCTest调用该harness并断言分位数；`XCTClockMetric`仅保留为趋势数据。
- Core Animation Instruments验证：交互/焦点动画期间无主线程`>16.7ms`长帧。
- 无持续动画时不设FPS指标；80–120ms过渡期间，60Hz帧间隔P95≤16.7ms；高刷屏采用系统刷新节奏。

## 5. 输入

| 输入 | 行为 |
|---|---|
| 左键 | 揭格 |
| 右键 | 标记 |
| 左右键 | 和弦 |
| 方向键 | 移动焦点，不循环 |
| Space | 揭格 |
| F | 标记 |
| Enter | 和弦 |
| `⌘N` | 新游戏 |

- `F/Space/Enter/⌘N`仅处理`isARepeat == false`的首次keyDown；方向键允许重复。
- Space拦截默认滚动/按钮触发；游戏结束后除`⌘N`外动作键无效。
- F仅作用于遮盖格；Enter仅作用于已揭数字格。

### 5.1 AppKit鼠标状态机

- 覆盖`mouseDown/rightMouseDown/mouseDragged/rightMouseDragged/mouseUp/rightMouseUp`；处理后立即返回，禁止`nextEvent`阻塞追踪。
- 使用`NSEvent.pressedMouseButtons` bit 0/1维护左右键状态。
- 左键按下仅预览；同格释放才揭开；拖出取消，拖回恢复预览。
- 右键按下时标记一次；本次拖动/释放不得重复标记。
- 和弦起点必须是已揭开的数字格；两键按下顺序不限。
- 两键均按下时进入邻域预览；任一键首次释放且指针仍在起点时只触发一次。
- 触发后消费另一键释放，禁止再次执行普通揭开或标记。
- 按键仍按住时，指针离开起点仅暂时清除预览；拖回起点恢复预览。
- 任一键在起点外释放则取消该手势，不触发和弦。
- 仅窗口失去key、应用失活或按键状态失配时永久取消并清空状态。
- 禁用棋盘context menu；Control-click按系统secondary-click语义处理。
- 棋盘`acceptsFirstMouse(for:)`返回`false`：非活动窗口首次点击只激活，不执行游戏动作。
- 激活点击不计入延迟采样；窗口激活后的首个游戏事件才进入性能门禁。

## 6. 计时与成绩

- 首次成功揭格启动；插旗不启动。
- 使用 `mach_continuous_time`，后台与睡眠计入。
- 显示和成绩统一为 `floor(elapsedSeconds)`；999秒封顶。
- 每个标准难度保存一条最佳成绩；仅严格更短时替换。
- 成绩资格：标准难度 + 正式随机seed + 未启用测试模式；其余局不计榜。

## 7. 无障碍

- VoiceOver朗读：行列、遮盖/标记/数字状态、胜负公告。
- 所有功能均可键盘完成。
- Reduced Motion关闭非必要过渡，但保留即时状态反馈。

### 7.1 Accessibility模型

- 棋盘暴露为虚拟`AXGrid`；每格为稳定ID的虚拟AX Cell，不创建720个`NSView`。
- Cell标签：`第{row}行，第{column}列`；Value：`遮盖/旗帜/问号/空白/数字N/地雷/错旗`。
- 遮盖格提供`揭开`、`切换标记`动作；已揭数字格提供`和弦`动作。
- 键盘焦点、VoiceOver焦点双向同步；浏览不得隐式执行游戏动作。
- 单格变化发送valueChanged；洪泛/终局仅发送一次汇总公告。
- 胜负公告：`胜利，用时N秒` / `踩雷，游戏结束`。
- 启动读取`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`，并监听`NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`。
- Reduced Motion开启时立即结束在途非必要动画并提交最终态；系统`NSMenu`动画保持系统控制。

## 8. 数据与安装

- Bundle ID：`com.local.classicmines`
- UserDefaults：偏好、三条成绩。
- 关闭窗口结束本局；重新打开生成新局。
- DMG包含 `.app`、Applications快捷方式、最终DMG的独立 `.sha256`。
- 本机构建且无 quarantine；执行 `codesign --verify --deep --strict`。
- 完全清理：退出应用后执行 `defaults delete com.local.classicmines`。

## 9. 验收

| 类别 | 门禁 |
|---|---|
| 内核 | 布雷、邻雷数、洪泛、和弦、极限盘、胜负测试通过 |
| 性能 | 普通输入P95≤4ms；最大洪泛P95≤8ms；无主线程长帧 |
| 视觉 | 1×/2× Retina截图；像素边框与焦点框清晰 |
| 隐私 | 无AF_INET/AF_INET6出站、DNS、HTTP(S) |
| 安装 | DMG拖装、签名验证、离线启动、SHA-256校验 |
| 清理 | 删除应用和UserDefaults后偏好与成绩归零 |

- 内核增加固定seed快照、角/边安全区、候选格不重复、雷数守恒测试。
- 多seed分布检查仅作统计回归，不作为单次随机CI硬门禁。
- VoiceOver仅用键盘完成：新局→移动→标记→揭开→和弦→获胜。
- 最大洪泛只播报一次，不产生逐格公告。
- 焦点移动首帧可辨识；动画途中开启Reduced Motion后立即归零且终态正确。

## 10. 阶段

| 阶段 | 交付物 | 门禁 |
|---|---|---|
| P0 | 规则、视觉Token、状态矩阵 | 规格冻结 |
| P1 | 纯Swift游戏内核 | 单测通过 |
| P2 | 像素UI与菜单 | 截图通过 |
| P3 | 鼠标、键盘、VoiceOver | 交互与性能通过 |
| P4 | `.app`、DMG、校验文件 | 本机安装通过 |
