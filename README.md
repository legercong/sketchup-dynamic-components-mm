# 草图大师（SketchUp）动态组件尺寸显示毫米补丁

把 SketchUp「动态组件」面板的尺寸单位默认改成 **毫米**，尺子按钮只在 **cm <-> mm** 之间切换，英寸不再出现，并去掉每次切换弹出来的确认框。

只改显示层，不动模型信息里的单位，也不改任何组件的实际尺寸。

- 适用：SketchUp 2024 / 2025 / 2026 自带的 `su_dynamiccomponents` 扩展（Windows）
- 风险：改的是扩展自带的 JS/CSS，**SketchUp 升级或重装扩展后会被覆盖**——重新跑一次安装脚本即可
- 可逆：改之前会自动备份原厂文件，一键还原

## 为什么不是改「模型信息」

动态组件面板的长度单位是独立机制，存在实体的 `dynamic_attributes` 字典里的 `_lengthunits`（嵌套字典，Ruby 的平铺 `get_attribute` 读不到）。把「窗口 > 模型信息 > 单位」改成毫米，面板照旧显示厘米/英寸；批量改属性对已存在的组件也基本无效。所以这个补丁直接改扩展的显示层入口 `comp.lengthUnits`，一次到位。

## 用法

1. 完全退出 SketchUp（确认进程结束，不是只关窗口）。
2. 双击 `安装-尺寸改毫米.bat`。
3. 窗口里每个目标目录出现绿色的 `patched` 或 `already` 就算成功。
4. 打开 SketchUp，点一个动态组件，尺寸栏应该直接是 `mm`。

装到 `C:\Program Files` 时脚本会自己请求管理员权限重新运行一次，点「是」即可。

## 它会改哪些文件

自动扫描 `APPDATA`、`PROGRAMDATA` 以及注册表里 SketchUp 的安装位置，把所有能找到的 `su_dynamiccomponents` 目录一并处理（Roaming 的 `Plugins` 副本和安装目录的 `ShippedExtensions` 副本都要改，因为哪份生效由 SketchUp 决定）。

| 文件 | 改动 |
| --- | --- |
| `js/components.js` | `comp.lengthUnits` 默认值 `INCHES` -> `MILLIMETERS`，并把存成 `INCHES` 的老组件按毫米显示 |
| `js/manager.js` | `toggleLengthUnits` 改成 cm <-> mm；`confirmUnitsChange` 直接返回 true（不再弹框） |
| `css/manager.css` | 新增 `.units-button-millimeters` 图标类 |
| `images/units_mm.gif` | 新增毫米尺子图标（按原图标像素风格绘制） |

每个目录改之前，原厂文件会复制到该目录下的 `_backup_dc_mm\`。

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
- 故意改动锚点模拟"陌生版本"，脚本判定 `MISSING` 并保持目录未改动。
- 跑 `还原` 后三个文件回到原厂、新增图标被删除。
