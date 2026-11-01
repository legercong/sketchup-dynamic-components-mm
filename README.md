# 草图大师（SketchUp）动态组件尺寸显示毫米补丁

把 SketchUp「动态组件」面板的尺寸单位默认改成 **毫米**——包括出厂就存成厘米或英寸的老组件；尺子按钮只在 **cm <-> mm** 之间切换，英寸不再出现，并去掉每次切换弹出来的确认框。

厘米只有在"你亲手点过一次尺子"之后才会出现，并记在那个组件上；再点一次就回到毫米。

只改显示层，不动模型信息里的单位，也不改任何组件的实际尺寸。

- 适用：SketchUp 2024 / 2025 / 2026 自带的 `su_dynamiccomponents` 扩展（Windows）
- 风险：改的是扩展自带的 JS/CSS，**SketchUp 升级或重装扩展后会被覆盖**——重新跑一次安装脚本即可
- 可逆：改之前会自动备份原厂文件，一键还原

## 为什么不是改「模型信息」

动态组件面板的长度单位是独立机制，存在实体的 `dynamic_attributes` 字典里的 `_lengthunits`（嵌套字典，Ruby 的平铺 `get_attribute` 读不到）。把「窗口 > 模型信息 > 单位」改成毫米，面板照旧显示厘米/英寸；批量改属性对已存在的组件也基本无效。所以这个补丁直接改扩展的显示层入口 `comp.lengthUnits`，一次到位。

坑在于 `_lengthunits` 里存的值是**不可信的**：中国作者写的组件、SketchUp 自带库、还有旧版尺子按钮点出来的结果，很多都是 `CENTIMETERS`。如果继续照这个键显示，"默认毫米"就永远做不到。所以补丁把它当成"没人选过"处理，另外用一个只有本补丁会写的键 `_lengthunits_user` 记录你的显式选择。

## 用法

1. 完全退出 SketchUp（确认进程结束，不是只关窗口）。
2. 双击 `安装-尺寸改毫米.bat`。
3. 窗口里每个目标目录出现绿色的 `patched` 或 `already` 就算成功。
4. 打开 SketchUp，点一个动态组件，尺寸栏应该**不用点尺子就是 `mm`**。

装到 `C:\Program Files` 时脚本会自己请求管理员权限重新运行一次，点「是」即可。

## 它会改哪些文件

自动扫描 `APPDATA`、`PROGRAMDATA` 以及注册表里 SketchUp 的安装位置，把所有能找到的 `su_dynamiccomponents` 目录一并处理（Roaming 的 `Plugins` 副本和安装目录的 `ShippedExtensions` 副本都要改，因为哪份生效由 SketchUp 决定）。

| 文件 | 改动 |
| --- | --- |
| `js/components.js` | `comp.lengthUnits` 只认 `_lengthunits_user`（你用尺子点出来的选择）；没有它就返回 `MILLIMETERS`，`_lengthunits` 里存的英寸/厘米一律不再当默认值 |
| `js/manager.js` | `toggleLengthUnits` 改成 cm <-> mm，并把这次选择同时写进 `_lengthunits_user` 推给 Ruby 侧持久化；`confirmUnitsChange` 直接返回 true（不再弹框） |
| `css/manager.css` | 新增 `.units-button-millimeters` 图标类 |
| `images/units_mm.gif` | 新增毫米尺子图标（按原图标像素风格绘制） |

`_lengthunits_user` 是下划线开头的内部键，和 `_lengthunits` 一样不会出现在面板或原始属性列表里；复制组件时会跟着走，所以你在某个组件上选的厘米会一直记住。

每个目录改之前，原厂文件会复制到该目录下的 `_backup_dc_mm\`。

## 常见疑问

**已经存成毫米的组件会被改回厘米吗？** 不会。补丁后的显示规则只有一条例外：`_lengthunits_user == 'CENTIMETERS'`，而这个键只有新版尺子按钮会写。所以数据里不管是 `MILLIMETERS`、`CENTIMETERS`、`INCHES` 还是空，打开面板都是毫米。实测过五种状态（无属性 / INCHES / CENTIMETERS / MILLIMETERS / 手动点过 cm），只有最后一种显示厘米。

**万一 Ruby 侧不接受这个新键呢？** 表现是"点成厘米后重新选组件又变回毫米"——只会退回毫米这个默认方向，不会退回厘米，也不会报错。

**我想整个面板只有毫米、连厘米按钮都不留？** 说一声，把按钮改成不动作即可（一处 `toggleLengthUnits`）。

## 安全设计

- **认不出原版代码就什么都不做**。找不到预期的锚点字符串时，只打印提示，一个字节都不改、也不建备份，避免把改坏的文件当成原版。
- **不会把已改过的文件当备份**。如果目标目录此前已被改过且没有原始备份，脚本会跳过备份步骤并明确提示。
- **可以反复运行**。第二次跑只会报 `already`。
- 还原时会检查备份本身是否已被打过补丁，避免"越还原越乱"。

## 卸载 / 还原

双击 `还原-改回原版.bat`。如果 `_backup_dc_mm` 被删过，就重装动态组件扩展或重新安装 SketchUp。

## 出问题了

打印里出现 `MISSING`、`这个版本的代码结构和本机不一样`，说明你那台的扩展版本和我这里的不一致。把该目录下的 `js\components.js` 发出来（GitHub issue 或私信），我适配后再出包。

## 说明

- 本仓库只包含我自己写的补丁脚本和使用说明，不包含 Trimble/SketchUp 的任何原厂文件；`原文件备份\` 目录（本机备份，属于 Trimble 版权内容）已在 `.gitignore` 里排除，不上传。
- 图标 `units_mm.gif` 是按 SketchUp 原 `units.gif` 的像素风格自绘的 40x21 小图。
- MIT。用的时候请自己确认对扩展文件的修改不违反你所用 SketchUp 的许可条款。

## 我本机的验证

- 从原厂文件跑出来的 4 个文件，与已经在这台机器上正常使用的成品**逐字节一致**。
- 用 Node 把改好的 `comp.lengthUnits` 和 `mgr.toggleLengthUnits` 原样抽出来跑状态机：`无属性 / INCHES / CENTIMETERS / MILLIMETERS` 四种数据打开面板全是 `MILLIMETERS`，只有带 `_lengthunits_user=CENTIMETERS`（自己点过厘米）的那个显示厘米；点一次变厘米、再点回毫米，图标同步。
- 两个 JS 文件整体过 `vm.Script` 语法校验。
- 故意改动锚点模拟"陌生版本"，脚本判定 `MISSING` 并保持目录未改动。
- 跑 `还原` 后三个文件回到原厂、新增图标被删除。
