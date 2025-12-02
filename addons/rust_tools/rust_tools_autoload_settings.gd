@tool

class_name RustToolsAutoloadSettings
extends VBoxContainer

###############################################################################
# Properties                                                                 #
###############################################################################

# Signals

# Enums

# Constants
const NAME_COLUMN := 0
const CLASS_COLUMN := 1
const SOURCE_COLUMN := 2
const EXPORT_DECL_COLUMN := 3
const ENABLED_COLUMN := 4
const SCENE_PATH_COLUMN := 5

# Export Variables

# Private Variables

# Onready Variables
@onready var tree := $Tree


###############################################################################
# Builtin functions                                                           #
###############################################################################
func _ready() -> void:
	tree.accessibility_name = TranslationServer.translate(&"Rust Tools Autoloads")

	tree.set_column_title(NAME_COLUMN, TranslationServer.translate(&"Name"))
	tree.set_column_title_alignment(NAME_COLUMN, HORIZONTAL_ALIGNMENT_LEFT)
	tree.set_column_expand(NAME_COLUMN, true)
	tree.set_column_expand_ratio(NAME_COLUMN, 1)

	tree.set_column_title(CLASS_COLUMN, TranslationServer.translate(&"Class"))
	tree.set_column_title_alignment(CLASS_COLUMN, HORIZONTAL_ALIGNMENT_LEFT)
	tree.set_column_expand(CLASS_COLUMN, true)
	tree.set_column_expand_ratio(CLASS_COLUMN, 1)

	tree.set_column_title(SOURCE_COLUMN, TranslationServer.translate(&"Source"))
	tree.set_column_title_alignment(SOURCE_COLUMN, HORIZONTAL_ALIGNMENT_LEFT)
	tree.set_column_expand(SOURCE_COLUMN, true)
	tree.set_column_expand_ratio(SOURCE_COLUMN, 1)

	tree.set_column_title(EXPORT_DECL_COLUMN, TranslationServer.translate(&"Path declaration"))
	tree.set_column_title_alignment(EXPORT_DECL_COLUMN, HORIZONTAL_ALIGNMENT_LEFT)
	tree.set_column_expand(EXPORT_DECL_COLUMN, true)
	tree.set_column_expand_ratio(EXPORT_DECL_COLUMN, 1)

	tree.set_column_title(ENABLED_COLUMN, TranslationServer.translate(&"Codegen"))
	tree.set_column_expand(ENABLED_COLUMN, true)
	tree.set_column_expand_ratio(ENABLED_COLUMN, 1)
	tree.set_column_title_alignment(ENABLED_COLUMN, HORIZONTAL_ALIGNMENT_LEFT)

	tree.set_column_title(SCENE_PATH_COLUMN, TranslationServer.translate(&"Scene path"))
	tree.set_column_title_alignment(SCENE_PATH_COLUMN, HORIZONTAL_ALIGNMENT_LEFT)
	tree.set_column_expand(SCENE_PATH_COLUMN, false)
	#tree.set_column_expand_ratio(SCENE_PATH_COLUMN, 1)
	tree.item_edited.connect(_autoload_edited)

	update_autoloads()


###############################################################################
# Public functions                                                            #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################


func _default_extension_decl(autoload_class: String) -> String:
	return "crate::{autoload_class}".format({autoload_class = autoload_class})


func _default_builtin_decl(autoload_class: String) -> String:
	return "godot::obj::{autoload_class}".format({autoload_class = autoload_class})


func get_autoload_class(autoload_path: String) -> String:
	var autoload_scene: PackedScene = ResourceLoader.load(autoload_path)
	var state: SceneState = autoload_scene.get_state()
	return state.get_node_type(0)


func update_autoloads() -> void:
	tree.clear()
	var exsisting_config: Dictionary = ProjectSettings.get_setting(
		RustToolsSettings.AUTOLOADS_CONFIG
	)
	var leftover_entries: Dictionary = exsisting_config.duplicate_deep()
	var root: TreeItem = tree.create_item()

	for property_info in ProjectSettings.get_property_list():
		if not property_info["name"].begins_with("autoload/"):
			continue

		var autoload_name: String = property_info["name"].get_slice("/", 1)
		if autoload_name.is_empty():
			continue

		var autoload_path: String = ProjectSettings.get(property_info["name"])

		# Autoloads not marked with `*` shouldn't be globally accessible.
		if not autoload_path.begins_with("*"):
			continue

		# Not supported yet.
		if autoload_path.contains(".gd"):
			continue

		autoload_path = autoload_path.substr(1)
		var autoload_class: String = get_autoload_class(autoload_path)
		var current_config: Variant = exsisting_config.get(autoload_name)

		if current_config and current_config.get(CLASS_COLUMN, "") == autoload_class:
			leftover_entries.erase(autoload_name)
		else:
			current_config = null

		var tree_item: TreeItem = tree.create_item(root)

		tree_item.set_text(NAME_COLUMN, autoload_name)

		tree_item.set_text(SCENE_PATH_COLUMN, ResourceUID.ensure_path(autoload_path))
		tree_item.set_selectable(SCENE_PATH_COLUMN, true)

		tree_item.set_text(CLASS_COLUMN, autoload_class)
		tree_item.set_selectable(CLASS_COLUMN, true)

		var source: String
		match ClassDB.class_get_api_type(autoload_class):
			ClassDB.APIType.API_CORE or ClassDB.APIType.API_EDITOR:
				source = "Core"
				tree_item.set_text(EXPORT_DECL_COLUMN, _default_builtin_decl(autoload_class))
			_:
				source = "Extension"
				if current_config:
					tree_item.set_text(
						EXPORT_DECL_COLUMN,
						current_config.get(
							EXPORT_DECL_COLUMN, _default_extension_decl(autoload_class)
						)
					)
				else:
					tree_item.set_text(EXPORT_DECL_COLUMN, _default_extension_decl(autoload_class))

		tree_item.set_editable(EXPORT_DECL_COLUMN, true)
		tree_item.set_text(SOURCE_COLUMN, source)

		var enabled: bool
		if current_config:
			enabled = current_config.get(ENABLED_COLUMN, false)
		else:
			enabled = false

		tree_item.set_cell_mode(ENABLED_COLUMN, TreeItem.CELL_MODE_CHECK)
		tree_item.set_editable(ENABLED_COLUMN, true)
		tree_item.set_checked(ENABLED_COLUMN, enabled)
		tree_item.set_text(ENABLED_COLUMN, TranslationServer.translate(&"Enable"))

	if leftover_entries.keys().size() == 0:
		return

	for key: String in leftover_entries.keys():
		exsisting_config.erase(key)

	ProjectSettings.set_setting(RustToolsSettings.AUTOLOADS_CONFIG, exsisting_config)


func _update_autoload(tree_item: TreeItem) -> void:
	var autoload_name: String = tree_item.get_text(NAME_COLUMN)
	var autoloads_config: Dictionary = ProjectSettings.get_setting(
		RustToolsSettings.AUTOLOADS_CONFIG
	)
	autoloads_config[autoload_name] = {
		ENABLED_COLUMN: tree_item.is_checked(ENABLED_COLUMN),
		CLASS_COLUMN: tree_item.get_text(CLASS_COLUMN),
		EXPORT_DECL_COLUMN: tree_item.get_text(EXPORT_DECL_COLUMN)
	}
	ProjectSettings.set_setting(RustToolsSettings.AUTOLOADS_CONFIG, autoloads_config)


###############################################################################
# Connections                                                                 #
###############################################################################


func _autoload_edited() -> void:
	var tree_item: TreeItem = tree.get_edited()
	if not tree_item:
		return
	var column: int = tree.get_edited_column()
	match column:
		ENABLED_COLUMN:
			_update_autoload(tree_item)
		EXPORT_DECL_COLUMN:
			_update_autoload(tree_item)
