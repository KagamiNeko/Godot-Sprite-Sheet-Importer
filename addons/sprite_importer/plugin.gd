@tool
extends EditorPlugin
## Sprite Sheet Importer 插件入口
##
## 注册编辑器侧边停靠面板，提供图集 JSON 配置工具。


const SpriteSheetEditorClass = preload("res://addons/sprite_importer/sprite_sheet_editor.gd")
const SpriteImportPluginClass = preload("res://addons/sprite_importer/import_plugin.gd")

var _dock: Control = null
var _import_plugin: EditorImportPlugin = null


func _enter_tree() -> void:
	_dock = SpriteSheetEditorClass.new()
	_dock.name = "Sprite Importer"
	_dock.plugin = self
	_dock.custom_minimum_size = Vector2(350, 400)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UR, _dock)

	_import_plugin = SpriteImportPluginClass.new()
	if _import_plugin:
		add_import_plugin(_import_plugin)
		print("[SpriteImporter] 导入插件已注册")
	else:
		printerr("[SpriteImporter] 导入插件创建失败")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _import_plugin:
		remove_import_plugin(_import_plugin)
		_import_plugin = null
