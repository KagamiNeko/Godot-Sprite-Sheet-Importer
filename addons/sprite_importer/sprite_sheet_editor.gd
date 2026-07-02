@tool
class_name SpriteSheetEditor
extends Control
## 图集 JSON 编辑器停靠面板
##
## 在编辑器中可视化配置实体贴图图集，生成 JSON 元数据文件。
## 支持状态/朝向/变体/叠加层的完整编辑。


# ============================================================
# 引用
# ============================================================

var plugin: EditorPlugin = null

# ============================================================
# 数据模型
# ============================================================

var _data: Dictionary = {}
var _current_json_path: String = ""

## 当前选中项追踪（用于删除操作）
var _selected_state: String = ""
var _selected_variant: String = ""

# ============================================================
# UI 节点引用
# ============================================================

var _atlas_png_line: LineEdit = null
var _atlas_name_line: LineEdit = null
var _atlas_json_line: LineEdit = null
var _grid_w_spin: SpinBox = null
var _grid_h_spin: SpinBox = null
var _dir_count_spin: SpinBox = null
var _dir_names_line: LineEdit = null
var _double_height_check: CheckBox = null
var _effective_size_label: Label = null
var _json_preview: TextEdit = null

# 列表容器
var _states_list: VBoxContainer = null
var _variants_list: VBoxContainer = null


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	_init_empty_data()
	_build_ui()
	_refresh_all_lists()
	_update_json_preview()


func _init_empty_data() -> void:
	_data = {
		"version": "1.0",
		"meta": {"name": "", "description": ""},
		"atlas": {"grid_size": [64, 64], "directions": 4, "direction_names": ["N", "E", "S", "W"]},
		"states": {
			"_default": {"row": 0, "start_col": 0, "frames": 1, "fps": 1, "loop": true}
		},
		"variants": {
			"_default": {"tile_offset": 0, "weight": 0}
		},
		"render": {"is_double_height": false}
	}


# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 整体背景
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.16, 0.19, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	
	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(main_vbox)

	_build_atlas_section(main_vbox)
	_build_states_section(main_vbox)
	_build_variants_section(main_vbox)
	_build_render_section(main_vbox)
	_build_action_bar(main_vbox)
	_build_json_preview(main_vbox)


# -- 图集配置区 --

func _build_atlas_section(parent: VBoxContainer) -> void:
	_add_section_label(parent, "图集配置")

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)

	# PNG 路径
	_add_label(grid, "图集 PNG:")
	var png_hbox := HBoxContainer.new()
	png_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(png_hbox)
	_atlas_png_line = _add_line_edit(png_hbox, "")
	_atlas_png_line.text_changed.connect(_on_png_path_changed)
	var png_btn := Button.new()
	png_btn.text = "..."
	png_btn.pressed.connect(_on_browse_png)
	png_hbox.add_child(png_btn)

	# 图集名称
	_add_label(grid, "图集名称:")
	_atlas_name_line = _add_line_edit(grid, "")
	_atlas_name_line.placeholder_text = "例如: enemy_soldier"
	_atlas_name_line.text_changed.connect(_on_atlas_name_changed)

	# JSON 路径
	_add_label(grid, "JSON 路径:")
	_atlas_json_line = _add_line_edit(grid, "")

	# 网格尺寸
	_add_label(grid, "网格尺寸 (W×H):")
	var grid_hbox := HBoxContainer.new()
	grid.add_child(grid_hbox)
	_grid_w_spin = _add_spin_box(grid_hbox, 64, 1, 512, "W:")
	_grid_h_spin = _add_spin_box(grid_hbox, 64, 1, 512, "H:")
	_grid_w_spin.value_changed.connect(_on_atlas_param_changed.unbind(1))
	_grid_h_spin.value_changed.connect(_on_atlas_param_changed.unbind(1))

	# 有效尺寸提示
	_effective_size_label = Label.new()
	_effective_size_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_effective_size_label.add_theme_font_size_override("font_size", 11)
	_effective_size_label.text = ""
	parent.add_child(_effective_size_label)

	# 朝向数
	_add_label(grid, "朝向数:")
	var dir_hbox := HBoxContainer.new()
	grid.add_child(dir_hbox)
	_dir_count_spin = _add_spin_box(dir_hbox, 0, 0, 8, "数量:")
	_dir_count_spin.value_changed.connect(_on_dir_count_changed)

	# 朝向名称
	_add_label(grid, "朝向名称:")
	_dir_names_line = _add_line_edit(grid, "")
	_dir_names_line.placeholder_text = "NE,NW,SE,SW (逗号分隔)"
	_dir_names_line.text_changed.connect(_on_atlas_param_changed.unbind(1))


# -- 状态列表区 --

func _build_states_section(parent: VBoxContainer) -> void:
	_add_section_label(parent, "状态列表 (States)")
	_states_list = _build_item_list_section(parent, "_add_state", "_edit_state", "_remove_state")


# -- 变体列表区 --

func _build_variants_section(parent: VBoxContainer) -> void:
	_add_section_label(parent, "变体列表 (Variants) — 偏移自动计算")
	_variants_list = _build_item_list_section(parent, "_add_variant", "_edit_variant", "_remove_variant")


# -- 渲染参数区 --

func _build_render_section(parent: VBoxContainer) -> void:
	_add_section_label(parent, "渲染参数")
	_double_height_check = _add_check_box(parent, "双倍高度实体（图集切图高度自动×2）", false)
	_double_height_check.toggled.connect(_on_render_param_changed)


## 更新有效图集切图尺寸提示
func _update_effective_size_label() -> void:
	if not _effective_size_label:
		return
	var w := int(_grid_w_spin.value)
	var h := int(_grid_h_spin.value)
	if _double_height_check and _double_height_check.button_pressed:
		_effective_size_label.text = "  有效切图尺寸: %d×%d (高度=%d×2)" % [w, h * 2, h]
	else:
		_effective_size_label.text = ""


# -- 操作栏 --

func _build_action_bar(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	parent.add_child(btn_hbox)

	var new_btn := Button.new()
	new_btn.text = "新建"
	new_btn.pressed.connect(_on_new)
	_style_small_button(new_btn, Color(0.35, 0.35, 0.4))
	btn_hbox.add_child(new_btn)

	var load_btn := Button.new()
	load_btn.text = "加载 JSON"
	load_btn.pressed.connect(_on_load_json)
	_style_small_button(load_btn, Color(0.35, 0.35, 0.4))
	btn_hbox.add_child(load_btn)

	var save_btn := Button.new()
	save_btn.text = "保存 JSON"
	save_btn.pressed.connect(_on_save_json)
	_style_small_button(save_btn, Color(0.25, 0.45, 0.25))
	btn_hbox.add_child(save_btn)

	var gen_btn := Button.new()
	gen_btn.text = "生成空图集"
	gen_btn.pressed.connect(_on_generate_atlas)
	_style_small_button(gen_btn, Color(0.45, 0.35, 0.2))
	btn_hbox.add_child(gen_btn)


# -- JSON 预览 --

func _build_json_preview(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	_add_section_label(parent, "JSON 预览")
	_json_preview = TextEdit.new()
	_json_preview.custom_minimum_size = Vector2(0, 180)
	_json_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_json_preview.size_flags_vertical = Control.SIZE_FILL
	_json_preview.editable = false
	# 暗色代码主题
	_json_preview.add_theme_color_override("background_color", Color(0.12, 0.12, 0.15))
	_json_preview.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	_json_preview.add_theme_font_size_override("font_size", 12)
	parent.add_child(_json_preview)


# ============================================================
# 列表 UI 辅助
# ============================================================

func _build_item_list_section(parent: VBoxContainer, add_method: String, _edit_method: String, _remove_method: String) -> VBoxContainer:
	"""创建一个带 [+] 按钮的可滚动列表区域"""
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 2)
	parent.add_child(toolbar)

	var add_btn := Button.new()
	add_btn.text = "+ 添加"
	add_btn.pressed.connect(Callable(self, add_method))
	_style_small_button(add_btn, Color(0.3, 0.5, 0.3))
	toolbar.add_child(add_btn)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0, 80)
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(list_scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 1)
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_vbox)

	return list_vbox


# ============================================================
# 基础 UI 工厂方法
# ============================================================

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_section_header_style())
	parent.add_child(panel)
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
	panel.add_child(lbl)

func _add_label(parent: Control, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)
	return lbl

func _add_line_edit(parent: Control, default_text: String) -> LineEdit:
	var le := LineEdit.new()
	le.text = default_text
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(le)
	return le

func _add_spin_box(parent: Control, default_val: float, min_val: float, max_val: float, prefix: String = "") -> SpinBox:
	var prefix_lbl: Label = null
	if prefix != "":
		prefix_lbl = Label.new()
		prefix_lbl.text = prefix
		parent.add_child(prefix_lbl)
	var sb := SpinBox.new()
	sb.value = default_val
	sb.min_value = min_val
	sb.max_value = max_val
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sb)
	return sb

func _add_check_box(parent: Control, text: String, default_val: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = default_val
	parent.add_child(cb)
	return cb

func _add_color_picker(parent: Control, default_color: Color) -> ColorPickerButton:
	var cpb := ColorPickerButton.new()
	cpb.color = default_color
	parent.add_child(cpb)
	return cpb


# ============================================================
# 样式辅助方法
# ============================================================

func _make_section_header_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.25, 0.32, 1.0)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.content_margin_left = 6
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	return sb


func _style_small_button(btn: Button, tint: Color) -> void:
	btn.add_theme_font_size_override("font_size", 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = tint.lightened(0.15)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb.duplicate()
	sb_pressed.bg_color = tint.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", sb_pressed)


# ============================================================
# 列表刷新
# ============================================================

func _refresh_all_lists() -> void:
	_refresh_list(_states_list, _data["states"], "_edit_state", _make_state_summary, func(k): _selected_state = k, "_remove_state_by_key")
	_refresh_list(_variants_list, _data["variants"], "_edit_variant", _make_variant_summary, func(k): _selected_variant = k, "_remove_variant_by_key")


func _refresh_list(list_vbox: VBoxContainer, data_dict: Dictionary, edit_method: String, summary_func: Callable, selection_setter: Callable, delete_method: String) -> void:
	for child in list_vbox.get_children():
		child.queue_free()

	for key: String in data_dict:
		var item_dict: Dictionary = data_dict[key]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 1)
		list_vbox.add_child(row)

		# 主按钮（点击编辑）
		var btn := Button.new()
		btn.text = " " + summary_func.call(key, item_dict)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.19, 0.19, 0.22, 1.0)
		sb.content_margin_left = 4; sb.content_margin_top = 2; sb.content_margin_bottom = 2
		sb.corner_radius_top_left = 2; sb.corner_radius_top_right = 2
		sb.corner_radius_bottom_left = 2; sb.corner_radius_bottom_right = 2
		btn.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate()
		sb_hover.bg_color = Color(0.25, 0.28, 0.35, 1.0)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.pressed.connect(func():
			selection_setter.call(key)
			Callable(self, edit_method).call(key)
		)
		row.add_child(btn)

		# × 删除
		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.disabled = (key == "_default")
		del_btn.pressed.connect(Callable(self, delete_method).bind(key))
		_style_small_button(del_btn, Color(0.5, 0.3, 0.3))
		row.add_child(del_btn)


func _make_state_summary(name: String, d: Dictionary) -> String:
	if name == "_default":
		return "_default │ 占1格·无朝向·回退用"
	var has_dirs := d.has("directions")
	var fps: float = d.get("fps", 1)
	var loop_str := "↺" if d.get("loop", true) else "→"
	if has_dirs:
		var ind_count := 0
		var mir_count := 0
		for dn in d["directions"]:
			if d["directions"][dn].has("mirror"):
				mir_count += 1
			else:
				ind_count += 1
		return "%s │ 独立:%d 镜像:%d fps:%.0f %s" % [name, ind_count, mir_count, fps, loop_str]
	else:
		var frames := d.get("frames", 1)
		return "%s │ 帧:%d fps:%.0f %s" % [name, frames, fps, loop_str]


func _make_variant_summary(name: String, d: Dictionary) -> String:
	var col: int = d.get("tile_offset", 0)
	var w: int = d.get("weight", 0)
	var tint_str := ""
	if d.has("tint") and d["tint"] != "#ffffff":
		tint_str = " tint:" + d["tint"]
	return "%s │ 偏移:%d w:%d%s" % [name, col, w, tint_str]


# ============================================================
# 信号回调
# ============================================================

func _on_png_path_changed(new_text: String) -> void:
	var base := new_text.trim_suffix(".png").trim_suffix(".PNG")
	if _atlas_json_line.text == "" or _atlas_json_line.text.begins_with(_current_json_path.get_base_dir()):
		_atlas_json_line.text = base + ".json"

func _on_browse_png() -> void:
	var fd := EditorFileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.add_filter("*.png", "PNG 图集文件")
	fd.file_selected.connect(_on_png_selected)
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.6)


func _on_png_selected(path: String) -> void:
	_atlas_png_line.text = path
	var file_name := path.get_file().trim_suffix(".png").trim_suffix(".PNG")
	_data["meta"]["name"] = file_name
	_atlas_name_line.text = file_name
	_on_png_path_changed(path)
	_update_json_preview()


func _on_dir_count_changed(value: float) -> void:
	_data["atlas"]["directions"] = int(value)
	var count := int(value)
	var existing_names: Array = _data["atlas"].get("direction_names", [])
	# 补齐或裁剪方向名数组
	while existing_names.size() < count:
		existing_names.append("")
	while existing_names.size() > count:
		existing_names.pop_back()
	_data["atlas"]["direction_names"] = existing_names
	_dir_names_line.text = ",".join(existing_names)
	_update_json_preview()


func _on_atlas_param_changed(_unused = null) -> void:
	_sync_atlas_from_ui()
	_update_effective_size_label()
	_update_json_preview()


func _on_atlas_name_changed(new_name: String) -> void:
	_data["meta"]["name"] = new_name
	_update_json_preview()


func _on_render_param_changed(_enabled: bool) -> void:
	_data["render"]["is_double_height"] = _double_height_check.button_pressed
	_update_effective_size_label()
	_update_json_preview()


func _sync_atlas_from_ui() -> void:
	_data["atlas"]["grid_size"] = [int(_grid_w_spin.value), int(_grid_h_spin.value)]
	var names_str := _dir_names_line.text.strip_edges()
	if names_str == "":
		_data["atlas"]["direction_names"] = []
	else:
		var names: Array = []
		for s in names_str.split(","):
			names.append(s.strip_edges())
		_data["atlas"]["direction_names"] = names


func _sync_atlas_to_ui() -> void:
	var atlas: Dictionary = _data["atlas"]

	# 临时阻断信号，避免批量设值时多次触发数据回写，
	# 防止加载 JSON 时 _data["render"]["is_double_height"] 被中间态覆盖
	_grid_w_spin.set_block_signals(true)
	_grid_h_spin.set_block_signals(true)
	_dir_count_spin.set_block_signals(true)
	_dir_names_line.set_block_signals(true)

	_grid_w_spin.value = atlas["grid_size"][0]
	_grid_h_spin.value = atlas["grid_size"][1]
	_dir_count_spin.value = atlas["directions"]
	var names: Array = atlas.get("direction_names", [])
	if names is Array:
		_dir_names_line.text = ",".join(names)
	else:
		_dir_names_line.text = ""
	_atlas_name_line.text = _data.get("meta", {}).get("name", "")

	_grid_w_spin.set_block_signals(false)
	_grid_h_spin.set_block_signals(false)
	_dir_count_spin.set_block_signals(false)
	_dir_names_line.set_block_signals(false)

	_update_effective_size_label()


# ============================================================
# 状态编辑
# ============================================================

func _add_state() -> void:
	_show_state_dialog("", {})


func _edit_state(state_name: String) -> void:
	if state_name == "_default":
		return  # _default 不可编辑
	if not _data["states"].has(state_name):
		return
	_show_state_dialog(state_name, _data["states"][state_name].duplicate(true))


func _remove_state() -> void:
	if _selected_state == "_default":
		return
	if _selected_state != "" and _data["states"].has(_selected_state):
		_remove_state_by_key(_selected_state)


func _remove_state_by_key(key: String) -> void:
	if key == "_default":
		return
	if _data["states"].has(key):
		_data["states"].erase(key)
		_selected_state = ""
		_recalculate_variant_offsets()
		_refresh_all_lists()
		_update_json_preview()


func _show_state_dialog(original_name: String, state_data: Dictionary) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "编辑状态" if original_name != "" else "添加状态"
	dlg.ok_button_text = "确定"
	dlg.cancel_button_text = "取消"
	add_child(dlg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	dlg.add_child(vbox)

	# 状态名称
	var name_hbox := HBoxContainer.new()
	vbox.add_child(name_hbox)
	_add_label(name_hbox, "状态名:")
	var name_line := _add_line_edit(name_hbox, original_name)

	# 朝向开关
	var use_dirs_check := CheckBox.new()
	use_dirs_check.text = "区分朝向"
	use_dirs_check.button_pressed = state_data.has("directions")
	vbox.add_child(use_dirs_check)

	# 通用参数
	var param_grid := GridContainer.new()
	param_grid.columns = 2
	param_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(param_grid)
	_add_label(param_grid, "帧数:")
	var frames_spin := _add_spin_box(param_grid, 4, 1, 99)
	_add_label(param_grid, "FPS:")
	var fps_spin := _add_spin_box(param_grid, state_data.get("fps", 6), 1, 60)
	_add_label(param_grid, "循环:")
	var loop_check := _add_check_box(param_grid, "", state_data.get("loop", true))

	# 读取现有朝向数据
	var dir_data: Dictionary = state_data.get("directions", {})
	var dir_names: Array = _data["atlas"].get("direction_names", [])
	if dir_names.size() == 0:
		dir_names = ["default"]

	# 为每个朝向确定当前模式
	# "independent" 或 {"mirror": "source_name", "flip_h": bool, "flip_v": bool}
	var dir_modes: Dictionary = {}
	var independent_dirs: Array[String] = []
	for dn: String in dir_names:
		if dir_data.has(dn):
			var dd: Dictionary = dir_data[dn]
			if dd.has("mirror"):
				dir_modes[dn] = {"mirror": dd["mirror"], "flip_h": dd.get("flip_h", false), "flip_v": dd.get("flip_v", false)}
			else:
				dir_modes[dn] = "independent"
				independent_dirs.append(dn)
		else:
			dir_modes[dn] = "independent"
			independent_dirs.append(dn)

	# 朝向配置表
	var dir_table_label := Label.new()
	dir_table_label.text = "朝向配置 (行列自动计算):"
	dir_table_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	dir_table_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(dir_table_label)

	var dir_table := VBoxContainer.new()
	vbox.add_child(dir_table)

	# 当前帧数
	var per_dir_frames: int = 4
	if dir_data.size() > 0:
		for dn in dir_data:
			per_dir_frames = dir_data[dn].get("frames", 4)
			break
	frames_spin.value = per_dir_frames

	# 布局预览 Label（先创建，lambda 引用它）
	var layout_hint := Label.new()
	layout_hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	layout_hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(layout_hint)

	# 布局预览更新函数（必须在方向表之前赋值，避免闭包捕获 null）
	var update_layout_hint: Callable = func():
		var state_index: int = _data["states"].size()
		if original_name != "":
			var keys: Array = _data["states"].keys()
			state_index = keys.find(original_name) as int
		var info := "行: 自动 (第%d行)" % state_index
		if use_dirs_check.button_pressed:
			var cols := 0
			for dn2 in dir_names:
				if dir_modes[dn2] is String and dir_modes[dn2] == "independent":
					cols += int(frames_spin.value)
			info += "  独立朝向占用列: %d" % cols
			for dn2 in dir_names:
				var m = dir_modes[dn2]
				if m is Dictionary:
					info += "  %s→%s" % [dn2, m["mirror"]]
		layout_hint.text = info

	# 为每个朝向创建一行（不重建，点击时仅就地更新可见性）
	var dir_rows: Array[Dictionary] = []
	for dn: String in dir_names:
		var mode: Variant = dir_modes[dn]
		var is_independent: bool = mode is String and mode == "independent"

		var row_hbox := HBoxContainer.new()
		dir_table.add_child(row_hbox)

		var dn_label := Label.new()
		dn_label.text = dn
		dn_label.custom_minimum_size = Vector2(40, 0)
		dn_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		row_hbox.add_child(dn_label)

		var ind_btn := Button.new()
		ind_btn.text = "独立"
		ind_btn.toggle_mode = true
		ind_btn.button_pressed = is_independent
		_style_small_button(ind_btn, Color(0.25, 0.35, 0.5) if ind_btn.button_pressed else Color(0.2, 0.2, 0.25))
		row_hbox.add_child(ind_btn)

		var mir_btn := Button.new()
		mir_btn.text = "镜像"
		mir_btn.toggle_mode = true
		mir_btn.button_pressed = not is_independent
		_style_small_button(mir_btn, Color(0.4, 0.3, 0.25) if mir_btn.button_pressed else Color(0.2, 0.2, 0.25))
		row_hbox.add_child(mir_btn)

		var mirror_src := OptionButton.new()
		for idn in independent_dirs:
			mirror_src.add_item(idn)
		if not is_independent:
			var src_name: String = mode["mirror"]
			var src_idx := independent_dirs.find(src_name)
			if src_idx >= 0:
				mirror_src.selected = src_idx
		row_hbox.add_child(mirror_src)

		var fh_check := CheckBox.new()
		fh_check.text = "H"
		if not is_independent:
			fh_check.button_pressed = mode["flip_h"]
		row_hbox.add_child(fh_check)

		var fv_check := CheckBox.new()
		fv_check.text = "V"
		if not is_independent:
			fv_check.button_pressed = mode["flip_v"]
		row_hbox.add_child(fv_check)

		mirror_src.visible = not is_independent
		fh_check.visible = not is_independent
		fv_check.visible = not is_independent

		dir_rows.append({"ind_btn": ind_btn, "mir_btn": mir_btn, "mirror_src": mirror_src, "fh_check": fh_check, "fv_check": fv_check})

		# 行索引（不变）
		var _ri := dir_rows.size() - 1

		# 刷新所有镜像来源下拉框
		var _refresh_all_mirror_src := func():
			for rd in dir_rows:
				var ob: OptionButton = rd["mirror_src"]
				ob.clear()
				for idn in independent_dirs:
					ob.add_item(idn)

		# flip 复选框变更时同步到 dir_modes
		var _sync_flip := func():
			var dname2: String = dir_names[_ri]
			var m = dir_modes[dname2]
			if m is Dictionary:
				m["flip_h"] = fh_check.button_pressed
				m["flip_v"] = fv_check.button_pressed
				update_layout_hint.call()
		fh_check.toggled.connect(func(_b): _sync_flip.call())
		fv_check.toggled.connect(func(_b): _sync_flip.call())

		# 镜像来源下拉变更时同步
		mirror_src.item_selected.connect(func(_idx: int):
			var dname2: String = dir_names[_ri]
			var m = dir_modes[dname2]
			if m is Dictionary:
				m["mirror"] = mirror_src.get_item_text(_idx)
				update_layout_hint.call()
			)

		# 独立按钮 → 互斥切换 + 就地更新
		ind_btn.toggled.connect(func(on: bool):
			_style_small_button(ind_btn, Color(0.25, 0.35, 0.5) if on else Color(0.2, 0.2, 0.25))
			if not on:
				return
			var dname2: String = dir_names[_ri]
			# 互斥：取消镜像按钮
			mir_btn.button_pressed = false
			dir_modes[dname2] = "independent"
			if not independent_dirs.has(dname2):
				independent_dirs.append(dname2)
			_refresh_all_mirror_src.call()
			dir_rows[_ri]["mirror_src"].visible = false
			dir_rows[_ri]["fh_check"].visible = false
			dir_rows[_ri]["fv_check"].visible = false
			update_layout_hint.call()
			)

		# 镜像按钮 → 互斥切换 + 就地更新
		mir_btn.toggled.connect(func(on: bool):
			_style_small_button(mir_btn, Color(0.4, 0.3, 0.25) if on else Color(0.2, 0.2, 0.25))
			if not on:
				return
			var dname2: String = dir_names[_ri]
			var r: Dictionary = dir_rows[_ri]
			# 需要至少一个独立朝向作为镜像来源
			var src_list := independent_dirs.duplicate()
			if src_list.has(dname2):
				src_list.erase(dname2)
			if src_list.size() == 0:
				# 没有可镜像的来源 → 回弹
				ind_btn.button_pressed = true
				return
			# 互斥：取消独立按钮
			ind_btn.button_pressed = false
			# 从独立列表中移除自己
			independent_dirs.erase(dname2)
			_refresh_all_mirror_src.call()
			var src_name2: String = src_list[r["mirror_src"].selected]
			dir_modes[dname2] = {"mirror": src_name2, "flip_h": r["fh_check"].button_pressed, "flip_v": r["fv_check"].button_pressed}
			r["mirror_src"].visible = true
			r["fh_check"].visible = true
			r["fv_check"].visible = true
			update_layout_hint.call()
			)

	update_layout_hint.call()

	# 帧数变更时更新预览
	frames_spin.value_changed.connect(func(_v): update_layout_hint.call())

	# 朝向开关联动
	var _sync_visibility := func():
		var use_dirs := use_dirs_check.button_pressed
		dir_table_label.visible = use_dirs
		dir_table.visible = use_dirs
	var _toggle_dirs_cb := func(_b: bool): _sync_visibility.call()
	use_dirs_check.toggled.connect(_toggle_dirs_cb)
	_sync_visibility.call()

	# 确认保存
	var _state_confirm_cb := func():
		var new_name := name_line.text.strip_edges()
		if new_name == "":
			return
		var result := Dictionary()
		result["fps"] = int(fps_spin.value)
		result["loop"] = loop_check.button_pressed

		if use_dirs_check.button_pressed:
			result["directions"] = {}
			for dn: String in dir_names:
				var mode = dir_modes[dn]
				if mode is String and mode == "independent":
					result["directions"][dn] = {"frames": int(frames_spin.value)}
				else:
					result["directions"][dn] = {
						"mirror": mode["mirror"],
						"frames": int(frames_spin.value),
						"flip_h": mode["flip_h"],
						"flip_v": mode["flip_v"]
					}
		else:
			result["frames"] = int(frames_spin.value)

		if original_name != "" and original_name != new_name:
			_dict_rename(_data["states"], original_name, new_name, result)
		else:
			_data["states"][new_name] = result
		_auto_layout_states()
		_sort_dict_alphabetically(_data["states"])
		_recalculate_variant_offsets()
		_refresh_all_lists()
		_update_json_preview()
		dlg.queue_free()
	dlg.confirmed.connect(_state_confirm_cb)

	var _state_cancel_cb := func(): dlg.queue_free()
	dlg.canceled.connect(_state_cancel_cb)
	dlg.min_size = Vector2i(380, 0)
	dlg.popup_centered_ratio(0.3)


# ============================================================
# 变体编辑
# ============================================================

func _add_variant() -> void:
	_show_variant_dialog("", {})


func _edit_variant(variant_name: String) -> void:
	if variant_name == "_default":
		return
	if not _data["variants"].has(variant_name):
		return
	_show_variant_dialog(variant_name, _data["variants"][variant_name].duplicate(true))


func _remove_variant() -> void:
	if _selected_variant != "" and _data["variants"].has(_selected_variant):
		_remove_variant_by_key(_selected_variant)


func _remove_variant_by_key(key: String) -> void:
	if key == "_default":
		return
	if _data["variants"].has(key):
		_data["variants"].erase(key)
		_selected_variant = ""
		_recalculate_variant_offsets()
		_refresh_all_lists()
		_update_json_preview()


func _show_variant_dialog(original_name: String, variant_data: Dictionary) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "编辑变体" if original_name != "" else "添加变体"
	dlg.ok_button_text = "确定"
	add_child(dlg)

	var vbox := VBoxContainer.new()
	dlg.add_child(vbox)

	var name_hbox := HBoxContainer.new()
	vbox.add_child(name_hbox)
	_add_label(name_hbox, "变体名:")
	var name_line := _add_line_edit(name_hbox, original_name)

	# 提示：偏移自动计算
	var hint := Label.new()
	hint.text = "列偏移由编辑器根据状态宽度自动计算，无需手动设置"
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)
	_add_label(grid, "随机权重 (weight):")
	var weight_spin := _add_spin_box(grid, variant_data.get("weight", 0), 0, 999)

	var tint_hbox := HBoxContainer.new()
	vbox.add_child(tint_hbox)
	_add_label(tint_hbox, "染色 (tint):")
	var tint_picker := _add_color_picker(tint_hbox, Color(variant_data.get("tint", "#ffffff")))
	tint_picker.custom_minimum_size = Vector2(60, 0)

	var _variant_confirm_cb := func():
		var new_name := name_line.text.strip_edges()
		if new_name == "":
			return
		if original_name != "" and original_name != new_name:
			_dict_rename(_data["variants"], original_name, new_name, {"tile_offset": 0, "weight": int(weight_spin.value), "tint": "#%s" % tint_picker.color.to_html(false)})
		else:
			_data["variants"][new_name] = {
				"tile_offset": 0,
				"weight": int(weight_spin.value),
				"tint": "#%s" % tint_picker.color.to_html(false)
			}
		_sort_dict_alphabetically(_data["variants"])
		_recalculate_variant_offsets()
		_refresh_all_lists()
		_update_json_preview()
		dlg.queue_free()
	dlg.confirmed.connect(_variant_confirm_cb)

	var _variant_cancel_cb := func(): dlg.queue_free()
	dlg.canceled.connect(_variant_cancel_cb)
	dlg.min_size = Vector2i(350, 0)
	dlg.popup_centered_ratio(0.3)


# ============================================================
# 叠加层编辑
# ============================================================

# ============================================================
# 变体偏移（连续流布局下恒为 0）
# ============================================================

## 自动为所有状态分配行号和列偏移
func _auto_layout_states() -> void:
	_sync_atlas_from_ui()
	var raw_names: Array = _data["atlas"].get("direction_names", [])
	if raw_names.size() == 0:
		raw_names = ["_default_"]
	var dir_names: Array[String] = []
	for dn in raw_names:
		dir_names.append(dn.strip_edges() if dn is String else str(dn))

	var grid_w: int = _data["atlas"]["grid_size"][0]
	const MAX_ATLAS_W := 1024
	var cols_per_row: int = max(1, MAX_ATLAS_W / grid_w)

	var variants: Dictionary = _data["variants"]
	var var_names: Array = variants.keys()
	if var_names.size() == 0:
		var_names = ["_default"]
		variants["_default"] = {"tile_offset": 0, "weight": 0}

	# 确保 _default 状态存在且排在首位
	if not _data["states"].has("_default"):
		_data["states"]["_default"] = {"frames": 1, "fps": 1, "loop": true}
	# 重组顺序：_default 永远首位
	var ordered_states := {"_default": _data["states"]["_default"]}
	for key in _data["states"]:
		if key != "_default":
			ordered_states[key] = _data["states"][key]
	_data["states"] = ordered_states

	# 仅以第一个变体为基准分配坐标
	var flat_index: int = 0
	for state_name: String in _data["states"]:
		var state_def: Dictionary = _data["states"][state_name]
		if state_def.has("directions"):
			for dn: String in dir_names:
				if not state_def["directions"].has(dn):
					continue
				var dd: Dictionary = state_def["directions"][dn]
				if dd.has("mirror"):
					continue
				var frames: int = dd.get("frames", 1)
				dd["row"] = flat_index / cols_per_row
				dd["start_col"] = flat_index % cols_per_row
				dd["frames"] = frames
				flat_index += frames
		else:
			var frames: int = state_def.get("frames", 1)
			state_def["row"] = flat_index / cols_per_row
			state_def["start_col"] = flat_index % cols_per_row
			state_def["frames"] = frames
			flat_index += frames

	# 镜像朝向：引用源朝向坐标
	for state_name: String in _data["states"]:
		var state_def: Dictionary = _data["states"][state_name]
		if state_def.has("directions"):
			for dn: String in dir_names:
				if state_def["directions"].has(dn):
					var dd: Dictionary = state_def["directions"][dn]
					if dd.has("mirror"):
						var src_name: String = dd["mirror"]
						if state_def["directions"].has(src_name):
							var src: Dictionary = state_def["directions"][src_name]
							dd["row"] = src.get("row", 0)
							dd["start_col"] = src.get("start_col", 0)
							dd["frames"] = src.get("frames", 1)
						else:
							dd["row"] = 0
							dd["start_col"] = 0

	# 重组方向顺序以匹配全局 dir_names
	for state_name: String in _data["states"]:
		var state_def: Dictionary = _data["states"][state_name]
		if state_def.has("directions"):
			var ordered_dirs := {}
			for dn: String in dir_names:
				if state_def["directions"].has(dn):
					ordered_dirs[dn] = state_def["directions"][dn]
			state_def["directions"] = ordered_dirs

	# 清理非动画状态的冗余字段
	for state_name: String in _data["states"]:
		var sd: Dictionary = _data["states"][state_name]
		if sd.has("directions"):
			# 有朝向：检查是否所有方向都只有 1 帧
			var all_static := true
			for dn in sd["directions"]:
				if sd["directions"][dn].get("frames", 1) > 1:
					all_static = false
					break
			if all_static:
				sd.erase("fps")
				sd.erase("loop")
				if sd["directions"].size() == 1 and dir_names.size() <= 1:
					# 仅一个朝向且无朝向区分 → 降级为 shared
					var sole: Dictionary = sd["directions"].values()[0]
					sd["row"] = sole.get("row", sd.get("row", 0))
					sd["start_col"] = sole.get("start_col", sd.get("start_col", 0))
					sd["frames"] = sole.get("frames", 1)
					sd.erase("directions")
		else:
			# 无朝向：frames=1 时去除冗余
			if sd.get("frames", 1) <= 1:
				sd.erase("frames")
				sd.erase("fps")
				sd.erase("loop")


## 每个变体计算 tile_offset（图块偏移量）
func _recalculate_variant_offsets() -> void:
	# 基于当前字典顺序重新计算 tile_offset
	var tiles_per_variant: int = _count_tiles_per_variant()
	var vi := 0
	for vn in _data["variants"]:
		_data["variants"][vn]["tile_offset"] = vi * tiles_per_variant
		vi += 1


func _count_tiles_per_variant() -> int:
	var dir_names: Array = _data["atlas"].get("direction_names", ["_"])
	var count: int = 0
	for state_name in _data["states"]:
		var sd: Dictionary = _data["states"][state_name]
		if sd.has("directions"):
			for dn in dir_names:
				if sd["directions"].has(dn):
					var dd = sd["directions"][dn]
					if dd.has("mirror"):
						continue
					count += dd.get("frames", 1)
		else:
			count += sd.get("frames", 1)
	return count


# ============================================================
# 辅助
# ============================================================

## 在 Dictionary 中重命名键，保持原有顺序
static func _dict_rename(dict: Dictionary, old_key: String, new_key: String, new_value: Variant) -> void:
	var ordered := {}
	for key in dict:
		if key == old_key:
			ordered[new_key] = new_value
		else:
			ordered[key] = dict[key]
	dict.clear()
	for key in ordered:
		dict[key] = ordered[key]


## 确保 _data 顶层键按固定顺序排列
func _reorder_top_keys() -> void:
	var fixed_order := ["version", "meta", "atlas", "states", "variants", "render"]
	var ordered := {}
	for key in fixed_order:
		if _data.has(key):
			ordered[key] = _data[key]
	_data = ordered


## 按首字母排列字典键
static func _sort_dict_alphabetically(dict: Dictionary) -> void:
	var sorted_keys := dict.keys()
	sorted_keys.sort()
	var ordered := {}
	for key in sorted_keys:
		ordered[key] = dict[key]
	dict.clear()
	for key in ordered:
		dict[key] = ordered[key]


# ============================================================
# 文件操作

func _on_new() -> void:
	_init_empty_data()
	_atlas_png_line.text = ""
	_atlas_name_line.text = ""
	_atlas_json_line.text = ""
	_current_json_path = ""
	_sync_atlas_to_ui()
	_double_height_check.button_pressed = false
	_recalculate_variant_offsets()
	_refresh_all_lists()
	_update_json_preview()


func _on_load_json() -> void:
	var fd := EditorFileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.add_filter("*.json", "JSON 图集配置")
	fd.file_selected.connect(_on_json_selected)
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.6)


func _on_json_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开文件: " + path)
		return
	var text: String = file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON 解析失败: " + path + " (行 " + str(json.get_error_line()) + ": " + json.get_error_message() + ")")
		return
	_data = json.get_data()
	_current_json_path = path

	# 同步 UI
	_atlas_json_line.text = path
	# 尝试推断 PNG 路径
	var png_path := path.trim_suffix(".json") + ".png"
	if FileAccess.file_exists(png_path):
		_atlas_png_line.text = png_path
	else:
		_atlas_png_line.text = ""
	_sync_atlas_to_ui()
	_double_height_check.button_pressed = _data.get("render", {}).get("is_double_height", false)
	_sort_dict_alphabetically(_data["states"])
	_sort_dict_alphabetically(_data["variants"])
	_auto_layout_states()
	_recalculate_variant_offsets()
	_refresh_all_lists()
	_update_json_preview()


func _on_save_json() -> void:
	var path := _atlas_json_line.text.strip_edges()
	if path == "":
		var fd := EditorFileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		fd.access = FileDialog.ACCESS_RESOURCES
		fd.add_filter("*.json", "JSON 图集配置")
		fd.file_selected.connect(_do_save_json)
		fd.canceled.connect(fd.queue_free)
		add_child(fd)
		fd.popup_centered_ratio(0.6)
		return
	_do_save_json(path)


func _do_save_json(path: String) -> void:
	_sync_atlas_from_ui()
	_data["render"]["is_double_height"] = _double_height_check.button_pressed
	_sort_dict_alphabetically(_data["states"])
	_sort_dict_alphabetically(_data["variants"])
	_auto_layout_states()
	_recalculate_variant_offsets()
	_reorder_top_keys()

	# 更新 meta name
	if _data["meta"]["name"] == "":
		var file_name := path.get_file().trim_suffix(".json")
		_data["meta"]["name"] = file_name

	var json_text := JSON.stringify(_data, "  ")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入文件: " + path)
		return
	file.store_string(json_text)
	_current_json_path = path
	_atlas_json_line.text = path
	_update_json_preview()
	print("[SpriteSheetEditor] JSON 已保存: " + path)


func _update_json_preview() -> void:
	if _json_preview:
		_sync_atlas_from_ui()
		_data["render"]["is_double_height"] = _double_height_check.button_pressed
		_sort_dict_alphabetically(_data["states"])
		_sort_dict_alphabetically(_data["variants"])
		_auto_layout_states()
		_recalculate_variant_offsets()
		_reorder_top_keys()
		_json_preview.text = JSON.stringify(_data, "  ")


func _on_generate_atlas() -> void:
	_sync_atlas_from_ui()
	_data["render"]["is_double_height"] = _double_height_check.button_pressed
	_auto_layout_states()
	_recalculate_variant_offsets()

	var png_path := _atlas_png_line.text.strip_edges()
	if png_path == "":
		# 没有 PNG 路径，用 JSON 路径推导
		var json_path := _atlas_json_line.text.strip_edges()
		if json_path == "":
			push_error("请先设置 PNG 或 JSON 路径")
			return
		png_path = json_path.trim_suffix(".json") + ".png"

	# 确保 meta name
	if _data["meta"]["name"] == "" and _atlas_json_line.text != "":
		_data["meta"]["name"] = _atlas_json_line.text.get_file().trim_suffix(".json")

	var err := AtlasGenerator.generate(_data, png_path)
	if err == OK:
		print("[SpriteSheetEditor] 空图集已生成: ", png_path)
		# 刷新文件系统以显示新 PNG
		if plugin:
			plugin.get_editor_interface().get_resource_filesystem().scan()
