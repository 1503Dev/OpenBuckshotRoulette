extends Node

var loaded_mods: Array[ModInfo] = []

func _ready() -> void:
	var all_mod_infos: Array[ModInfo] = []

	for dir_path in _get_mod_directories():
		all_mod_infos.append_array(_scan_mods_from_dir(dir_path))

	var seen: Dictionary = {}
	var merged: Array[ModInfo] = []
	for info in all_mod_infos:
		var key = info.name + "@" + info.version
		if not seen.has(key):
			seen[key] = true
			merged.append(info)

	var valid_mod_info_list: Array[ModInfo] = []

	for mod_info in merged:
		if mod_info.entry == "":
			push_error("Mod entry script path is empty for mod: " + mod_info.name)
			continue

		var script_path: String = ProjectSettings.localize_path(mod_info.dir.path_join(mod_info.entry))
		if ResourceLoader.exists(script_path):
			var mod_script = load(script_path)
			if mod_script and mod_script.can_instantiate():
				var mod_instance = mod_script.new()
				if mod_instance is BaseMod and mod_instance.has_method("_on_mod_load"):
					mod_instance.name = mod_info.name + '@' + mod_info.version
					add_child(mod_instance)
					mod_instance.call("_on_mod_load", mod_info)
					valid_mod_info_list.append(mod_info)
				else:
					push_error("Mod instance is not BaseMod or missing _on_mod_load method in mod: " + mod_info.name)
			else:
				push_error("Failed to load or instantiate mod script: " + script_path)
		else:
			push_error("Mod script path does not exist: " + script_path)

	GlobalVariables.on_mod_info_loaded.emit(valid_mod_info_list)

	if get_tree().current_scene:
		_check_and_trigger_scene_changed(get_tree().current_scene)

	get_tree().node_added.connect(_on_node_added)

func _get_mod_directories() -> Array[String]:
	var dirs: Array[String] = []

	dirs.append("user://mods/")

	var exec_dir = OS.get_executable_path().get_base_dir()
	dirs.append(exec_dir.path_join("mods"))

	if OS.has_feature("mobile"):
		dirs.append("/sdcard/open_buckshot_roulette/mods/")

	return dirs

func _scan_mods_from_dir(mods_dir_path: String) -> Array[ModInfo]:
	var result: Array[ModInfo] = []

	if not DirAccess.dir_exists_absolute(mods_dir_path):
		return result

	var dir := DirAccess.open(mods_dir_path)
	if not dir:
		push_error("Failed to open mods directory: " + mods_dir_path)
		return result

	dir.list_dir_begin()
	var sub_dir_name := dir.get_next()

	while sub_dir_name != "":
		if dir.current_is_dir() and not sub_dir_name.begins_with("."):
			var manifest_path := mods_dir_path.path_join(sub_dir_name).path_join("manifest.json")
			if FileAccess.file_exists(manifest_path):
				var file := FileAccess.open(manifest_path, FileAccess.READ)
				if file:
					var json_string := file.get_as_text()
					file.close()

					var json := JSON.new()
					var error := json.parse(json_string)
					if error == OK:
						var data = json.get_data()
						if typeof(data) == TYPE_DICTIONARY:
							var mod_info := ModInfo.new()
							mod_info.name = data.get("name", "")
							mod_info.version = data.get("version", "")
							mod_info.target = data.get("target", "")
							mod_info.entry = data.get("entry", "")
							mod_info.godot_version = Engine.get_version_info().string
							mod_info.game_version = GlobalVariables.currentVersion
							mod_info.dir = ProjectSettings.globalize_path(mods_dir_path.path_join(sub_dir_name))
							mod_info.protocol = GlobalVariables.PROTOCOL
							result.append(mod_info)
						else:
							push_error("Manifest data is not a dictionary in mod: " + sub_dir_name)
					else:
						push_error("Failed to parse manifest.json in mod: " + sub_dir_name + " Error code: " + str(error))
				else:
					push_error("Failed to open manifest.json in mod: " + sub_dir_name)
			else:
				push_error("Missing manifest.json in mod folder: " + sub_dir_name)

		sub_dir_name = dir.get_next()
	dir.list_dir_end()
	
	loaded_mods = result

	return result

func _on_node_added(node: Node) -> void:
	if node == get_tree().current_scene:
		_check_and_trigger_scene_changed(node)

func _check_and_trigger_scene_changed(scene_node: Node) -> void:
	for child in get_children():
		if child is BaseMod and child.has_method("_on_scene_changed"):
			child.call("_on_scene_changed", scene_node)
