class_name SpriteData
extends Resource
## 贴图数据资源 — 由导入插件从 JSON+PNG 生成
##
## 运行时通过查询方法获取指定状态/朝向/帧/变体的 AtlasTexture


# ============================================================
# 基础数据
# ============================================================

## 图集纹理路径（运行时自动加载）
@export var atlas_path: String = ""
## 单位网格尺寸（像素）
@export var grid_size: Vector2i = Vector2i(64, 64)
## 朝向名称列表
@export var direction_names: Array = []
## 双倍高度（切图时 grid_size.y × 2）
@export var is_double_height: bool = false

## 状态定义 { state_name: { fps, loop, directions: { dir: { frames, start_col, flip_h, flip_v } } } }
@export var states: Dictionary = {}
## 变体定义 { variant_name: { tile_offset, weight, tint } }
@export var variants: Dictionary = {}
## 预建的 AtlasTexture 帧缓存 { "state_dir_frame_variant": AtlasTexture }
@export var frames: Dictionary = {}

## 运行时缓存的图集纹理
var _atlas: Texture = null


## 获取图集纹理
func get_atlas() -> Texture:
	if _atlas == null and atlas_path != "":
		_atlas = load(atlas_path) as Texture
	return _atlas


## 确保帧的 atlas 引用有效
func _ensure_atlas() -> void:
	var tex := get_atlas()
	if tex == null:
		return
	for key in frames:
		var at: AtlasTexture = frames[key]
		if at.atlas == null:
			at.atlas = tex


# ============================================================
# 查询方法
# ============================================================

## 获取指定状态/朝向/帧/变体的贴图
func get_frame(state: StringName, direction: StringName, frame_idx: int, variant: StringName = "_default") -> AtlasTexture:
	var key := "%s_%s_%d_%s" % [state, direction, frame_idx, variant]
	if not frames.has(key):
		return null
	var at: AtlasTexture = frames[key]
	if at.atlas == null:
		var tex := get_atlas()
		if tex:
			at.atlas = tex
	return at


## 获取指定状态/朝向的帧数
func get_frame_count(state: StringName, direction: StringName) -> int:
	var sd: Dictionary = states.get(state, {})
	var dirs: Dictionary = sd.get("directions", {})
	if dirs.has(direction):
		return dirs[direction].get("frames", 1)
	if sd.has("frames"):
		return sd["frames"]
	return 1


## 获取状态的 FPS
func get_fps(state: StringName) -> int:
	var sd: Dictionary = states.get(state, {})
	return sd.get("fps", 1)


## 获取状态是否循环
func is_looping(state: StringName) -> bool:
	var sd: Dictionary = states.get(state, {})
	return sd.get("loop", true)


## 获取方向是否为镜像
func is_mirror(state: StringName, direction: StringName) -> bool:
	var sd: Dictionary = states.get(state, {})
	var dirs: Dictionary = sd.get("directions", {})
	if dirs.has(direction):
		return dirs[direction].has("flip_h") or dirs[direction].has("flip_v")
	return false


## 获取镜像翻转
func get_flip(state: StringName, direction: StringName) -> Dictionary:
	var sd: Dictionary = states.get(state, {})
	var dirs: Dictionary = sd.get("directions", {})
	if dirs.has(direction):
		return {"h": dirs[direction].get("flip_h", false), "v": dirs[direction].get("flip_v", false)}
	return {"h": false, "v": false}
