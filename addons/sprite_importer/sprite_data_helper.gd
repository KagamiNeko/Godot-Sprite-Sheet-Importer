class_name SpriteDataHelper
extends RefCounted
## SpriteData 渲染辅助工具（插件内置，零项目依赖）
##
## 封装从 SpriteData 中获取帧的所有复杂逻辑：
## - 方向索引 → direction_names[dir_idx] 映射
## - 镜像方向自动解析为源方向 + flip
## - 状态/方向不存在时自动 fallback 到 _default
## - 动态构建 SpriteFrames（含 FPS、循环、翻转）
##
## 消费者传入状态名/方向索引/变体名即可，方向索引超出范围时自动处理。


## 持有的 SpriteData 资源
var sprite_data: Resource  # SpriteData


func _init(sd: Resource) -> void:
	sprite_data = sd


# ============================================================
# 内部 — 状态 / 方向解析
# ============================================================

## 解析有效状态名
func _resolve_state(state: StringName) -> StringName:
	if sprite_data.states.has(state):
		return state
	if sprite_data.states.has("_default"):
		return &"_default"
	return state


## 方向索引 → 方向名（自动 clamp 到有效范围）
func _dir_idx_to_name(dir_idx: int) -> String:
	var names: Array = sprite_data.direction_names
	if names.size() == 0:
		return ""
	return names[clampi(dir_idx, 0, names.size() - 1)]


## 将方向名解析为实际查询方向 + 翻转参数
func _resolve_direction(state: StringName, dir_name: String) -> Dictionary:
	if dir_name == "":
		return {"dir": "", "flip_h": false, "flip_v": false}
	var sd: Resource = sprite_data
	var st: Dictionary = sd.states.get(state, {})
	var dirs: Dictionary = st.get("directions", {})

	if not dirs.has(dir_name):
		return {"dir": "", "flip_h": false, "flip_v": false}

	var dd: Dictionary = dirs[dir_name]
	if dd.has("mirror"):
		return {
			"dir": dd["mirror"],
			"flip_h": dd.get("flip_h", false),
			"flip_v": dd.get("flip_v", false),
		}
	return {"dir": dir_name, "flip_h": false, "flip_v": false}


## 方向索引 → 解析为实际查询方向 + flip
func _dir_idx_to_query(state: StringName, dir_idx: int) -> Dictionary:
	var dir_name: String = _dir_idx_to_name(dir_idx)
	return _resolve_direction(state, dir_name)


## 为指定状态寻找第一个可用的非镜像方向
func _find_available_dir(state: StringName) -> String:
	var sd: Resource = sprite_data
	var st: Dictionary = sd.states.get(state, {})
	var dirs: Dictionary = st.get("directions", {})

	for dn in sd.direction_names:
		if dirs.has(dn) and not dirs[dn].has("mirror"):
			return dn

	if sd.direction_names.size() > 0:
		return sd.direction_names[0]
	return ""


# ============================================================
# 公共 API — 帧查询
# ============================================================

## 获取指定状态的帧数
func get_frame_count(state: StringName, dir_idx: int) -> int:
	var s: StringName = _resolve_state(state)
	var query: Dictionary = _dir_idx_to_query(s, dir_idx)
	var qdir: String = query["dir"]
	if qdir == "":
		qdir = _find_available_dir(s)
		if qdir == "":
			return 1
	return sprite_data.get_frame_count(s, qdir)


## 获取单个帧贴图
func get_texture(state: StringName, dir_idx: int, frame_idx: int, variant: StringName = "_default") -> AtlasTexture:
	var s: StringName = _resolve_state(state)
	var query: Dictionary = _dir_idx_to_query(s, dir_idx)
	var qdir: String = query["dir"]
	if qdir == "":
		qdir = _find_available_dir(s)
		if qdir == "":
			return null
	var fi: int = max(0, frame_idx)
	return sprite_data.get_frame(s, qdir, fi, variant)


## 获取翻转信息
func get_flip(state: StringName, dir_idx: int) -> Dictionary:
	var query: Dictionary = _dir_idx_to_query(state, dir_idx)
	return {"h": query["flip_h"], "v": query["flip_v"]}


## 获取 FPS
func get_fps(state: StringName) -> int:
	var s: StringName = _resolve_state(state)
	var fps: int = sprite_data.get_fps(s)
	return fps if fps > 0 else 6


## 是否循环
func is_looping(state: StringName) -> bool:
	var s: StringName = _resolve_state(state)
	return sprite_data.is_looping(s)


## 是否为双倍高度实体
func is_double_height() -> bool:
	return sprite_data.is_double_height


## 判断是否需要 AnimatedSprite2D（存在多帧动画状态）
func needs_animated_sprite() -> bool:
	for state_name in sprite_data.states:
		if state_name == "_default":
			continue
		var max_frames: int = 0
		var st: Dictionary = sprite_data.states[state_name]
		if st.has("directions"):
			for dn in st["directions"]:
				var dd: Dictionary = st["directions"][dn]
				max_frames = max(max_frames, dd.get("frames", 1))
		else:
			max_frames = st.get("frames", 1)
		if max_frames > 1:
			return true
	return false


# ============================================================
# 公共 API — 构建 SpriteFrames
# ============================================================

## 按权重随机选取变体
func pick_random_variant() -> StringName:
	var vars: Dictionary = sprite_data.variants
	if vars.size() <= 1:
		return &"_default"
	var total_weight: float = 0.0
	for vn in vars:
		var w: float = vars[vn].get("weight", 0.0)
		if w > 0:
			total_weight += w
	if total_weight <= 0:
		return &"_default"
	var r: float = randf() * total_weight
	var acc: float = 0.0
	for vn in vars:
		var w: float = vars[vn].get("weight", 0.0)
		if w <= 0:
			continue
		acc += w
		if r <= acc:
			return vn
	return &"_default"


## 构建指定状态/朝向/变体的完整 SpriteFrames
func build_sprite_frames(state: StringName, dir_idx: int, variant: StringName = "_default") -> SpriteFrames:
	var s: StringName = _resolve_state(state)
	var query: Dictionary = _dir_idx_to_query(s, dir_idx)
	var qdir: String = query["dir"]
	if qdir == "":
		qdir = _find_available_dir(s)

	var frame_count: int = sprite_data.get_frame_count(s, qdir)
	if frame_count <= 0:
		frame_count = 1

	var frames: SpriteFrames = SpriteFrames.new()
	for fi in range(frame_count):
		var at: AtlasTexture = sprite_data.get_frame(s, qdir, fi, variant)
		if at:
			frames.add_frame(&"default", at)
		else:
			frames.add_frame(&"default", AtlasTexture.new())

	frames.set_animation_speed(&"default", float(get_fps(s)))
	frames.set_animation_loop(&"default", is_looping(s))

	return frames
