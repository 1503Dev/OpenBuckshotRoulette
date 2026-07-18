class_name MP_GameStateManager extends Node

@export var packets : PacketManager
@export var instance_handler : MP_UserInstanceHandler
@export var round_manager : MP_RoundManager
@export var turn_order : MP_TurnOrder
@export var skipping_intro : bool
@export var MAIN_timeout_duration_item_distribution : float
@export var MAIN_timeout_duration_turn : float
@export var MAIN_timeout_duration_adrenaline : float
@export var MAIN_timeout_duration_jammer : float
@export var MAIN_timeout_duration_shotgun_target_selection : float
@export var MAIN_sequence_visible_duration : float
@export var MAIN_item_resource_array : Array[MP_ItemResource]
@export var MAIN_sequence_batch_array_for_2 : Array[MP_SequenceBatchResource]
@export var MAIN_sequence_batch_array_for_3 : Array[MP_SequenceBatchResource]
@export var MAIN_sequence_batch_array_for_4 : Array[MP_SequenceBatchResource]
var MAIN_active_sequence_batch_array_copy_in_use_for_2 : Array[MP_SequenceBatchResource]
var MAIN_active_sequence_batch_array_copy_in_use_for_3 : Array[MP_SequenceBatchResource]
var MAIN_active_sequence_batch_array_copy_in_use_for_4 : Array[MP_SequenceBatchResource]

var MAIN_active_round_dict : Dictionary
var MAIN_active_sequence_dict : Dictionary
var MAIN_active_sequence_dict_send : Dictionary
var MAIN_shooter_shell : String
var MAIN_shell_to_eject : String
var MAIN_sequence_length_on_outcome : int
var MAIN_phone_verbal_shell : String
var MAIN_phone_verbal_index : int
var MAIN_active_first_turn_socket : int
var MAIN_active_turn_order : String = "CW"
var MAIN_active_round_index : int = -1
var MAIN_active_current_main_round_index : int
var MAIN_active_current_sub_round_index : int
var MAIN_active_current_turn_socket : int = 5
var MAIN_active_num_of_items_to_grab : int = 0
var MAIN_active_num_of_users_grabbing_items : int = 0
var MAIN_active_num_of_users_finished_item_grabbing : int = 0
var MAIN_active_socket_inventories_to_clear = []
var MAIN_active_first_socket_to_die : int = -1
var MAIN_active_checking_for_first_death : bool
var MAIN_active_running_intro : bool = true
var MAIN_active_match_result_statistics : Dictionary = {}
var MAIN_active_user_id_to_ignore_timeout_packets_array : Array[int]
var MAIN_active_user_id_exceeded_adrenaline_timeout_array : Array[int]
var MAIN_active_user_id_exceeded_secondary_timeout_array : Array[int]
var MAIN_active_user_id_exceeded_turn_timeout_array : Array[int]
var MAIN_active_timeout_packet_id_array : Array[int] = [10, 12, 15, 17, 19, 22, 24]
var MAIN_active_environmental_event : String = ""
var MAIN_item_grabbing_in_progress : bool
var MAIN_active_sequence_index_to_pull = 0
var MAIN_is_start_of_new_round : bool
var MAIN_shotgun_loading_in_progress : bool
var MAIN_running_win_routine : bool

var MAIN_inventory_by_socket = []
# socket 0: [{  }, {  }, {  }, {  }, {  }, {  }, {  }, {  }]
# socket 1: [{  }, {  }, {  }, {  }, {  }, {  }, {  }, {  }]
# socket 2: [{  }, {  }, {  }, {  }, {  }, {  }, {  }, {  }]
# socket 3: [{  }, {  }, {  }, {  }, {  }, {  }, {  }, {  }]
# MAIN_inventory_by_socket[socket_number][local_grid_index]
#var dict = {
#	"item_name" = item name,
#	"item_instance" = item parent object,
#	"item_id" = item id,
#}
var global_item_count_on_table_by_id = []

var MAIN_shell_visible_to_eject : String
var MAIN_barrel_sawed_off = false

func _ready():
	MAIN_active_running_intro = !skipping_intro
	SetupInventory()
	MakeSequenceCopies()
	SetupEmptyGlobalItemCount()
	if GlobalVariables.exiting_to_lobby_after_inactivity:
		pinging_mouse_pos = true
		PingMousePosition()
	await GlobalVariables.tree.create_timer(5, false).timeout

func _process(_delta: float) -> void:
	if GlobalVariables.exiting_to_lobby_after_inactivity:
		CountInactivity()

func SetupEmptyGlobalItemCount():
	global_item_count_on_table_by_id = []
	for item_id in 11:
		global_item_count_on_table_by_id.append(0)

func RebuildItemCountsFromInventory():
	SetupEmptyGlobalItemCount()
	for property in instance_handler.instance_property_array:
		property.CLearInventory_Count()
		property.unplaced_reserved_item_id = -1
	for socket_number in range(MAIN_inventory_by_socket.size()):
		var socket_properties : MP_UserInstanceProperties = GetSocketProperties(socket_number)
		for local_grid_index in range(MAIN_inventory_by_socket[socket_number].size()):
			var dict = MAIN_inventory_by_socket[socket_number][local_grid_index]
			if dict != {}:
				var item_id = int(dict["item_id"])
				if item_id >= 0 && item_id < global_item_count_on_table_by_id.size():
					global_item_count_on_table_by_id[item_id] += 1
				if socket_properties != null && item_id >= 0 && item_id < socket_properties.user_inventory_count_by_item_id.size():
					socket_properties.user_inventory_count_by_item_id[item_id] += 1

func RollbackUnplacedReservedItem(for_socket_number : int):
	var property : MP_UserInstanceProperties = GetSocketProperties(for_socket_number)
	if property == null:
		return
	var reserved_item_id = property.unplaced_reserved_item_id
	if reserved_item_id == -1:
		return
	if reserved_item_id >= 0 && reserved_item_id < global_item_count_on_table_by_id.size():
		if global_item_count_on_table_by_id[reserved_item_id] > 0:
			global_item_count_on_table_by_id[reserved_item_id] -= 1
	if property.user_inventory_count_by_item_id != null && reserved_item_id >= 0 && reserved_item_id < property.user_inventory_count_by_item_id.size():
		if property.user_inventory_count_by_item_id[reserved_item_id] > 0:
			property.user_inventory_count_by_item_id[reserved_item_id] -= 1
	property.unplaced_reserved_item_id = -1
	property.is_holding_item_to_place = false

var mouse_pos
func _input(event):
	if event is InputEventMouse:
			mouse_pos = event.position

var pinging_mouse_pos = false
func PingMousePosition():
	while (pinging_mouse_pos):
		var old = mouse_pos
		await GlobalVariables.tree.create_timer(.5, false).timeout
		var new = mouse_pos
		if new != old: 
			counting = false
			count = 0
		else:
			counting = true
		pass
	pass

var counting = false
var count = 0
var max_inactivity_sec = 300
var fs = false
var reached_end = false
func CountInactivity():
	if counting && !reached_end:
		count += get_process_delta_time()
	else:
		count = 0
	if count > max_inactivity_sec && !fs:
		reached_end = true
		instance_handler.Setup_ExitGameWithLobbyMembers()
		fs = true

func SetupInventory():
	MAIN_inventory_by_socket = []
	for socket_number in 4:
		MAIN_inventory_by_socket.append([])
		for item_slot in 8:
			MAIN_inventory_by_socket[socket_number].append({})

func MakeSequenceCopies():
	MAIN_active_sequence_batch_array_copy_in_use_for_2 = MAIN_sequence_batch_array_for_2.duplicate()
	MAIN_active_sequence_batch_array_copy_in_use_for_3 = MAIN_sequence_batch_array_for_3.duplicate()
	MAIN_active_sequence_batch_array_copy_in_use_for_4 = MAIN_sequence_batch_array_for_4.duplicate()

func IncrementActiveSequenceIndex(overriding_with_value : int = -1):
	if overriding_with_value == -1:
		MAIN_active_sequence_index_to_pull += 1
		if MAIN_active_sequence_index_to_pull == 4:
			MAIN_active_sequence_index_to_pull = 0
	else:
		MAIN_active_sequence_index_to_pull = overriding_with_value

func SetItemDistributionVariablesFromCustomization(for_round_index : int):
	var active = GlobalVariables.active_match_customization_dictionary.duplicate(true)
	for m_round in active.round_property_array:
		if m_round.round_index == for_round_index:
			for item_property in m_round.item_properties:
				for item_resource in MAIN_item_resource_array:
					if item_property.item_id == item_resource.id:
						item_resource.max_amount_on_table = item_property.max_per_player
						item_resource.max_amount_on_table_global = item_property.max_on_table
						item_resource.distribution_enabled = item_property.is_ingame

func Global_AddItemToInventory(socket_number : int, instance : Node3D, item_id : int, local_grid_index : int):
	var item_name = instance.get_child(1).itemName
	var dict = {
		"item_name" = item_name,
		"item_instance" = instance,
		"item_id" = item_id,
	}
	MAIN_inventory_by_socket[socket_number][local_grid_index] = dict

func Global_RemoveItemFromInventory(socket_number : int, local_grid_index):
	var slot = MAIN_inventory_by_socket[socket_number][local_grid_index]
	if typeof(slot) != TYPE_DICTIONARY || !slot.has("item_id"):
		MAIN_inventory_by_socket[socket_number][local_grid_index] = {}
		return
	for property in instance_handler.instance_property_array:
		if property.socket_number == socket_number:
			property.user_inventory_count_by_item_id[slot["item_id"]] -= 1
	global_item_count_on_table_by_id[slot["item_id"]] -= 1
	MAIN_inventory_by_socket[socket_number][local_grid_index] = {}

func Global_ClearInventoryDictionaries(socket_number : int):
	for i in range(MAIN_inventory_by_socket[socket_number].size()):
		MAIN_inventory_by_socket[socket_number][i] = {}

func GetItemToGrab(for_user : MP_UserInstanceProperties, incrementing_inventory : bool = false):
	var resource_pool_main : Array[MP_ItemResource]
	var id_pool_available_to_grab : Array[int]
	var id_pool_globally_eligible : Array[int]
	for res in MAIN_item_resource_array:
		if res.distribution_enabled:
			resource_pool_main.append(res)
		if res.id == 10 && instance_handler.instance_property_array.size() == 2:
			resource_pool_main.erase(res)
	for res in resource_pool_main:
		var total_res_count = 0
		total_res_count = global_item_count_on_table_by_id[res.id]
		if total_res_count < res.max_amount_on_table_global:
			id_pool_globally_eligible.append(res.id)
	for res in resource_pool_main:
		if for_user.user_inventory_count_by_item_id[res.id] < res.max_amount_on_table:
			if res.id in id_pool_globally_eligible:
				id_pool_available_to_grab.append(res.id)
				
	if (DebugTools.DEBUG_TOOLS_ENABLED):
		print("=== GetItemToGrab ===")
		print("DEBUG GetItemToGrab socket:", for_user.socket_number, " increment:", incrementing_inventory)
		print("socket: ", for_user.socket_number, " incrementing: ", incrementing_inventory)
		print("global_item_count_on_table_by_id: ", global_item_count_on_table_by_id)
		print("user_inventory_count_by_item_id: ", for_user.user_inventory_count_by_item_id)
		print("id_pool_globally_eligible: ", id_pool_globally_eligible)
		print("id_pool_available_to_grab: ", id_pool_available_to_grab)
				
	var item_id_to_grab
	if id_pool_available_to_grab != []:
		if id_pool_available_to_grab.size() == 1:
			item_id_to_grab = id_pool_available_to_grab[0]
		else:
			item_id_to_grab = id_pool_available_to_grab[randi_range(0, id_pool_available_to_grab.size() - 1)]
	if item_id_to_grab != null && incrementing_inventory:
		for_user.user_inventory_count_by_item_id[item_id_to_grab] += 1
		global_item_count_on_table_by_id[item_id_to_grab] += 1
	return item_id_to_grab
	
	#var resource_pool_main : Array[MP_ItemResource]
	#var id_pool_available_to_grab : Array[int]
	#var id_pool_globally_eligible : Array[int]
	#for res in MAIN_item_resource_array:
	#	if res.distribution_enabled:
	#		resource_pool_main.append(res)
	#	if res.id == 10 && instance_handler.instance_property_array.size() == 2:
	#		resource_pool_main.erase(res)
	#for res in resource_pool_main:
	#	var total_res_count = 0
	#	var t = false
	#	for property in instance_handler.instance_property_array:
	#		total_res_count += property.user_inventory_count_by_item_id[res.id]
	#		print("res id: ", res.id, " user inventory count for this id: ", property.user_inventory_count_by_item_id[res.id])
	#	if total_res_count < res.max_amount_on_table_global:
	#		print("ITEM NAME: ", res.name ," total res count: ", total_res_count, " max amount on table global: ", res.max_amount_on_table_global)
	#		id_pool_globally_eligible.append(res.id)
	#		t = true
	#for res in resource_pool_main:
	#	print("for user inventory count by item id: ", for_user.user_inventory_count_by_item_id[res.id], " res max amount on table: ", res.max_amount_on_table)
	#	if for_user.user_inventory_count_by_item_id[res.id] < res.max_amount_on_table:
	#		if res.id in id_pool_globally_eligible:
	#			id_pool_available_to_grab.append(res.id)
	#var item_id_to_grab
	#print("id pool available to grab: ", id_pool_available_to_grab)
	#if id_pool_available_to_grab != []:
	#	if id_pool_available_to_grab.size() == 1:
	#		item_id_to_grab = id_pool_available_to_grab[0]
	#	else:
	#		item_id_to_grab = id_pool_available_to_grab[randi_range(0, id_pool_available_to_grab.size() - 1)]
	#	for_user.user_inventory_count_by_item_id[item_id_to_grab] += 1
	#return item_id_to_grab

func CheckIfEndingTurnAfterItemUse(item_id : int, for_socket_number : int):
	var property = GetSocketProperties(for_socket_number)
	if GetSocketProperties(for_socket_number).user_id in MAIN_active_user_id_exceeded_secondary_timeout_array:
		return true
	if GetSocketProperties(for_socket_number).user_id in MAIN_active_user_id_exceeded_turn_timeout_array:
		pass
	if GlobalVariables.timeouts_enabled:
		for timeout in property.timeout.timeout_branch_array:
			if timeout.branch_alias == "turn":
				if (timeout.current_timeout_length - timeout.current_timeout_count) < 3.85:
					print("timeout is under 3.85, return true")
					return true
	match item_id:
		1: 	#handsaw
			return false
		2: 	#magnifying glass
			return false
		3: 	#jammer
			return false
		4: 	#cigarettes
			return false
		5: 	#beer (if the shotgun is empty after the beer shell ejection, end the user's turn.)
			return MAIN_active_sequence_dict.sequence_in_shotgun.size() - 1 == 0
		6: 	#burner phone
			return false
		7: 	#expired medicine
			return false
		8:	 #adrenaline
			return false
		9: 	#inverter
			return false
		10:	#remote
			return false
	return false

func IsPlacingLastItem(user_properties : MP_UserInstanceProperties):
	var m_count = 0
	var result = GetItemToGrab(user_properties, false)
	if (DebugTools.DEBUG_TOOLS_ENABLED):
		print("DEBUG IsPlacingLastItem socket:", user_properties.socket_number, " result:", result)
	if result == null:
		user_properties.is_grabbing_items = false
		return true
	for dict in user_properties.user_inventory:
		if dict != {}:
			m_count += 1
	m_count += 1
	if m_count == 8: 
		user_properties.is_grabbing_items = false
		print(user_properties.socket_number, " is placing last item.")
		return true
	if user_properties.num_of_items_currently_grabbed >= MAIN_active_num_of_items_to_grab:
		user_properties.is_grabbing_items = false
		print(user_properties.socket_number, " is placing last item.")
		return true
	print(user_properties.socket_number, " is not placing last item.")
	return false

var item_grabbing_finished_for_all_users_checked = false
func CheckIfItemGrabbingFinishedForAllUsers():
	if item_grabbing_finished_for_all_users_checked: return
	var finished = false
	print("num of users finished: ", MAIN_active_num_of_users_finished_item_grabbing, " num of users grabbing: ", MAIN_active_num_of_users_grabbing_items)
	var count_finished_grabbing = 0
	var count_instances = instance_handler.instance_property_array.size()
	for property in instance_handler.instance_property_array:
		if !property.is_grabbing_items:
			count_finished_grabbing += 1
	finished = count_finished_grabbing == count_instances
	var properties_that_have_no_more_items_to_grab = 0
	for property in instance_handler.instance_property_array:
		if GetItemToGrab(property, false) == null:
			properties_that_have_no_more_items_to_grab += 1
	print("properties no more items to grab: ", properties_that_have_no_more_items_to_grab, " count instances: ", count_instances)
	if properties_that_have_no_more_items_to_grab == count_instances:
		finished = true
	if finished:
		MAIN_item_grabbing_in_progress = false
		item_grabbing_finished_for_all_users_checked = true
		await GlobalVariables.tree.create_timer(2, false).timeout
		round_manager.MainRoutine_LoadShotgun()

func GetSocketsToBeginItemGrabbingOn(inventories_cleared : bool = false):
	var socket_array_to_return = []
	print("getting sockets to begin item grabbing on. inventories cleared: ", inventories_cleared)
	for property in instance_handler.instance_property_array:
		if property.health_current != 0 or MAIN_is_start_of_new_round or inventories_cleared:
			print("checking property items")
			var num_of_items_in_inventory = 0
			for dict in property.user_inventory:
				if dict != {}:
					num_of_items_in_inventory += 1
			print("num of items: ", num_of_items_in_inventory, " inventories cleared: ", inventories_cleared)
			if num_of_items_in_inventory != 8 or inventories_cleared:
				if GetItemToGrab(property, false) != null:
					print("appending property: ", property.socket_number)
					socket_array_to_return.append(property.socket_number)
	
	if MAIN_active_num_of_items_to_grab == 0:
		print("number of items to grab is set to 0. clearing array")
		socket_array_to_return = []
	print("returning array: ", socket_array_to_return)
	return socket_array_to_return

func GetSocketArrayToEndItemGrabbingOn(excluding_socket_number : int = -1):
	var array_to_return = []
	for property in instance_handler.instance_property_array:
		print("property name: ", property.user_name, " is grabbing items: ", property.is_grabbing_items)
		if property.is_grabbing_items && !property.is_holding_item_to_place:
			if property.socket_number != excluding_socket_number:
				if GetItemToGrab(property, false) == null:
					array_to_return.append(property.socket_number)
	print("socket array to end item grabbing on: ", array_to_return)
	return array_to_return

func CheckIfAllInventoriesAreFull():
	var full_inventory_count = 0
	var alive_user_property_array = []
	for property in instance_handler.instance_property_array:
		if property.health_current != 0:
			alive_user_property_array.append(property)
	for instance_properties in alive_user_property_array:
		var instance_item_count = 0
		for dictionary in instance_properties.user_inventory:
			if dictionary != {}:
				instance_item_count += 1
		if instance_item_count == 8:
			full_inventory_count += 1
	var all_inventories_full : bool = full_inventory_count == alive_user_property_array.size()
	print("all inventories full: ", all_inventories_full)
	return all_inventories_full

func GetBurnerPhone_VerbalIndex():
	var current_sequence = MAIN_active_sequence_dict.get("sequence_in_shotgun", [])
	if !(current_sequence is Array):
		return -1
	var current_array : Array = current_sequence as Array
	var verbal_index = 0
	if current_array.size() <= 2:
		verbal_index = -1
	else:
		var randindex = randi_range(2, current_array.size() - 1)
		verbal_index = randindex
		verbal_index += 1
	if verbal_index > 7:
		verbal_index = 7
	return verbal_index

func _GetBurnerPhone_Shell(with_verbal_index : int):
	var current_sequence = MAIN_active_sequence_dict.get("sequence_in_shotgun", [])
	if !(current_sequence is Array):
		return ""
	var current_array : Array = current_sequence as Array
	if current_array.size() <= 2:
		return ""
	var check_index = with_verbal_index - 1
	if check_index < 0 || check_index >= current_array.size():
		return ""
	return str(current_array[check_index])

#func GetBurnerPhone_Shell():
#	var current_sequence = MAIN_active_sequence_dict.sequence_in_shotgun
#	var verbal_shell = ""
#	if current_sequence.size() <= 2:
#		verbal_shell = ""
#	else:
#		var randindex = randi_range(2, current_sequence.size() - 1)
#		verbal_shell = current_sequence[randindex]
#	return verbal_shell

func FreeLookCameraForAllUsers_Enable():
	for property in instance_handler.instance_property_array:
		property.is_allowed_to_free_look = true

func FreeLookCameraForAllUsers_Disable():
	for property in instance_handler.instance_property_array:
		property.is_allowed_to_free_look = false
		if property.camera_look.looking_active:
			property.camera_look.EndCameraLook()

func GetPropertyInvalidItems(user_properties : MP_UserInstanceProperties):
	#items that can be set invalid:
	#ID 1 - handsaw		(when the barrel is already sawed off)
	#ID 3 - jammer		(when none of the opponents can be jammed, either coz they're dead or jammed already)
	#ID 8 - adrenaline 	(when there are no items eligible for stealing. OR if there are eligible items, set adrenaline invalid to prevent the player from consuming all adrenalines)
	var array_to_return = []
	array_to_return.append(false)
	for item in user_properties.intermediary.game_state.MAIN_item_resource_array:	
		array_to_return.append(false)
	#ID 1	handsaw
	if MAIN_barrel_sawed_off: array_to_return[1] = true
	#ID 2	jammer
	array_to_return[3] = !CheckIfJammerHasEligibleTargets(user_properties)
	#ID 3	adrenaline
	var total_item_count = 0
	var total_adrenaline_count = 0
	if !user_properties.is_stealing_item:
		var invalid_item_count = 0
		for property in instance_handler.instance_property_array:
			if property.socket_number != user_properties.socket_number:
				for dict in MAIN_inventory_by_socket[property.socket_number]:
					if dict != {}:
						total_item_count += 1
						if array_to_return[dict.item_id]:
							invalid_item_count += 1
					if dict != {}:
						if dict.item_id == 8:
							total_adrenaline_count += 1
		if total_item_count == 0 or invalid_item_count == total_item_count: array_to_return[8] = true
		if total_item_count == total_adrenaline_count: array_to_return[8] = true #prevent adrenaline from being eligible if all stealable items are adrenalines
	else:
		array_to_return[8] = true
	
	return array_to_return

func GetSocketID(socket_number : int):
	var id = 0
	for property in instance_handler.instance_property_array:
		if property.socket_number == socket_number:
			id = property.user_id
			break
	return id

func CheckIfShooterEndingTurnAfterShot(active_shooter_socket_target : int, active_shooter_socket_self : int, active_shooter_shell : String, barrel_sawed_off : bool, active_shooter_sequence_length_after_eject : int):
	if GetSocketProperties(active_shooter_socket_self).user_id in MAIN_active_user_id_exceeded_secondary_timeout_array:
		return true
	var ending_turn = true
	#var handing_turn_over = true
	#var sequence_empty = false
	var user_has_won_with_socket = -1
	var future_health_for_shot_socket
	var shotgun_damage = 1
	var num_of_users_alive = 0
	var user_alive_socket = -1
	
	if barrel_sawed_off: shotgun_damage = 2
	for property in instance_handler.instance_property_array:
		if property.socket_number == active_shooter_socket_target:
			var t = property.health_current
			future_health_for_shot_socket = t - shotgun_damage
	for property in instance_handler.instance_property_array:
		if property.socket_number != active_shooter_socket_target:
			if property.health_current != 0:
				num_of_users_alive += 1
				user_alive_socket = property.socket_number
		else:
			if future_health_for_shot_socket != 0:
				num_of_users_alive += 1
				user_alive_socket = active_shooter_socket_target
	if num_of_users_alive == 1:
		user_has_won_with_socket = user_alive_socket
	
	if active_shooter_socket_target == active_shooter_socket_self && active_shooter_shell == "blank":
		ending_turn = true
		#handing_turn_over = false
	if active_shooter_sequence_length_after_eject == 0:
		ending_turn = true
		#sequence_empty = true
	if user_has_won_with_socket != -1: ending_turn = true
	
	return ending_turn

func CheckIfJammerHasEligibleTargets(user_properties : MP_UserInstanceProperties):
	var num_of_players_ingame = instance_handler.instance_property_array.size()
	var num_of_players_eligible_to_jam = num_of_players_ingame - 1
	for property in instance_handler.instance_property_array:
		if property.socket_number != user_properties.socket_number:
			if property.health_current == 0 or property.is_jammed:
				num_of_players_eligible_to_jam -= 1
	if num_of_players_eligible_to_jam == 0:
		return false
	else:
		return true

func GetSocketInventoriesToClear():
	var final_array = []
	for i in 4:
		var item_count = 0
		for c in range(MAIN_inventory_by_socket[i].size()):
			if MAIN_inventory_by_socket[i][c] != {}:
				item_count += 1
		if item_count != 0:
			final_array.append(i)
	final_array.sort()
	return final_array

func ResetTimeoutBarsForAllUsers():
	if !GlobalVariables.timeouts_enabled: return
	for property in instance_handler.instance_property_array:
		property.timeout.ResetAllTimeouts()

func BeginTimeoutForSocket(timeout_type : String, timeout_duration : float, for_socket_number : int):
	if !GlobalVariables.timeouts_enabled: return
	print("beginning timeout for socket: ", for_socket_number, " with type: ", timeout_type, " and length: ", timeout_duration)
	for property in instance_handler.instance_property_array:
		if property.socket_number == for_socket_number:
			property.timeout.StartCountingTimeout(timeout_type, timeout_duration)
			break

func StopTimeoutForSocket(timeout_type : String, for_socket_number : int):
	if !GlobalVariables.timeouts_enabled: return
	print("stopping timeout for socket: ", for_socket_number, " with type: ", timeout_type)
	for property in instance_handler.instance_property_array:
		if property.socket_number == for_socket_number:
			property.timeout.StopCountingTimeout(timeout_type)
			break

func StopAllTimeouts():
	for property in instance_handler.instance_property_array:
		property.timeout.StopCountingAllTimeouts()

func OnTimeoutReached(timeout_type : String, for_socket_number : float):
	if !GlobalVariables.timeouts_enabled: return
	if GlobalSteam.STEAM_ID != GlobalSteam.HOST_ID: return
	var socket_number_int := int(for_socket_number)
	var property : MP_UserInstanceProperties = GetSocketProperties(socket_number_int)
	var ending_turn_after_timeout = false
	print("... timeout type: ", timeout_type, " ... property on secondary interaction: ", property.is_on_secondary_interaction, " ... is interacting with item: ", property.is_interacting_with_item)
	if (timeout_type == "turn" && !property.is_on_secondary_interaction) && property.is_interacting_with_item:
		print("appending to MAIN_active_user_id_exceeded_turn_timeout_array")
		MAIN_active_user_id_exceeded_turn_timeout_array.append(property.user_id)
		print("MAIN_active_user_id_exceeded_turn_timeout_array after append: ", MAIN_active_user_id_exceeded_turn_timeout_array)
		return
	if timeout_type == "turn" && property.is_on_secondary_interaction:
		MAIN_active_user_id_exceeded_secondary_timeout_array.append(property.user_id)
		return
	if timeout_type == "adrenaline" or "jammer" or "shotgun target selection":
		if property.user_id in MAIN_active_user_id_exceeded_secondary_timeout_array:
			ending_turn_after_timeout = true
		else:
			ending_turn_after_timeout = false
	if timeout_type == "turn":
		MAIN_active_user_id_to_ignore_timeout_packets_array.append(property.user_id)
	if timeout_type == "item distribution":
		RollbackUnplacedReservedItem(socket_number_int)
		MAIN_active_user_id_to_ignore_timeout_packets_array.append(property.user_id)
		
	var packet = {
		"packet category": "MP_UserInstanceProperties",
		"packet alias": "timeout exceeded",
		"sent_from": "host",
		"packet_id": 30,
		"packet id": 30,
		"timeout_type": timeout_type,
		"ending_turn_after_timeout": ending_turn_after_timeout,
		"socket_number": property.socket_number,
		"next_turn_socket": round_manager.GetNextTurn_Socket(MAIN_active_current_turn_socket)
		}
	packets.send_p2p_packet(0, packet)
	packets.PipeData(packet)
	
	#game_state.MAIN_active_user_id_exceeded_secondary_timeout_array.erase(property.user_id)
	#game_state.MAIN_active_user_id_to_ignore_timeout_packets_array.erase(property.user_id)
	#game_state.MAIN_active_user_id_exceeded_turn_timeout_array.erase(property.user_id)

func ClearTimeouts():
	MAIN_active_user_id_exceeded_secondary_timeout_array.clear()
	MAIN_active_user_id_to_ignore_timeout_packets_array.clear()
	MAIN_active_user_id_exceeded_turn_timeout_array.clear()

func GetSocketProperties(socket_number : int):
	for instance_property in instance_handler.instance_property_array:
		if instance_property.socket_number == socket_number:
			return instance_property

func CheckIfPropertyHasItem(socket_number : int, item_id_to_check : int):
	var has_item = false
	for i in range(MAIN_inventory_by_socket[socket_number].size()):
		if MAIN_inventory_by_socket[socket_number][i] != {}:
			if MAIN_inventory_by_socket[socket_number][i].item_id == item_id_to_check:
				has_item = true
	return has_item

func PrintInventory():
	print("")
	print("INVENTORY:")
	print("")
	for i in range(4):
		print("SOCKET ", i, ": ")
		for c in range(MAIN_inventory_by_socket[i].size()):
			print("local grid ", c, ": ", MAIN_inventory_by_socket[i][c])
		print("")

func GetMatchResultStatistics():
	var id_most_damage = -1
	var id_most_deaths = -1
	var id_the_chimney = -1
	var id_least_careful = -1
	var id_most_resourceful = -1
	var id_the_wealthiest = -1
	
	var dict_array_most_damage = []
	var dict_array_most_deaths = []
	var dict_array_the_chimney = []
	var dict_array_least_careful = []
	var dict_array_most_resourceful = []
	var dict_array_the_wealthiest = []
	
	for property in instance_handler.instance_property_array:
		var dict
		dict = { "stat": property.stat_damage_dealt, "user_id": property.user_id}; dict_array_most_damage.append(dict)
		dict = { "stat": property.stat_number_of_deaths, "user_id": property.user_id}; dict_array_most_deaths.append(dict)
		dict = { "stat": property.stat_number_of_cigarettes_smoked, "user_id": property.user_id}; dict_array_the_chimney.append(dict)
		dict = { "stat": property.stat_number_of_times_shot_self_with_live, "user_id": property.user_id}; dict_array_least_careful.append(dict)
		dict = { "stat": property.stat_number_of_items_used, "user_id": property.user_id}; dict_array_most_resourceful.append(dict)
		dict = { "stat": property.stat_amount_of_cash_earned, "user_id": property.user_id}; dict_array_the_wealthiest.append(dict)
	id_most_damage = GetMaxDictionary_Name(dict_array_most_damage)
	id_most_deaths = GetMaxDictionary_Name(dict_array_most_deaths)
	id_the_chimney = GetMaxDictionary_Name(dict_array_the_chimney)
	id_least_careful = GetMaxDictionary_Name(dict_array_least_careful)
	id_most_resourceful = GetMinDictionary_Name(dict_array_most_resourceful)
	id_the_wealthiest = GetMaxDictionary_Name(dict_array_the_wealthiest)
	
	var match_result_statistics = {
		"id_most_damage": id_most_damage,
		"id_most_deaths": id_most_deaths,
		"id_the_chimney": id_the_chimney,
		"id_least_careful": id_least_careful,
		"id_most_resourceful": id_most_resourceful,
		"id_the_wealthiest": id_the_wealthiest,
	}
	return match_result_statistics
	
func GetMaxDictionary_Name(dict_array):
	var highest_value = 0
	var dict_to_return = {}
	for dict in dict_array:
		var stat_value = dict.values()[0]
		if stat_value >= highest_value:
			highest_value = stat_value
			dict_to_return = dict
	if highest_value != 0:
		return dict_to_return.user_id
	else:
		return -1

func GetMinDictionary_Name(dict_array):
	var lowest_value = 1000000
	var dict_to_return = {}
	for dict in dict_array:
		var stat_value = dict.values()[0]
		if stat_value <= lowest_value:
			lowest_value = stat_value
			dict_to_return = dict
	if lowest_value != 1000000:
		return dict_to_return.user_id
	else:
		return -1
