class_name SpawnManager
extends Node2D

## 2D Spawn Point Manager for BLACKOUT (Asterion Research Facility).
## Handles deterministic spawn slot mapping (Slots 1 to 8), slot allocation,
## collision-free placement, and disconnect recovery for connected players.
## Integrates cleanly with the authoritative ClientNetworkManager session events.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const PlayerController = preload("res://client/player/player_controller.gd")

## Total allowable spawn slots in BLACKOUT MVP.
const MAX_SPAWN_SLOTS: int = 8

## Fallback spawn coordinate for Asterion facility central hub.
const FALLBACK_SPAWN: Vector2 = Vector2(800.0, 550.0)

@export_group("Spawn Point Configuration")
## Configurable deterministic spawn positions for Slots 1 through 8 in Central Hub.
@export var spawn_positions: Array[Vector2] = [
	Vector2(800.0, 550.0), # Slot 1: Central Hub Core
	Vector2(720.0, 550.0), # Slot 2: Central Hub West
	Vector2(880.0, 550.0), # Slot 3: Central Hub East
	Vector2(800.0, 470.0), # Slot 4: Central Hub North
	Vector2(800.0, 630.0), # Slot 5: Central Hub South
	Vector2(730.0, 480.0), # Slot 6: Central Hub North-West
	Vector2(870.0, 480.0), # Slot 7: Central Hub North-East
	Vector2(730.0, 620.0)  # Slot 8: Central Hub South-West
]

## Active slot reservations: { slot_id (int) -> peer_id (int) }
var active_slot_assignments: Dictionary = {}

## Reverse lookup mapping: { peer_id (int) -> slot_id (int) }
var peer_to_slot_map: Dictionary = {}

## Tracked player instances: { peer_id (int) -> Node2D }
var tracked_players: Dictionary = {}

signal slot_assigned(peer_id: int, slot_id: int, spawn_pos: Vector2)
signal slot_freed(peer_id: int, slot_id: int)

func _ready() -> void:
	_validate_spawn_array()
	_auto_connect_network_signals()

## Automatically connects to the global NetworkManager autoload if present in the scene tree.
func _auto_connect_network_signals() -> void:
	if not is_inside_tree():
		return

	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		bind_client_network_manager(net_mgr.client)

## Binds to ClientNetworkManager signals for authoritative slot synchronization.
func bind_client_network_manager(client_mgr: Node) -> void:
	if client_mgr == null:
		return

	if client_mgr.has_signal("player_assigned") and not client_mgr.player_assigned.is_connected(_on_local_player_assigned):
		client_mgr.player_assigned.connect(_on_local_player_assigned)

	if client_mgr.has_signal("other_player_connected") and not client_mgr.other_player_connected.is_connected(_on_other_player_connected):
		client_mgr.other_player_connected.connect(_on_other_player_connected)

	if client_mgr.has_signal("other_player_disconnected") and not client_mgr.other_player_disconnected.is_connected(_on_other_player_disconnected):
		client_mgr.other_player_disconnected.connect(_on_other_player_disconnected)

	if client_mgr.has_signal("disconnected_from_server") and not client_mgr.disconnected_from_server.is_connected(_on_disconnected_from_server):
		client_mgr.disconnected_from_server.connect(_on_disconnected_from_server)

	if client_mgr.has_signal("lobby_synced") and not client_mgr.lobby_synced.is_connected(_on_lobby_synced):
		client_mgr.lobby_synced.connect(_on_lobby_synced)

## Returns the deterministic spawn coordinate for a given slot (1 to 8).
func get_spawn_position(slot_id: int) -> Vector2:
	if slot_id >= 1 and slot_id <= spawn_positions.size():
		return spawn_positions[slot_id - 1]

	push_warning("[SpawnManager] Requested invalid slot %d (Valid range: 1–%d). Returning fallback spawn." % [
		slot_id, MAX_SPAWN_SLOTS
	])

	if not spawn_positions.is_empty():
		return spawn_positions[0]
	return FALLBACK_SPAWN

## Assigns a spawn slot to a connected peer.
## If preferred_slot (e.g. from authoritative server) is provided, reserves that slot.
## Otherwise assigns the lowest available slot. Returns the assigned slot (1-8), or 0 if full.
func assign_slot(peer_id: int, preferred_slot: int = 0) -> int:
	# 1. If this peer already owns a slot, return it
	if peer_to_slot_map.has(peer_id):
		var existing_slot: int = peer_to_slot_map[peer_id]
		if preferred_slot > 0 and preferred_slot != existing_slot:
			# Reassign to preferred slot if valid and free
			if is_slot_available(preferred_slot):
				free_slot(peer_id)
				return _reserve_slot(peer_id, preferred_slot)
		return existing_slot

	# 2. Check if preferred slot is valid and available
	if preferred_slot >= 1 and preferred_slot <= MAX_SPAWN_SLOTS:
		if is_slot_available(preferred_slot):
			return _reserve_slot(peer_id, preferred_slot)
		else:
			push_warning("[SpawnManager] Preferred slot %d already occupied by peer %d. Finding alternative." % [
				preferred_slot, active_slot_assignments.get(preferred_slot, -1)
			])

	# 3. Find the lowest available slot from 1 to 8
	for s in range(1, MAX_SPAWN_SLOTS + 1):
		if is_slot_available(s):
			return _reserve_slot(peer_id, s)

	# 4. No slots available
	push_warning("[SpawnManager] Cannot assign spawn slot for peer %d: all %d slots are occupied." % [
		peer_id, MAX_SPAWN_SLOTS
	])
	return 0

## Frees the spawn slot associated with a disconnected peer so it can be reused.
## Returns the freed slot ID, or 0 if peer had no slot.
func free_slot(peer_id: int) -> int:
	if not peer_to_slot_map.has(peer_id):
		return 0

	var freed_slot: int = peer_to_slot_map[peer_id]
	peer_to_slot_map.erase(peer_id)
	active_slot_assignments.erase(freed_slot)

	if tracked_players.has(peer_id):
		var p_node = tracked_players[peer_id]
		var local_player = get_parent().get_node_or_null("Player") if is_inside_tree() else null
		if is_instance_valid(p_node) and p_node != local_player:
			p_node.queue_free()
		tracked_players.erase(peer_id)

	print("[SpawnManager] Freed spawn slot %d for disconnected peer %d." % [freed_slot, peer_id])
	slot_freed.emit(peer_id, freed_slot)
	return freed_slot

## Checks if a slot (1 to 8) is currently unoccupied.
func is_slot_available(slot_id: int) -> bool:
	if slot_id < 1 or slot_id > MAX_SPAWN_SLOTS:
		return false
	return not active_slot_assignments.has(slot_id)

## Returns the slot assigned to a peer, or 0 if unassigned.
func get_slot_for_peer(peer_id: int) -> int:
	return peer_to_slot_map.get(peer_id, 0)

## Returns the peer assigned to a slot, or 0 if unoccupied.
func get_peer_for_slot(slot_id: int) -> int:
	return active_slot_assignments.get(slot_id, 0)

## Returns total count of actively assigned slots.
func get_active_player_count() -> int:
	return active_slot_assignments.size()

## Positions a player node at its assigned spawn position and configures its identity.
func place_player(player: Node2D, slot_id: int, peer_id: int = 0) -> bool:
	if player == null:
		push_error("[SpawnManager] Cannot place null player node.")
		return false

	var target_slot: int = slot_id
	if target_slot < 1 or target_slot > MAX_SPAWN_SLOTS:
		target_slot = 1

	var spawn_pos: Vector2 = get_spawn_position(target_slot)
	player.global_position = spawn_pos

	if player.has_method("setup_player"):
		var p_name = "Player %d" % target_slot
		player.setup_player(target_slot, p_name, player.get("is_local_player"))

	if peer_id > 0:
		tracked_players[peer_id] = player

	return true

## Instantiates and attaches a remote player puppet if not already present.
func spawn_remote_player_if_needed(peer_id: int, slot: int) -> Node2D:
	if tracked_players.has(peer_id) and is_instance_valid(tracked_players[peer_id]):
		return tracked_players[peer_id]

	if PlayerScene == null:
		return null

	var remote_player = PlayerScene.instantiate() as PlayerController
	if remote_player != null:
		remote_player.name = "RemotePlayer_%d" % peer_id
		var parent_node = get_parent() if is_inside_tree() else self
		parent_node.add_child(remote_player)
		place_player(remote_player, slot, peer_id)
		remote_player.setup_player(slot, "Player %d" % slot, false)
		return remote_player
	return null

## Clears all active slot reservations and tracked player references.
func reset_all_assignments() -> void:
	var local_player = get_parent().get_node_or_null("Player") if is_inside_tree() else null
	for pid in tracked_players.keys():
		var p_node = tracked_players[pid]
		if is_instance_valid(p_node) and p_node != local_player:
			p_node.queue_free()
	active_slot_assignments.clear()
	peer_to_slot_map.clear()
	tracked_players.clear()
	print("[SpawnManager] All spawn slot assignments have been reset.")

## Overrides the 8 spawn positions with a new list of coordinates.
func configure_spawn_points(new_positions: Array[Vector2]) -> void:
	if new_positions.size() >= MAX_SPAWN_SLOTS:
		spawn_positions = new_positions.duplicate()
	else:
		push_warning("[SpawnManager] Provided array has fewer than %d slots. Supplementing defaults." % MAX_SPAWN_SLOTS)
		spawn_positions = new_positions.duplicate()
		_validate_spawn_array()

## Returns a copy of all 8 configured spawn positions.
func get_all_spawn_positions() -> Array[Vector2]:
	return spawn_positions.duplicate()

func _reserve_slot(peer_id: int, slot_id: int) -> int:
	active_slot_assignments[slot_id] = peer_id
	peer_to_slot_map[peer_id] = slot_id
	var spawn_pos = get_spawn_position(slot_id)
	print("[SpawnManager] Assigned Slot %d -> Peer %d (Spawn: %s)." % [slot_id, peer_id, str(spawn_pos)])
	slot_assigned.emit(peer_id, slot_id, spawn_pos)
	return slot_id

func _validate_spawn_array() -> void:
	while spawn_positions.size() < MAX_SPAWN_SLOTS:
		spawn_positions.append(FALLBACK_SPAWN)

# --- Network Event Callbacks ---

func _on_local_player_assigned(peer_id: int, slot: int, _total_players: int) -> void:
	assign_slot(peer_id, slot)
	var local_player = get_parent().get_node_or_null("Player") if is_inside_tree() else null
	if local_player != null:
		place_player(local_player, slot, peer_id)

func _on_other_player_connected(peer_id: int, slot: int) -> void:
	assign_slot(peer_id, slot)
	spawn_remote_player_if_needed(peer_id, slot)

func _on_other_player_disconnected(peer_id: int) -> void:
	free_slot(peer_id)

func _on_disconnected_from_server(_reason: String) -> void:
	reset_all_assignments()

func _on_lobby_synced(_state: int, _player_count: int, _ready_count: int, players_info: Array) -> void:
	var local_client_peer_id: int = 0
	var net_mgr = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		local_client_peer_id = net_mgr.client.assigned_peer_id

	var active_peers: Array[int] = []
	for p_info in players_info:
		var pid = int(p_info.get("peer_id", 0))
		var slot = int(p_info.get("player_slot", 0))
		if pid > 0:
			active_peers.append(pid)
			assign_slot(pid, slot)
			if pid != local_client_peer_id:
				spawn_remote_player_if_needed(pid, slot)

	# Clean up any stale peers no longer in the lobby
	var current_tracked = peer_to_slot_map.keys()
	for pid in current_tracked:
		if not active_peers.has(pid):
			free_slot(pid)
