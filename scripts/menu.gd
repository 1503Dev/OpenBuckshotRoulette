extends Node3D
@onready var viewblocker_parent: Control = $"Camera/dialogue UI/viewblocker parent"
@onready var posterization_test: Control = $"Camera/post processing/posterization test"
@onready var sub_options_select: Control = $"Camera/dialogue UI/menu ui/sub options select"
@onready var main_screen: Control = $"Camera/dialogue UI/menu ui/main screen"
@onready var options_audio_video: Control = $"Camera/dialogue UI/menu ui/options_audio video"
@onready var options_controller: Control = $"Camera/dialogue UI/menu ui/options_controller"
@onready var credits: Control = $"Camera/dialogue UI/menu ui/credits"
@onready var language: Control = $"Camera/dialogue UI/menu ui/language"
@onready var controller_rebinding: Control = $"Camera/dialogue UI/menu ui/controller rebinding"
@onready var mouse_blocker: Control = $"Camera/dialogue UI/menu ui/mouse blocker"
@onready var control_main_options: Control = $"Camera/dialogue UI/menu ui/main screen/Control_MainOptions"
@onready var options_online_service: Control = $"Camera/dialogue UI/menu ui/options_online service"
@onready var button_class_pause_server_address: ButtonClass = $"Camera/dialogue UI/menu ui/options_online service/Control/Label/Label_ServerAddress/Label/true button/button class_pause server address"
@onready var options_manager: OptionsManager = $"standalone managers/options manager"
@onready var label_server_address: Label = $"Camera/dialogue UI/menu ui/options_online service/Control/Label/Label_ServerAddress"
@onready var button_class_reconnect_to_ws: ButtonClass = $"Camera/dialogue UI/menu ui/options_online service/Control/Label2/Label_ConnectionStatus/Label/true button/button class_reconnect_to_ws"
@onready var label_connection_status: Label = $"Camera/dialogue UI/menu ui/options_online service/Control/Label2/Label_ConnectionStatus"
@onready var label_max_fps_value: Label = $"Camera/dialogue UI/menu ui/options_audio video/Label_MaxFPS/Label_MaxFPS_Value"
@onready var label_performance_level_value: Label = $"Camera/dialogue UI/menu ui/options_audio video/Label_PerformanceLevel/Label_PerformanceLevel_Value"
@onready var shell_waterfall_2: Node3D = $"shell waterfall2"
@onready var shell_waterfall_4: Node3D = $"shell waterfall4"
@onready var button_class_pause_user_name: ButtonClass = $"Camera/dialogue UI/menu ui/options_online service/Control/Label3/Label_UserName/Label/true button/button class_pause user name"
@onready var label_user_name: Label = $"Camera/dialogue UI/menu ui/options_online service/Control/Label3/Label_UserName"

@onready var hide_on_android: Array[Node] = [
	$"Camera/dialogue UI/menu ui/options_audio video/option monitor_windowed", $"Camera/dialogue UI/menu ui/options_audio video/option monitor_fullscreen", $"Camera/dialogue UI/menu ui/options_audio video/bracket selection_windowed", $"Camera/dialogue UI/menu ui/options_audio video/bracket selection_fullscreen", $"Camera/dialogue UI/menu ui/options_audio video/true button_windowed", $"Camera/dialogue UI/menu ui/options_audio video/true button_fullscreen"
]

var max_fps_values := [10, 20, 30, 45, 60, 90, 120, 144, 240, 0]

func _ready() -> void:
	GlobalVariables.set_tree(self )
	viewblocker_parent.show()
	control_main_options.show()
	sub_options_select.hide()
	main_screen.show()
	options_audio_video.hide()
	options_controller.hide()
	options_online_service.hide()
	credits.hide()
	language.hide()
	if (OS.has_feature("mobile")):
		for item in hide_on_android:
			item.hide()
	GlobalVariables.on_button_class_interact.connect(_on_button_class_interact)

	bind_events()
	if DebugTools.DEBUG_TOOLS_ENABLED && DebugTools.SKIP_SPLASH_ANIM:
		viewblocker_parent.hide()
		mouse_blocker.hide()
		$"standalone managers/cursor manager".SetCursor(true, false)
	NeoSettings.connect('value_changed', update_performance_options)
	update_performance_options()
	init_username()

func bind_events():
	button_class_pause_server_address.connect("is_pressed", _on_button_class_pause_server_address_is_pressed)
	button_class_reconnect_to_ws.connect('is_pressed', _on_button_class_reconnect_to_ws_is_pressed)

func update_performance_options(_key: String = "", _value: Variant = null):
	posterization_test.visible = NeoSettings.fetch("performance/ambient_filter_enabled", true)

	var max_fps:int = NeoSettings.fetch("performance/max_fps", 0)
	if max_fps == 0:
		label_max_fps_value.text = 'UNLIMITED'
	else:
		label_max_fps_value.text = str(max_fps)
	Engine.max_fps =  max_fps

	var performance_level:int = NeoSettings.fetch("performance/level", 0)
	label_performance_level_value.text = str(performance_level)
	if performance_level >= 1:
		shell_waterfall_2.show()
		shell_waterfall_4.show()
	if performance_level >= 2:
		shell_waterfall_4.show()
		shell_waterfall_2.hide()
	if performance_level >= 3:
		shell_waterfall_4.hide()
	if performance_level <= 0:
		shell_waterfall_2.show()
		shell_waterfall_4.show()

func init_username() -> void:
	var saved_name = NeoSettings.fetch("multiplayer/username", "")
	if saved_name == "":
		saved_name = _generate_random_name()
		NeoSettings.put("multiplayer/username", saved_name)
	GlobalSteam.STEAM_NAME = saved_name
	update_user_name_label()

func _generate_random_name() -> String:
	var length = randi() % 5 + 6
	var mName = ""
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for i in range(length):
		mName += chars[randi() % chars.length()]
	return mName

func _open_mods_folder() -> void:
	var mods_path: String
	if OS.has_feature("mobile"):
		OS.request_permissions()
		mods_path = "/sdcard/open_buckshot_roulette/mods/"
	else:
		mods_path = ProjectSettings.globalize_path("user://mods/")
	if not DirAccess.dir_exists_absolute(mods_path):
		DirAccess.make_dir_absolute(mods_path)
	OS.shell_open(mods_path)

func get_text_from_clipboard() -> String:
	var text = DisplayServer.clipboard_get()
	return text.strip_edges()

func is_valid_ws_url(url: String) -> bool:
	var lower = url.to_lower()
	
	if not (lower.begins_with("ws://") or lower.begins_with("wss://")):
		return false
	if not (url.contains(".") and url.count(":") >= 2):
		return false
	
	var address_part = url.split("//")[1]
	if address_part.ends_with(":") or " " in address_part:
		return false
	var parts = address_part.split(":")
	if parts.size() > 1:
		var port_str = parts[-1].split("/")[0]
		if not port_str.is_valid_int():
			return false
			
	return true

func _on_button_class_pause_server_address_is_pressed():
	var text = get_text_from_clipboard()
	if is_valid_ws_url(text):
		options_manager.setting_server_address = text
		options_manager.SaveSettings()
		update_server_address_label()

func update_server_address_label():
	label_server_address.text = Steam.server_address

func _on_button_class_reconnect_to_ws_is_pressed():
	GlobalSteam.connect_to_server()

func _process(_delta: float) -> void:
	if options_online_service.visible:
		var state = GlobalSteam.ws_peer.get_ready_state()
		
		if state == WebSocketPeer.STATE_OPEN:
			label_connection_status.text = 'CONNECTED'
		elif state == WebSocketPeer.STATE_CONNECTING:
			label_connection_status.text = 'CONNECTING'
		else:
			label_connection_status.text = 'DISCONNECTED'

func _copy_runtime_info() -> void:
	var lines: PackedStringArray = []
	lines.append("[RUNTIME INFO]")
	lines.append("GlobalVariables.currentVersion_nr = %s" % GlobalVariables.currentVersion_nr)
	lines.append("GlobalVariables.PROTOCOL = %s" % GlobalVariables.PROTOCOL)
	lines.append("OS.distribution_name = %s" % OS.get_distribution_name())
	lines.append("OS.granted_permissions = %s" % _serialize_variant(OS.get_granted_permissions()))
	lines.append("OS.locale = %s" % OS.get_locale())
	lines.append("OS.memory_info = %s" % _serialize_variant(OS.get_memory_info()))
	lines.append("OS.model_name = %s" % OS.get_model_name())
	lines.append("OS.name = %s" % OS.get_name())
	lines.append("OS.processor_count = %s" % OS.get_processor_count())
	lines.append("OS.processor_name = %s" % OS.get_processor_name())
	lines.append("OS.static_memory_peak_usage = %s" % OS.get_static_memory_peak_usage())
	lines.append("OS.static_memory_usage = %s" % OS.get_static_memory_usage())
	lines.append("OS.version = %s" % OS.get_version())
	lines.append("OS.version_alias = %s" % OS.get_version_alias())
	lines.append("OS.video_adapter_driver_info = %s" % _serialize_variant(OS.get_video_adapter_driver_info()))
	lines.append("OS.is_userfs_persistent = %s" % OS.is_userfs_persistent())
	lines.append("DisplayServer.name = %s" % DisplayServer.get_name())
	lines.append("DisplayServer.screen_count = %s" % DisplayServer.get_screen_count())
	lines.append("RenderingServer.current_rendering_driver_name = %s" % RenderingServer.get_current_rendering_driver_name())
	lines.append("RenderingServer.current_rendering_method = %s" % RenderingServer.get_current_rendering_method())
	lines.append("RenderingServer.frame_setup_time_cpu = %s" % RenderingServer.get_frame_setup_time_cpu())
	var rd = RenderingServer.get_rendering_device()
	if rd:
		lines.append("RenderingServer.rendering_device = [RenderingDevice]{")
		lines.append("    device_name = %s" % rd.get_device_name())
		lines.append("    device_total_memory = %s" % rd.get_device_total_memory())
		lines.append("    device_vendor_name = %s" % rd.get_device_vendor_name())
		lines.append("}")
	else:
		lines.append("RenderingServer.rendering_device = null")
	lines.append("RenderingServer.video_adapter_api_version = %s" % RenderingServer.get_video_adapter_api_version())
	lines.append("RenderingServer.video_adapter_name = %s" % RenderingServer.get_video_adapter_name())
	var adapter_type = RenderingServer.get_video_adapter_type()
	var type_names = {
		RenderingDevice.DEVICE_TYPE_OTHER: "DEVICE_TYPE_OTHER",
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU: "DEVICE_TYPE_INTEGRATED_GPU",
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: "DEVICE_TYPE_DISCRETE_GPU",
		RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU: "DEVICE_TYPE_VIRTUAL_GPU",
		RenderingDevice.DEVICE_TYPE_CPU: "DEVICE_TYPE_CPU",
	}
	lines.append("RenderingServer.video_adapter_type = %s" % type_names.get(adapter_type, "DEVICE_TYPE_OTHER"))
	lines.append("RenderingServer.video_adapter_vendor = %s" % RenderingServer.get_video_adapter_vendor())
	lines.append("Engine.architecture_name = %s" % Engine.get_architecture_name())
	lines.append("Engine.is_editor_hint = %s" % Engine.is_editor_hint())
	lines.append("ModLoader.loaded_mods = %s" % _serialize_variant(ModLoader.loaded_mods))
	DisplayServer.clipboard_set("\n".join(lines))

func _serialize_variant(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return str(value)
		TYPE_STRING:
			return "\"%s\"" % value
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var parts: PackedStringArray = []
			parts.append("[Dictionary]{")
			for key in dict:
				parts.append("    %s = %s" % [str(key), _serialize_variant(dict[key])])
			parts.append("}")
			return "\n".join(parts)
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			var arr = value
			var parts: PackedStringArray = []
			parts.append("[%s]{" % _get_type_name(typeof(value)))
			for i in arr.size():
				parts.append("    [%s] = %s" % [i, _serialize_variant(arr[i])])
			parts.append("}")
			return "\n".join(parts)
		_:
			if value is Object:
				if value is ModInfo:
					var parts: PackedStringArray = []
					parts.append("[ModInfo]{")
					parts.append("    name = %s" % _serialize_variant(value.name))
					parts.append("    version = %s" % _serialize_variant(value.version))
					parts.append("    target = %s" % _serialize_variant(value.target))
					parts.append("    entry = %s" % _serialize_variant(value.entry))
					parts.append("}")
					return "\n".join(parts)
				return "[%s]{%s}" % [value.get_class(), "\n    (object instance)\n"]
			return str(value)

func _get_type_name(type: int) -> String:
	match type:
		TYPE_NIL:
			return "nil"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "String"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR2I:
			return "Vector2i"
		TYPE_RECT2:
			return "Rect2"
		TYPE_RECT2I:
			return "Rect2i"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_VECTOR3I:
			return "Vector3i"
		TYPE_TRANSFORM2D:
			return "Transform2D"
		TYPE_VECTOR4:
			return "Vector4"
		TYPE_VECTOR4I:
			return "Vector4i"
		TYPE_PLANE:
			return "Plane"
		TYPE_QUATERNION:
			return "Quaternion"
		TYPE_AABB:
			return "AABB"
		TYPE_BASIS:
			return "Basis"
		TYPE_TRANSFORM3D:
			return "Transform3D"
		TYPE_PROJECTION:
			return "Projection"
		TYPE_COLOR:
			return "Color"
		TYPE_STRING_NAME:
			return "StringName"
		TYPE_NODE_PATH:
			return "NodePath"
		TYPE_RID:
			return "RID"
		TYPE_OBJECT:
			return "Object"
		TYPE_DICTIONARY:
			return "Dictionary"
		TYPE_ARRAY:
			return "Array"
		TYPE_PACKED_BYTE_ARRAY:
			return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY:
			return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY:
			return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY:
			return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY:
			return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY:
			return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY:
			return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY:
			return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY:
			return "PackedColorArray"
		TYPE_PACKED_VECTOR4_ARRAY:
			return "PackedVector4Array"
	return "Variant"

func _on_button_class_interact(alias: String):
	if alias.begins_with('max fps'):
		var current_fps:int = NeoSettings.fetch("performance/max_fps", 0)
		var current_index:int = max_fps_values.find(current_fps)
		if (current_index == -1):
			current_index = max_fps_values.size() - 1
		if (alias == 'max fps reduce'):
			if (current_index > 0): 
				current_index -= 1
		elif (alias == 'max fps plus'):
			if (current_index < max_fps_values.size() - 1): 
				current_index += 1
		current_fps = max_fps_values[current_index]
		NeoSettings.put("performance/max_fps", current_fps)
	elif alias == 'performance level reduce':
		NeoSettings.decrease("performance/level", 1, 0)
	elif alias == 'performance level plus':
		NeoSettings.increase("performance/level", 1, 3)
	elif alias == 'open mods folder':
		_open_mods_folder()
	elif alias == 'copy runtime info':
		_copy_runtime_info()
	elif alias == 'gitee':
		OS.shell_open(GlobalVariables.gitee_link)


func _on_button_class_pause_user_name_is_pressed() -> void:
	var text = get_text_from_clipboard()
	if text.length() <= 24 && text.length() >= 1:
		NeoSettings.put("multiplayer/username", text)
		GlobalSteam.STEAM_NAME = text
		update_user_name_label()

func update_user_name_label():
	label_user_name.text = NeoSettings.fetch("multiplayer/username", GlobalSteam.STEAM_NAME)
