class_name MP_InteractionManager extends Node

@export var description : MP_DescriptionManager
@export var properties : MP_UserInstanceProperties
@export var cursor : MP_CursorManager
@export var mouseRay : MP_MouseRaycast
@export var item_interaction : MP_ItemInteraction
@export var shotgun : MP_ShotgunInteraction

var activeInteractionBranch
var checking = true
var intermediary : MP_InteractionIntermed

var fps := 60

func _ready() -> void:
	intermediary = get_node("/root/mp_main/standalone managers/interactions/interaction intermediary")

func _process(delta: float) -> void:
	if !properties.is_active:
		return
	fps = int(1.0 / delta)
	CheckIfHovering()
	UpdateRaycastState()
	if !properties.camera_look.looking_active && properties.major_permission_enabled:
		CheckPickupLerp()
		CheckInteractionBranch()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if properties.is_active && !properties.camera_look.looking_active && properties.major_permission_enabled:
			MainInteractionEvent()

func MainInteractionEvent() -> void:
	if !properties.is_active:
		return
	SyncPhysicsImmediate()
	var wait_time = -0.00335 * fps + 0.217
	wait_time = max(wait_time, 0)
	await GlobalVariables.tree.create_timer(wait_time).timeout
	
	if activeInteractionBranch != null && activeInteractionBranch.interactionAllowed && !activeInteractionBranch.interactionInvalid:
		var parent = activeInteractionBranch.get_parent()
		var childArray = parent.get_children()
		for child in childArray:
			if child is MP_PickupIndicator:
				if child.snapping_to_max: child.SnapToMax()
				if child.snapping_to_min: child.SnapToMin()
		
		InteractWith(activeInteractionBranch.interactionAlias, activeInteractionBranch)

func SyncPhysicsImmediate() -> void:
	if mouseRay.has_method("force_raycast_update"):
		mouseRay.force_raycast_update()
	
	if mouseRay.has_method("UpdateResult"):
		mouseRay.UpdateResult()
		
	UpdateRaycastState()
	CheckInteractionBranch()
	CheckIfHovering()

func UpdateRaycastState() -> void:
	if mouseRay.result != null && mouseRay.result.has("collider"):
		var collider = mouseRay.result.collider
		if is_instance_valid(collider):
			intermediary.intermed_activeParent = collider.get_parent()
		else:
			intermediary.intermed_activeParent = null
	else:
		intermediary.intermed_activeParent = null

func CheckInteractionBranch() -> void:
	var isFound = null
	if !properties.major_permission_enabled: 
		activeInteractionBranch = null
		return
		
	if intermediary.intermed_activeParent != null:
		var childArray = intermediary.intermed_activeParent.get_children()
		for child in childArray:
			if child is MP_InteractionBranch:
				isFound = child
				break
	activeInteractionBranch = isFound

func InteractWith(alias : String, branch : MP_InteractionBranch = null) -> void:
	if alias != "inspect mesh": description.EndLerp()
	match alias:
		"shotgun": shotgun.PickupShotgun()
		"hover pan object": shotgun.Shoot(activeInteractionBranch)
		"item grid": properties.item_manager.PlaceItemRequest(branch.grid_index)
		"item briefcase intake": properties.item_manager.GrabItemRequest()
		"item": item_interaction.InteractWithItemRequest(branch.get_parent(), properties.is_stealing_item)
		"jammer button":
			var jammer_button = branch.get_parent().get_child(0)
			if jammer_button.has_method("Press"): jammer_button.Press()

func CheckIfHovering() -> void:
	if !properties.major_permission_enabled || properties.is_interacting_with_item:
		cursor.SetCursorImage("point")
		return
		
	if activeInteractionBranch != null && activeInteractionBranch.interactionAllowed:
		if !activeInteractionBranch.interactionInvalid && !activeInteractionBranch.interactionInspecting:
			cursor.SetCursorImage("hover")
		elif activeInteractionBranch.interactionInvalid:
			cursor.SetCursorImage("invalid")
		elif activeInteractionBranch.interactionInspecting:
			cursor.SetCursorImage("eye")
	else:
		cursor.SetCursorImage("point")

func CheckPickupLerp() -> void:
	UpdateRaycastState()
