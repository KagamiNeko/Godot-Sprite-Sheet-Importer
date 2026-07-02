@tool
extends EditorImportPlugin
## Sprite Sheet 导入插件
##
## 监听 PNG 文件，检测同名 JSON 后自动生成 SpriteData.tres 资源。

const SpriteDataClass = preload("res://addons/sprite_importer/sprite_data.gd")


# ============================================================
# 导入器元信息
# ============================================================

func _get_importer_name() -> String:
	return "sprite_sheet"


func _get_visible_name() -> String:
	return "Sprite Sheet"


func _get_recognized_extensions() -> PackedStringArray:
	return ["png"]


func _get_save_extension() -> String:
	return "tres"


func _get_resource_type() -> String:
	return "SpriteData"


func _get_priority() -> float:
	return 1.5  # 高于默认 PNG 导入器 (1.0)


func _get_import_order() -> int:
	return 1


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


# ============================================================
# 导入逻辑
# ============================================================

func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	platform_variants: Array[String],
	gen_files: Array[String]
) -> Error:
	# 1. 查找同名 JSON
	var base_name := source_file.get_basename()
	var json_path := base_name + ".json"

	if not FileAccess.file_exists(json_path):
		return ERR_SKIP

	# 2. 读取并解析 JSON
	var json_file := FileAccess.open(json_path, FileAccess.READ)
	if json_file == null:
		printerr("[SpriteImporter] 无法读取 JSON: ", json_path)
		return ERR_FILE_CANT_OPEN

	var json_text := json_file.get_as_text()
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		printerr("[SpriteImporter] JSON 解析失败: ", json_path, " 行 ", json.get_error_line(), ": ", json.get_error_message())
		return ERR_PARSE_ERROR

	var data: Dictionary = json.get_data()

	# 3. 基础参数
	var grid: Vector2i = Vector2i(data["atlas"]["grid_size"][0], data["atlas"]["grid_size"][1])
	var is_double: bool = data.get("render", {}).get("is_double_height", false)
	var dir_names: Array = data["atlas"].get("direction_names", [])
	if dir_names.size() == 0:
		dir_names = ["_"]

	var states: Dictionary = data.get("states", {})
	var variants: Dictionary = data.get("variants", {})
	if variants.size() == 0:
		variants = {"_default": {"tile_offset": 0, "weight": 0}}

	# 4. 加载原始图集纹理（绕过资源系统，避免导入循环）
	var global_path := ProjectSettings.globalize_path(source_file)
	var img := Image.load_from_file(global_path)
	if img == null:
		printerr("[SpriteImporter] 无法加载纹理: ", source_file)
		return ERR_FILE_CANT_OPEN
	var atlas_tex := ImageTexture.create_from_image(img)

	# 5. 构建 SpriteData
	var sprite_data = SpriteDataClass.new()
	sprite_data.atlas_path = source_file
	sprite_data.atlas_texture = atlas_tex
	sprite_data.grid_size = grid
	sprite_data.direction_names = dir_names
	sprite_data.is_double_height = is_double
	sprite_data.states = states.duplicate(true)
	sprite_data.variants = variants.duplicate(true)

	var tile_h: int = grid.y * (2 if is_double else 1)
	var cols_per_row: int = max(1, ProjectSettings.get_setting("sprite_importer/max_atlas_width", 1024) / grid.x)

	# 6. 预建所有 AtlasTexture 帧（支持逐帧跨行换行）
	for state_name: String in states:
		var sd: Dictionary = states[state_name]
		for vn: String in variants:
			var vd: Dictionary = variants[vn]
			var offset: int = vd.get("tile_offset", 0)

			if sd.has("directions"):
				for dn: String in dir_names:
					if not sd["directions"].has(dn):
						continue
					var dd: Dictionary = sd["directions"][dn]
					if dd.has("mirror"):
						continue
					var frames: int = dd.get("frames", 1)
					var start_col: int = dd.get("start_col", 0)
					var start_row: int = dd.get("row", 0)
					for fi in range(frames):
						var flat_col: int = offset + start_col + fi
						var col: int = flat_col % cols_per_row
						var frame_row: int = start_row + flat_col / cols_per_row
						var at := AtlasTexture.new()
						at.region = Rect2(col * grid.x, frame_row * tile_h, grid.x, tile_h)
						var key := "%s_%s_%d_%s" % [state_name, dn, fi, vn]
						sprite_data.frames[key] = at
			else:
				var frames: int = sd.get("frames", 1)
				var start_col: int = sd.get("start_col", 0)
				var start_row: int = sd.get("row", 0)
				for fi in range(frames):
					var flat_col: int = offset + start_col + fi
					var col: int = flat_col % cols_per_row
					var frame_row: int = start_row + flat_col / cols_per_row
					var at := AtlasTexture.new()
					at.region = Rect2(col * grid.x, frame_row * tile_h, grid.x, tile_h)
					var key := "%s__%d_%s" % [state_name, fi, vn]
					sprite_data.frames[key] = at

	# 7. 保存
	var save_file := save_path + "." + _get_save_extension()
	var save_err := ResourceSaver.save(sprite_data, save_file)
	if save_err != OK:
		printerr("[SpriteImporter] 保存失败: ", save_file)
		return save_err

	gen_files.append(save_file)
	print("[SpriteImporter] SpriteData 已生成: ", save_file)
	return OK
