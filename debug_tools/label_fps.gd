extends Label

@onready var label_version: Label = $Label_Version

var frames_render: int = 0
var frames_render_2: float = 0.0
var frames_physics: int = 0
var frames_physics_2: float = 0.0

var text_fps := 'Loading...'
var text_renderer3d_info := 'Loading'

var is_beta:= false

func _physics_process(delta: float) -> void:
	frames_physics += 1
	frames_physics_2 = 1.0 / delta
	
func _process(delta: float) -> void:
	frames_render += 1
	frames_render_2 = 1.0 / delta

func _on_timer_fps_timeout() -> void:
	text_fps = str(frames_render) + '/' + str("%.2f" % frames_render_2) + 'r, ' + str(frames_physics) + '/' + str("%.2f" % frames_physics_2) + 'p'
	frames_physics = 0
	frames_render = 0
	
	text = 'FPS: ' + text_fps
	if is_beta || DebugTools.DEBUG_TOOLS_ENABLED:
		var renderer_name = RenderingServer.get_video_adapter_name()
		var v_size = get_viewport().get_visible_rect().size
		var render_scale = get_viewport().scaling_3d_scale
		var engine_method = RenderingServer.get_video_adapter_api_version()
		text_renderer3d_info = renderer_name + ', ' + engine_method + ', v-size: ' + str(v_size) + ', scale: ' + str(render_scale)
		text = text + '\nRenderer3D: ' + text_renderer3d_info

func _ready() -> void:
	is_beta = GlobalVariables.currentVersion_nr.contains('beta')
	label_version.text = 'Open Buckshot Roulette ' + GlobalVariables.currentVersion
