# 🎨 Sprite Sheet Importer

**Godot 4.x 编辑器插件** — 为游戏中的角色、物品、地形等实体提供完整的图集数据管理工具链。

[![Godot](https://img.shields.io/badge/Godot-4.3%2B-blue)](https://godotengine.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

---

## 📖 目录

- [功能概述](#功能概述)
- [快速开始](#快速开始)
- [编辑器面板](#编辑器面板)
- [JSON 数据结构](#json-数据结构)
- [空图集生成](#空图集生成)
- [SpriteData 资源导入](#spritedata-资源导入)
- [运行时使用](#运行时使用)
- [文件结构](#文件结构)

---

## 功能概述

传统游戏开发中，一个实体可能有多种**状态**（idle / walk / attack）、多种**朝向**（N / E / S / W）、多帧**动画**、以及多种**变体**（默认 / 精英 / 受伤）。这些维度互相叠加，手动管理贴图坐标极其繁琐。

本插件提供一套完整的解决方案：

| 模块 | 功能 |
|------|------|
| 🖥️ **编辑器面板** | 可视化配置状态、朝向、变体，自动计算图集坐标 |
| 📋 **JSON 规范** | 结构化的图集元数据，可版本控制、可脚本批量生成 |
| 🏗️ **空图集生成** | 一键生成带网格标注的 PNG，美术可直接参照绘制 |
| 📦 **自动导入** | PNG+JSON → SpriteData 资源，运行时零解析开销 |

### 设计理念

- **万物皆状态**：角色用 idle/walk 是状态，门用 open/closed 也是状态，墙体用 intact/damaged 也是
- **密排图集**：所有图块连续排列，1024px 自动换行，零空隙
- **镜像复用**：左右对称的方向可复用同一组帧（水平翻转），节省图集空间
- **变体扁平化**：多套贴图共用一个图集 + 一套坐标，易于管理

---

## 快速开始

### 安装

1. 将 `addons/sprite_importer/` 复制到项目的 `addons/` 目录
2. `项目设置 → 插件` → 启用 `Sprite Sheet Importer`
3. 编辑器右侧出现 **`Sprite Importer`** 面板

### 5 分钟上手

1. 在面板中点击 `...` 选择一张 PNG 图集（可先用空图集）
2. 设置朝向名称（默认 `N,E,S,W`）
3. 点击状态列表的 `+ 添加`，创建 `idle`、`walk` 等状态
4. 在状态弹窗中勾选"区分朝向"，设置帧数，配置镜像方向
5. 点击 `保存 JSON` → `生成空图集`
6. 将生成的标记 PNG 交给美术绘制
7. 美术完成后替换 PNG → **右键 Reimport** → 自动生成 `SpriteData.tres`

---

## 编辑器面板

面板位于编辑器右侧 dock（与 Inspector 同侧）。

### 图集配置

| 字段 | 说明 |
|------|------|
| 图集 PNG | 图集文件路径 |
| 图集名称 | 用于标识该图集的实体（如 `enemy_soldier`） |
| JSON 路径 | 元数据文件路径，默认与 PNG 同名 |
| 网格尺寸 | 单个图块的像素尺寸（W×H），默认为 64×64 |
| 朝向数 | 实体朝向数量，0=无朝向（如地板） |
| 朝向名称 | 逗号分隔，如 `N,E,S,W` |

### 状态配置

每个状态有两种模式：

- **不区分朝向**：适合静态实体（地板、死亡动画）
  - 帧数、FPS、循环

- **区分朝向**：适合有方向的实体（行走、攻击）
  - 每方向帧数、FPS、循环
  - 每方向可选择 **独立**（占据图块）或 **镜像**（复用另一方向 + 翻转）

### 变体配置

- 变体名、随机权重、染色（tint）
- 默认变体 `_default` 永远存在，不可删除
- 偏移量自动计算，无需手动管理
- 按首字母排序

### 操作按钮

- **新建**：清空配置
- **加载 JSON**：读取已有配置
- **保存 JSON**：写入元数据文件
- **生成空图集**：根据配置生成带标注的 PNG

---

## JSON 数据结构

```jsonc
{
  "version": "1.0",
  "meta": {
    "name": "enemy_soldier"       // 图集名称
  },
  "atlas": {
    "grid_size": [64, 64],        // 单位网格尺寸
    "directions": 4,              // 朝向数量
    "direction_names": ["N","E","S","W"]
  },
  "states": {
    "_default": {                 // 始终存在，回退用
      "row": 0, "start_col": 0
    },
    "idle": {                     // 无朝向静态状态
      "row": 0, "start_col": 1,
      "frames": 1                 // 帧数=1 时省略
    },
    "walk": {                     // 有朝向动画状态
      "directions": {
        "N": {"row": 0, "start_col": 2, "frames": 4},
        "E": {"row": 0, "start_col": 6, "frames": 4},
        "S": {                    // 镜像方向：复用 N，水平翻转
          "mirror": "N",
          "row": 0, "start_col": 2,
          "frames": 4,
          "flip_h": true
        },
        "W": {"mirror": "E", "row": 0, "start_col": 6, "frames": 4, "flip_h": true}
      },
      "fps": 8, "loop": true
    }
  },
  "variants": {
    "_default": {                 // 始终存在
      "tile_offset": 0, "weight": 0
    },
    "elite": {
      "tile_offset": 5, "weight": 3, "tint": "#ffcccc"
    }
  },
  "render": {
    "is_double_height": false     // 切图时高度是否 ×2
  }
}
```

> **坐标系统**：所有图块逐帧平铺为扁平序列，`row` / `start_col` 由编辑器自动计算。超出 `max_atlas_width` 时自动换行，同方向帧可跨行拆分以紧密填满。变体通过 `tile_offset` 全局偏移。

---

## 空图集生成

点击"生成空图集"按钮后，根据当前配置生成一张 PNG：

- 每个图块左上角标注 `图集名_状态_方向_帧_变体`
- 图块边框按**状态名**着色，同状态同色系
- 右下角堆叠**5×5 空心方框**，按变体名着色，第 N 个方向堆 N+1 个
- 镜像源图块底部标注 `<-方向:翻转`
- 变体切换处以 1px 变体色竖线分隔
- 宽度由项目设置 `sprite_importer/max_atlas_width` 决定（默认 1024px）
- 逐帧紧密平铺，同方向帧可跨行拆分以填满宽度
- 内置 5×7 像素字体，不依赖系统字体

美术拿到空图集后，直接在对应图格内替换为实际素材即可。

---

## SpriteData 资源导入

PNG 文件如果有同名 JSON，导入插件会自动生成 `SpriteData.tres`。

> **注意**：将 PNG 拖入 `SpriteData` 字段即可，Godot 的导入系统会自动解析为导入后的资源，无需手动指定 `.tres` 路径。

### 项目设置

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| `addons/sprite_importer/max_atlas_width` | 1024 | 图集最大宽度（px），超宽自动换行 |

### 运行时查询

```gdscript
var sd: SpriteData = load("res://sprites/enemy_soldier.png")

# 获取贴图
var frame: AtlasTexture = sd.get_frame("idle", "N", 0, "_default")

# 查询属性
sd.get_frame_count("walk", "E")   # → 4
sd.get_fps("walk")                # → 8
sd.is_looping("walk")             # → true
sd.is_mirror("idle", "S")         # → true
sd.get_flip("idle", "S")          # → {"h": true, "v": false}
sd.is_double_height               # → true（双倍高度实体）
```

### SpriteDataHelper（推荐）

插件仓库附带了 `scripts/utils/sprite_data_helper.gd` 辅助工具，封装方向映射、镜像解析、fallback 等逻辑：

```gdscript
var helper := SpriteDataHelper.new(sprite_data)

# Direction 枚举 → 方向名映射
var frames := helper.build_sprite_frames("idle", GlobalEnums.Direction.SOUTH)
animated_sprite.sprite_frames = frames
animated_sprite.flip_h = helper.get_flip("idle", GlobalEnums.Direction.SOUTH)["h"]

# 查询帧数（自动处理镜像方向）
helper.get_frame_count("walk", GlobalEnums.Direction.EAST)
```

---

## 运行时使用

### 自定义渲染器

```gdscript
var helper := SpriteDataHelper.new(sprite_data)

# 状态切换
func set_state(state_name: String) -> void:
    var frames := helper.build_sprite_frames(state_name, facing, variant)
    sprite.sprite_frames = frames
    sprite.play("default")
    var flip := helper.get_flip(state_name, facing)
    sprite.flip_h = flip["h"]
```

---

## 文件结构

```
addons/sprite_importer/
├── plugin.cfg                  # 插件注册
├── plugin.gd                   # EditorPlugin 入口 + 项目设置注册
├── sprite_sheet_editor.gd      # 编辑器配置面板（~900 行）
├── import_plugin.gd            # EditorImportPlugin 自动导入
├── atlas_generator.gd          # 空图集生成器（含 5×7 位图字体 + 区分色标注）
└── sprite_data.gd              # SpriteData 资源类（运行时查询，已内置插件中）

scripts/utils/
└── sprite_data_helper.gd       # SpriteDataHelper 辅助工具（方向映射 + 镜像解析 + SpriteFrames 构建）
```

---

## 许可

MIT License

---

## 致谢

本项目灵感来源于 Aseprite、TexturePacker 等工具，专为 Godot 4.x 编辑器深度集成而设计。
