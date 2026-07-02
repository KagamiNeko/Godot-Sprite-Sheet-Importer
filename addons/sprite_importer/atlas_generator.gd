@tool
class_name AtlasGenerator
extends RefCounted
## 根据图集 JSON 配置生成带网格标记的空图集 PNG
##
## 利用内置 5×7 位图字体绘制文字标注，不依赖 Godot 字体系统，
## 可在任何环境下独立运行。


# ============================================================
# 5×7 位图字体（ASCII 32-90, 95, 97-122）
# ============================================================

static var _FONT: Dictionary = {
	"A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
	"B": [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110],
	"C": [0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110],
	"D": [0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110],
	"E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
	"F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
	"G": [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110],
	"H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
	"I": [0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
	"J": [0b00111, 0b00001, 0b00001, 0b00001, 0b00001, 0b10001, 0b01110],
	"K": [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001],
	"L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
	"M": [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001],
	"N": [0b10001, 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001],
	"O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
	"P": [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000],
	"Q": [0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101],
	"R": [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001],
	"S": [0b01110, 0b10001, 0b10000, 0b01110, 0b00001, 0b10001, 0b01110],
	"T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
	"U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
	"V": [0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b01010, 0b00100],
	"W": [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b11011, 0b10001],
	"X": [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001],
	"Y": [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100],
	"Z": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111],

	"0": [0b01110, 0b10011, 0b10101, 0b10101, 0b11001, 0b10001, 0b01110],
	"1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
	"2": [0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111],
	"3": [0b01110, 0b10001, 0b00001, 0b00110, 0b00001, 0b10001, 0b01110],
	"4": [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
	"5": [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110],
	"6": [0b01110, 0b10001, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110],
	"7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
	"8": [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110],
	"9": [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b10001, 0b01110],

	" ": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000],
	"-": [0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000],
	"_": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b11111],
	":": [0b00000, 0b00100, 0b00000, 0b00000, 0b00100, 0b00000, 0b00000],
	",": [0b00000, 0b00000, 0b00000, 0b00000, 0b00100, 0b00100, 0b01000],
	".": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00100],
	"/": [0b00001, 0b00010, 0b00010, 0b00100, 0b01000, 0b01000, 0b10000],
	"#": [0b01010, 0b01010, 0b11111, 0b01010, 0b11111, 0b01010, 0b01010],
	"x": [0b00000, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b00000],
	"<": [0b00010, 0b00100, 0b01000, 0b10000, 0b01000, 0b00100, 0b00010],
	">": [0b01000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b01000],
}

static var _CHAR_W := 5
static var _CHAR_H := 7
static var _CHAR_SPACING := 1  # 字符间距


# ============================================================
# 绘制方法
# ============================================================

## 在图集中绘制单个像素字符
static func _draw_char(img: Image, x: int, y: int, ch: String, color: Color) -> void:
	var bitmap: Array = _FONT.get(ch, _FONT[" "])
	for row in range(_CHAR_H):
		var bits: int = bitmap[row]
		for col in range(_CHAR_W):
			if bits & (1 << (_CHAR_W - 1 - col)):
				var px := x + col
				var py := y + row
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)


## 在图集中绘制字符串（自动转大写以适配位图字体）
static func _draw_string(img: Image, x: int, y: int, text: String, color: Color) -> void:
	var upper := text.to_upper()
	for i in range(upper.length()):
		_draw_char(img, x + i * (_CHAR_W + _CHAR_SPACING), y, upper[i], color)


# ============================================================
# 主入口
# ============================================================

## 根据图集数据生成空图集 PNG
## @param data: 与 JSON 相同结构的 Dictionary
## @param png_path: 输出 PNG 的绝对路径
## @return Error
static func generate(data: Dictionary, png_path: String) -> Error:
	# ---- 基本参数 ----
	var grid: Vector2i = Vector2i(data["atlas"]["grid_size"][0], data["atlas"]["grid_size"][1])
	var is_double: bool = data.get("render", {}).get("is_double_height", false)
	var tile_w: int = grid.x
	var tile_h: int = grid.y * (2 if is_double else 1)

	var dir_names: Array = data["atlas"].get("direction_names", [])
	if dir_names.size() == 0:
		dir_names = ["_"]

	var states: Dictionary = data.get("states", {})
	var variants: Dictionary = data.get("variants", {})

	var variant_names: Array = variants.keys()
	if variant_names.size() == 0:
		variant_names = ["_default"]

	var atlas_name: String = data.get("meta", {}).get("name", "sprite")
	if atlas_name == "":
		atlas_name = "sprite"

	var max_chars_per_line := max(1, (tile_w - 4) / (_CHAR_W + _CHAR_SPACING))

	# ---- 按 JSON 坐标精准绘制（与导入插件读取坐标一致）----
	var max_atlas_w: int = ProjectSettings.get_setting("addons/sprite_importer/max_atlas_width", 1024)
	var cols_per_row: int = max(1, max_atlas_w / tile_w)

	# 第一遍：收集图块 + 计算图集尺寸
	var tile_list: Array[Dictionary] = []
	var max_col: int = 0
	var max_row: int = 0

	for state_name: String in states:
		var sd: Dictionary = states[state_name]
		if sd.has("directions"):
			var mirror_sources: Dictionary = {}
			for dn: String in dir_names:
				if not sd["directions"].has(dn):
					continue
				var dd: Dictionary = sd["directions"][dn]
				if dd.has("mirror"):
					var src: String = dd["mirror"]
					if not mirror_sources.has(src):
						mirror_sources[src] = []
					mirror_sources[src].append({"dir": dn, "fh": dd.get("flip_h", false), "fv": dd.get("flip_v", false)})

			for dn: String in dir_names:
				if not sd["directions"].has(dn):
					continue
				var dd: Dictionary = sd["directions"][dn]
				if dd.has("mirror"):
					continue
				var frames: int = dd.get("frames", 1)
				var start_col: int = dd.get("start_col", 0)
				var row: int = dd.get("row", 0)

				var mirror_info := ""
				if mirror_sources.has(dn):
					for ms in mirror_sources[dn]:
						var m := "<-%s" % ms["dir"]
						if ms["fh"] or ms["fv"]:
							if ms["fh"]: m += "H"
							if ms["fv"]: m += "V"
						if mirror_info != "": mirror_info += " "
						mirror_info += m

				for fi in range(frames):
					var flat_col: int = start_col + fi
					var col: int = flat_col % cols_per_row
					var frame_row: int = row + flat_col / cols_per_row
					max_col = max(max_col, col)
					max_row = max(max_row, frame_row)
					for vn: String in variant_names:
						var vd: Dictionary = variants.get(vn, {})
						var voffset: int = vd.get("tile_offset", 0)
						var fc: int = col + voffset
						var fr: int = frame_row + fc / cols_per_row
						fc = fc % cols_per_row
						tile_list.append({
							"col": fc,
							"row": fr,
							"state": state_name,
							"variant": vn,
							"dir": dn,
							"frame": fi,
							"mirror": mirror_info,
							"label": "%s_%s_%s_f%d_%s" % [atlas_name, state_name, dn, fi, vn.to_upper()],
						})
		else:
			var frames: int = sd.get("frames", 1)
			var start_col: int = sd.get("start_col", 0)
			var row: int = sd.get("row", 0)
			for fi in range(frames):
				var flat_col: int = start_col + fi
				var col: int = flat_col % cols_per_row
				var frame_row: int = row + flat_col / cols_per_row
				max_col = max(max_col, col)
				max_row = max(max_row, frame_row)
				for vn: String in variant_names:
					var vd: Dictionary = variants.get(vn, {})
					var voffset: int = vd.get("tile_offset", 0)
					var fc: int = col + voffset
					var fr: int = frame_row + fc / cols_per_row
					fc = fc % cols_per_row
					tile_list.append({
						"col": fc,
						"row": fr,
						"state": state_name,
						"variant": vn,
						"dir": "",
						"frame": fi,
						"mirror": "",
						"label": "%s_%s_f%d_%s" % [atlas_name, state_name, fi, vn.to_upper()],
					})

	if tile_list.size() == 0:
		push_error("[AtlasGenerator] 无图块可绘制")
		return ERR_INVALID_DATA

	# 计算图集尺寸（宽度始终取项目设定值，右侧可有空列）
	var atlas_w: int = max_atlas_w
	var atlas_h: int = (max_row + 1) * tile_h

	var img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.14, 0.14, 0.18, 1.0))

	# 第二遍：在 JSON 坐标处精准绘制
	var _prev_state := ""
	var _prev_dir := ""
	var _dir_index := 0
	for ti in range(tile_list.size()):
		var tile: Dictionary = tile_list[ti]

		# 计算状态内方向序号
		if tile["dir"] == "":
			_dir_index = 0
		elif tile["state"] != _prev_state:
			_dir_index = 0
		elif tile["dir"] != _prev_dir:
			_dir_index += 1
		_prev_state = tile["state"]
		_prev_dir = tile["dir"]

		# 变体检测
		var is_new_variant: bool = true
		if ti > 0:
			is_new_variant = tile["variant"] != tile_list[ti - 1]["variant"]

		# 精准坐标
		var cx: int = tile["col"] * tile_w
		var cy: int = tile["row"] * tile_h

		# 边框颜色 → 状态名
		var state_color := _name_to_color(tile["state"])
		# 小方框颜色 → 变体名
		var variant_color := _name_to_color(tile["variant"])

		# 变体分隔线
		if is_new_variant:
			img.fill_rect(Rect2i(cx, cy, 1, tile_h), variant_color.lightened(0.15))

		# 状态色边框
		_draw_cell_border(img, cx, cy, tile_w, tile_h, state_color)
		_draw_wrapped_label(img, cx + 2, cy + 2, tile["label"], max_chars_per_line, Color(0.85, 0.88, 0.92))

		# 右下角堆叠空心方框
		var dot_x := cx + tile_w - 8
		var dot_y := cy + tile_h - 8
		var count := _dir_index + 1
		for i in range(count):
			_draw_hollow_rect(img, dot_x, dot_y - i * 6, 5, 5, variant_color)

		if tile["mirror"] != "":
			var bottom_y := cy + tile_h - _CHAR_H - 2
			_draw_string(img, cx + 2, bottom_y, tile["mirror"], Color(0.9, 0.7, 0.3))

	# ---- 保存 ----
	var err := img.save_png(png_path)
	if err == OK:
		print("[AtlasGenerator] 空图集已生成: %s (%dx%d)" % [png_path, atlas_w, atlas_h])
	else:
		push_error("[AtlasGenerator] 保存失败: %s" % png_path)
	return err


## 根据名称生成稳定的区分颜色（用于状态/变体边框）
## 使用黄金比例分布色相，同名字始终得到相同颜色
static func _name_to_color(name: String) -> Color:
	var h := float(name.hash()) / float(0xFFFFFFFF)
	h = fmod(abs(h) * 1.61803398875, 1.0)  # 黄金比例分布
	var s := 0.45 + fmod(h * 3.7, 0.35)     # 0.45 ~ 0.8
	var v := 0.45 + fmod(h * 5.3, 0.25)     # 0.45 ~ 0.7
	return Color.from_hsv(h, s, v)


## 在图集中绘制换行标签
## 按 _ 分词，每段在不超过 max_chars 时追加到当前行，否则换行
static func _draw_wrapped_label(img: Image, x: int, y: int, text: String, max_chars: int, color: Color) -> void:
	var segments: Array[String] = []
	for seg in text.split("_"):
		segments.append(seg)

	var line := ""
	var line_y := y
	for seg in segments:
		var test := line
		if test != "":
			test += "_"
		test += seg
		if test.length() <= max_chars:
			line = test
		else:
			# 当前行放不下，先输出上一行
			if line != "":
				_draw_string(img, x, line_y, line, color)
				line_y += _CHAR_H + 1
			line = seg
			# 单词本身太长则直接截断
			if line.length() > max_chars:
				_draw_string(img, x, line_y, line.substr(0, max_chars), color)
				line_y += _CHAR_H + 1
				line = line.substr(max_chars)
	if line != "":
		_draw_string(img, x, line_y, line, color)


## 绘制格子边框（1px 线条）
static func _draw_cell_border(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	# 上边
	for i in range(w):
		img.set_pixel(x + i, y, color)
	# 下边
	for i in range(w):
		img.set_pixel(x + i, y + h - 1, color)
	# 左边
	for i in range(h):
		img.set_pixel(x, y + i, color)
	# 右边
	for i in range(h):
		img.set_pixel(x + w - 1, y + i, color)


## 绘制 1px 空心矩形框
static func _draw_hollow_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for i in range(w):
		img.set_pixel(x + i, y, color)
		img.set_pixel(x + i, y + h - 1, color)
	for i in range(1, h - 1):
		img.set_pixel(x, y + i, color)
		img.set_pixel(x + w - 1, y + i, color)
