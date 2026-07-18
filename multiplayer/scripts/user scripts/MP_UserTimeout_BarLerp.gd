class_name MP_UserTimeout_BarLerp extends Node

@export var assigned_type : String
@export var assigned_name : String
@export var scale_start : Vector3
@export var scale_end : Vector3

var mesh : Node3D
var duration
var elapsed
var moving

func _ready():
	mesh = get_parent()
	ResetToDefault()

func _process(_delta: float) -> void:
	Lerp()

func ResetToDefault():
	match assigned_name:
		"divider bar":
			ResetLerp()
		"vertical counter bar":
			SetScaleToMinimum()
		"item briefcase bar":
			SetScaleToMinimum()
		"jammer bar":
			SetScaleToMinimum()

func StartLerp(with_duration : float):
	moving = false
	elapsed = 0
	duration = with_duration
	moving = true

func EndLerp():
	moving = false

func ResetLerp():
	mesh.scale = scale_start

func SetScaleToMinimum():
	mesh.scale = scale_end

func Lerp():
	if moving:
		elapsed += get_process_delta_time()
		var c = clampf(elapsed / duration, 0.0, 1.0)
		var new_scale = lerp(scale_start, scale_end, c)
		mesh.scale = new_scale
