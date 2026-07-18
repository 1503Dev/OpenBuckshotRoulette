class_name PacketManager extends Node

@export var lobby_ui : MP_LobbyUI
@export var match_customization : MP_MatchCustomization
@export_group("mp_main")
@export var game_state : MP_GameStateManager
@export var lobby : LobbyManager
@export var instance_handler : MP_UserInstanceHandler
@export var round_manager : MP_RoundManager
@export var verifier : MP_PacketVerification
@export_group("")

func _ready() -> void:
	Steam.p2p_session_request.connect(_on_p2p_session_request)
	Steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)
	GlobalSteam.packet_received.connect(_on_packet_received)

func GetTime():
	return str(Time.get_time_string_from_system())

func _process(_delta) -> void:
	if GlobalSteam.LOBBY_ID != 0:
		read_p2p_packet()

var read_count
func read_all_p2p_packets(m_read_count: int = 0):
	if m_read_count >= GlobalSteam.PACKET_READ_LIMIT:
		return
	
	if Steam.getAvailableP2PPacketSize(0) > 0:
		read_p2p_packet()
		read_all_p2p_packets(read_count + 1)

func send_p2p_packet_directly_to_host(sending_from_id : int, packet_data : Dictionary):
	if sending_from_id == GlobalSteam.HOST_ID && !GlobalVariables.mp_debugging:
		var verified_packet = verifier.VerifyPacket(packet_data)
		PipeData(verified_packet)
	else:
		send_p2p_packet(GlobalSteam.HOST_ID, packet_data)

func send_p2p_packet_through_host(sending_From_id : int, packet_data : Dictionary):
	print("checking if sending packet through host with packet data: ", packet_data)
	if sending_From_id == GlobalSteam.HOST_ID:
		print("packet is already sending from host. sending to all members.")
		packet_data.confirmed = true
		send_p2p_packet(0, packet_data)
	else:
		print("packet is not from host. sending through host.")
		packet_data.confirmed = false
		send_p2p_packet(GlobalSteam.HOST_ID, packet_data)

func send_p2p_packet(target: int, packet_data: Dictionary) -> void:
	if GlobalVariables.mp_debugging: return
	if target == 0:
		packet_data.erase("target_user_id")
	else:
		packet_data["target_user_id"] = target
	var send_type: int = Steam.P2P_SEND_RELIABLE
	var channel: int = 0
	
	var this_data: PackedByteArray
	
	var compressed_data: PackedByteArray = var_to_bytes(packet_data).compress(FileAccess.COMPRESSION_GZIP)
	this_data.append_array(compressed_data)
	
	if target == 0:
		if GlobalSteam.LOBBY_MEMBERS.size() >= 1:
			for this_member in GlobalSteam.LOBBY_MEMBERS:
				if this_member['steam_id'] != GlobalSteam.STEAM_ID:
					if GlobalVariables.using_steam:
						Steam.sendP2PPacket(this_member['steam_id'], this_data, send_type, channel)
					if GlobalVariables.printing_packets: print("sending packet with target 0: ", packet_data)
		if not GlobalVariables.using_steam and GlobalSteam.connected:
			GlobalSteam.send_packet(this_data)
	else:
		if GlobalVariables.using_steam:
			Steam.sendP2PPacket(target, this_data, send_type, channel)
		if not GlobalVariables.using_steam and GlobalSteam.connected:
			GlobalSteam.send_packet(this_data)

func _on_packet_received(readable_data: Dictionary):
	var sender_id: int = GlobalSteam.HOST_ID
	
	if readable_data.has("target_user_id") && int(readable_data.target_user_id) != GlobalSteam.STEAM_ID:
		return
	
	if GlobalSteam.STEAM_ID != GlobalSteam.HOST_ID:
		if sender_id != GlobalSteam.HOST_ID: 
			print("packet refused: received packet from non-host user.")
			return
	
	if sender_id in GlobalSteam.USER_ID_LIST_TO_IGNORE:
		print("packet refused: received packet from an ID that is set to be ignored.")
		return
	
	if game_state != null:
		if sender_id in game_state.MAIN_active_user_id_to_ignore_timeout_packets_array:
			print("received packet from an ID that has exceeded timeout")
			if readable_data.packet_id in game_state.MAIN_active_timeout_packet_id_array:
				print("received packet is set to ignore on timeout. refused")
			else:
				print("received packet is not set to ignore on timeout. continuing")
	
	if sender_id == GlobalSteam.HOST_ID:
		print("received packet from host")
	if GlobalVariables.printing_packets: 
		print("received packet: ", readable_data)
	
	temp_id = sender_id
	PipeData(readable_data)

var temp_id = 0
func read_p2p_packet() -> void:
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)
	
	if packet_size > 0:
		var this_packet: Dictionary = Steam.readP2PPacket(packet_size, 0)
		
		if this_packet.is_empty() or this_packet == null:
			print("WARNING: read an empty packet with non-zero size!")
		
		var packet_sender: int = this_packet['steam_id_remote']
		
		var packet_code: PackedByteArray = this_packet['data']
		var readable_data: Dictionary = bytes_to_var(packet_code.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP))
		
		if readable_data.has("target_user_id") && int(readable_data.target_user_id) != GlobalSteam.STEAM_ID:
			return
		
		if GlobalSteam.STEAM_ID != GlobalSteam.HOST_ID:
			if packet_sender != GlobalSteam.HOST_ID: 
				print("packet refused: received packet from non-host user.")
				return
		
		if packet_sender in GlobalSteam.USER_ID_LIST_TO_IGNORE:
			print("packet refused: received packet from an ID that is set to be ignored.")
			return
		
		if game_state != null:
			if packet_sender in game_state.MAIN_active_user_id_to_ignore_timeout_packets_array:
				print("received packet from an ID that has exceeded timeout")
				if readable_data.packet_id in game_state.MAIN_active_timeout_packet_id_array:
					print("received packet is set to ignore on timeout. refused")
				else:
					print("received packet is not set to ignore on timeout. continuing")
		
		if packet_sender == GlobalSteam.HOST_ID:
			print("received packet from host")
		if GlobalVariables.printing_packets: 
			print("received packet: ", readable_data)
		
		temp_id = packet_sender
		PipeData(readable_data)

@export var lobbyController : LobbyController
@export var memberChecker : MemberChecker

func _resolved_lobby_controller() -> LobbyController:
	if lobbyController != null:
		return lobbyController
	if lobby != null and lobby.lobby_controller != null:
		return lobby.lobby_controller
	return null

func PipeData(dict : Dictionary):
	if GlobalVariables.printing_packets: print("[", GetTime(), "]", ": sorting packet: ", dict)
	if dict == null || dict == {}:
		return
	if !GlobalVariables.using_steam && GlobalSteam.STEAM_ID != GlobalSteam.HOST_ID:
		if str(dict.get("packet category", "")) == "MP_PacketVerification" && str(dict.get("sent_from", "")) == "client":
			return
	var value_category = str(dict.get("packet category", ""))
	var value_alias = str(dict.get("packet alias", ""))
	match value_category:
		"MP_UserInstanceHandler": 
			if (instance_handler): instance_handler.PacketSort(dict)
		"MP_RoundManager":
			round_manager.PacketSort(dict)
		"MP_UserInstanceProperties":
			for instance in instance_handler.instance_property_array:
				instance.PacketSort(dict)
		"MP_PacketVerification":
			var verified_packet = verifier.VerifyPacket(dict)
			if verified_packet == {}:
				print("verification: failed to verify client request packet: ", dict, " ignoring")
			else:
				print("verification: success on verify client request packet: ", dict, " sending")
				verifier.PacketSort(dict)
	match value_alias:
		"handshake":
			print("got handshake with dictionary: ", dict)
		"start game from lobby":
			var lc_start := _resolved_lobby_controller()
			if lc_start == null:
				push_warning("PacketManager: no LobbyController; ignoring start game from lobby.")
				return
			if GlobalSteam.STEAM_ID == GlobalSteam.HOST_ID:
				lc_start.StartGameRoutine_Main()
			else:
				lc_start.StartGameRoutine_Client()
		"host arrived in main scene":
			var lc_scene := _resolved_lobby_controller()
			if lc_scene == null:
				push_warning("PacketManager: no LobbyController; ignoring host arrived in main scene.")
				return
			lc_scene.StartGameRoutine_LoadScene()
		"member joined list":
			if memberChecker == null:
				return
			var steam_id = dict["steam_id"]
			memberChecker.MemberJoinedList(steam_id)
		"update member list":
			if memberChecker == null:
				return
			if not dict.has("number of players here"):
				push_warning("PacketManager: update member list missing 'number of players here'; ignoring.")
				return
			var temp_numberOfPlayersHere = dict["number of players here"]
			memberChecker.amountOfPlayers_here = temp_numberOfPlayersHere
			memberChecker.UpdateMemberList()
		"all members arrived":
			if memberChecker == null:
				return
			memberChecker.MembersArrived()
		"kick player":
			lobby.ReceivePacket_KickPlayer(dict)
		"update match info ui":
			lobby_ui.UpdateMatchInformation(dict)
		"check version":
			lobby.ReceivePacket_VersionCheck(dict, temp_id)
		"version response":
			lobby.ReceivePacket_VersionResponse(dict)
		"update match customization":
			match_customization.ReceivePacket_MatchCustomization(dict)
		"request player list sync":
			if GlobalSteam.STEAM_ID == GlobalSteam.HOST_ID:
				print("Host received player list sync request from client: ", dict.get("requesting_player_id"))
				lobby.BroadcastPlayerListSync()
		"sync player list":
			print("Received player list sync from host")
			if GlobalSteam.STEAM_ID != GlobalSteam.HOST_ID:
				GlobalSteam.LOBBY_MEMBERS.clear()
				for row in dict.get("player_list", []):
					if row is Dictionary:
						GlobalSteam.LOBBY_MEMBERS.append({
							"steam_id": int(row.get("steam_id", 0)),
							"steam_name": str(row.get("steam_name", "")),
						})
				if instance_handler != null:
					instance_handler.current_member_steamid_array = GlobalSteam.LOBBY_MEMBERS.duplicate()
					instance_handler.CheckLobbyMemberArray()
				if memberChecker != null:
					memberChecker.UpdateExpectedTotal(GlobalSteam.LOBBY_MEMBERS.size())
					memberChecker.UpdateMemberList()
			if lobby_ui != null:
				lobby_ui.UpdatePlayerList()

func _on_p2p_session_request(remote_id: int) -> void:
	var this_requester: String = Steam.getFriendPersonaName(remote_id)
	print("%s is requesting a P2P session" % this_requester)
	
	Steam.acceptP2PSessionWithUser(remote_id)
	
	make_p2p_handshake()

func make_p2p_handshake() -> void:
	print("Sending P2P handshake to the lobby in packet manager")
	
	var packet = {
		"packet category": "lobby",
		"packet alias": "handshake",
		"packet_id": 1,
		"message": str("handshake from: " , GlobalSteam.STEAM_ID)
	}
	send_p2p_packet(0, packet)

func _on_p2p_session_connect_fail(steam_id: int, session_error: int) -> void:
	if session_error == 0:
		print("WARNING: Session failure with %s: no error given" % steam_id)
	
	elif session_error == 1:
		print("WARNING: Session failure with %s: target user not running the same game" % steam_id)
	
	elif session_error == 2:
		print("WARNING: Session failure with %s: local user doesn't own app / game" % steam_id)
	
	elif session_error == 3:
		print("WARNING: Session failure with %s: target user isn't connected to Steam" % steam_id)
	
	elif session_error == 4:
		print("WARNING: Session failure with %s: connection timed out" % steam_id)
	
	elif session_error == 5:
		print("WARNING: Session failure with %s: unused" % steam_id)
	
	else:
		print("WARNING: Session failure with %s: unknown error %s" % [steam_id, session_error])
