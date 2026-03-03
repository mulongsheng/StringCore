# StringCore

基于 FFXIVMinion 平台的 TensorReaction 辅助插件。

## 功能模块

### 减伤规划系统

- 支持 M9S / M10S / M11S / M12S 副本
- 按 AOE 时间线勾选需要减伤的技能
- 自动识别职业对应的减伤技能（牵制/昏乱/雪仇等）
- 队伍职能自动分配 + 可拖拽调整

### MapEffect 查看器

- 实时查看当前地图所有特效资源
- 覆盖 22 个 Argus API（位置/朝向/缩放/脚本/子资源）
- 支持按类型/文本过滤、右键复制
- 支持手动执行 runMapEffect / addPlayerMarker

### Argus 代码生成器

- 10 种形状：圆形 / 扇形 / 矩形 / 居中矩形 / 甜甜圈 / 扇形甜甜圈 / 十字 / 箭头 / V形 / 线条
- 支持 ShapeDrawer 和 Argus2 底层两种 API
- 支持 Timed（持续时间）和 OnFrame（每帧瞬时）两种模式
- 支持坐标固定和 OnEnt（附着实体）两种附着方式
- 颜色选择器 + 10 个预设颜色 + 渐变色支持
- 默认使用 TensorCore.getMoogleDrawer() 配色
- 一键预览 / 生成代码 / 复制到剪贴板

## 依赖

- minionlib
- TensorCore

## 安装

将 `StringCore` 文件夹放入 `FFXIVMinion64/LuaMods/` 目录下即可。
