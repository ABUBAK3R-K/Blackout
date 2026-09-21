class_name TaskManager
extends RefCounted

## Server-side authoritative manager for task definitions, player assignments,
## completion validation, and Impostor prerequisite tracking.

const NetworkConfig = preload("res://shared/network_config.gd")
const TaskConfig = preload("res://shared/task_config.gd")
const TaskDefinition = preload("res://shared/task_definition.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")

var tasks_by_id: Dictionary = {}        # { task_id (String) -> TaskDefinition }
var tasks_by_peer: Dictionary = {}      # { peer_id (int) -> Array[TaskDefinition] }

var impostor_peer_id: int = 0
var impostor_prerequisite_task_ids: Array[String] = []

var crew_task_count: int = TaskConfig.DEFAULT_CREW_TASK_COUNT
var impostor_prerequisite_count: int = TaskConfig.DEFAULT_IMPOSTOR_PREREQUISITE_COUNT

func clear() -> void:
	tasks_by_id.clear()
	tasks_by_peer.clear()
	impostor_peer_id = 0
	impostor_prerequisite_task_ids.clear()

## Authoritatively assigns tasks to all connected players.
## Crew members receive crew_task_count tasks; Impostor(s) receive impostor_prerequisite_count tasks.
func assign_tasks(connected_players: Dictionary) -> bool:
	clear()

	if connected_players.is_empty():
		push_warning("[TaskManager] Cannot assign tasks: no connected players.")
		return false

	var crew_peers: Array = []
	var impostor_peers: Array = []

	for pid in connected_players.keys():
		var p_data: PlayerConnectionData = connected_players[pid]
		if p_data.role == NetworkConfig.PlayerRole.IMPOSTOR:
			impostor_peers.append(pid)
		else:
			crew_peers.append(pid)

	var all_task_types = TaskConfig.get_all_task_types()

	# Assign tasks to each Crew member
	for pid in crew_peers:
		tasks_by_peer[pid] = []
		var available_types = all_task_types.duplicate()
		available_types.shuffle()

		for i in range(crew_task_count):
			var type_id = available_types[i % available_types.size()]
			var info = TaskConfig.get_task_info(type_id)
			var task_id = "task_%s_p%d_%d" % [type_id, pid, i]

			var task = TaskDefinition.new(
				task_id,
				type_id,
				str(info.get("display_name", type_id)),
				str(info.get("category", "general")),
				pid,
				false
			)

			tasks_by_id[task_id] = task
			tasks_by_peer[pid].append(task)

	# Assign prerequisite tasks to Impostor(s)
	for imp_pid in impostor_peers:
		impostor_peer_id = imp_pid
		tasks_by_peer[imp_pid] = []
		var impostor_types = all_task_types.duplicate()
		impostor_types.shuffle()

		for i in range(impostor_prerequisite_count):
			var type_id = impostor_types[i % impostor_types.size()]
			var info = TaskConfig.get_task_info(type_id)
			var task_id = "task_%s_p%d_%d" % [type_id, imp_pid, i]

			var task = TaskDefinition.new(
				task_id,
				type_id,
				str(info.get("display_name", type_id)),
				str(info.get("category", "general")),
				imp_pid,
				true
			)

			tasks_by_id[task_id] = task
			tasks_by_peer[imp_pid].append(task)
			impostor_prerequisite_task_ids.append(task_id)

	print("[TaskManager] Task assignment complete: %d Crew (%d tasks each), %d Impostor (%d prerequisite tasks). Total task instances: %d." % [
		crew_peers.size(), crew_task_count, impostor_peers.size(), impostor_prerequisite_count, tasks_by_id.size()
	])
	return true

func get_player_tasks(peer_id: int) -> Array:
	return tasks_by_peer.get(peer_id, [])

func get_task(task_id: String) -> TaskDefinition:
	return tasks_by_id.get(task_id, null)

## Validates and executes a task completion request from a client.
func complete_task(peer_id: int, task_id: String, current_state: NetworkConfig.GameState) -> Dictionary:
	if not tasks_by_id.has(task_id):
		var err_msg = "Task completion rejected: unknown task ID '%s'." % task_id
		push_warning("[TaskManager] %s" % err_msg)
		return {"success": false, "error": err_msg}

	var task: TaskDefinition = tasks_by_id[task_id]

	if task.assigned_peer_id != peer_id:
		var err_msg = "Task completion rejected: player %d attempted to complete task '%s' owned by player %d." % [
			peer_id, task_id, task.assigned_peer_id
		]
		push_warning("[TaskManager] %s" % err_msg)
		return {"success": false, "error": err_msg}

	if task.is_completed:
		var err_msg = "Task completion rejected: task '%s' is already completed." % task_id
		push_warning("[TaskManager] %s" % err_msg)
		return {"success": false, "error": err_msg}

	var is_impostor: bool = (peer_id == impostor_peer_id)

	# State validation:
	# - Impostor prerequisite tasks can ONLY be completed during INITIAL_TASK_PHASE.
	# - Crew tasks can be completed during INITIAL_TASK_PHASE, BLACKOUT_AVAILABLE, and BLACKOUT_ACTIVE (design.md §3.5.1).
	# - Any other match state (LOBBY, POST_BLACKOUT_INVESTIGATION, MEETING, VOTING, MELTDOWN, GAME_OVER) is rejected.
	if is_impostor or task.is_impostor_prerequisite:
		if current_state != NetworkConfig.GameState.INITIAL_TASK_PHASE:
			var err_msg = "Task completion rejected: current match state is %s (Expected: INITIAL_TASK_PHASE)." % NetworkConfig.get_game_state_name(current_state)
			push_warning("[TaskManager] %s" % err_msg)
			return {"success": false, "error": err_msg}
	else:
		var valid_crew_states = [
			NetworkConfig.GameState.INITIAL_TASK_PHASE,
			NetworkConfig.GameState.BLACKOUT_AVAILABLE,
			NetworkConfig.GameState.BLACKOUT_ACTIVE
		]
		if not valid_crew_states.has(current_state):
			var err_msg = "Task completion rejected: current match state is %s (Expected: INITIAL_TASK_PHASE, BLACKOUT_AVAILABLE, or BLACKOUT_ACTIVE)." % NetworkConfig.get_game_state_name(current_state)
			push_warning("[TaskManager] %s" % err_msg)
			return {"success": false, "error": err_msg}

	# Authoritatively mark completed
	task.is_completed = true
	task.completed_at = Time.get_unix_time_from_system()

	var all_prereqs_done: bool = are_all_impostor_prerequisites_completed() if is_impostor else false

	print("[TaskManager] Task '%s' (%s) marked COMPLETED by player %d (Prereq: %s)." % [
		task.display_name, task_id, peer_id, str(task.is_impostor_prerequisite)
	])

	return {
		"success": true,
		"task": task,
		"is_impostor": is_impostor,
		"all_prereqs_completed": all_prereqs_done
	}

func are_all_impostor_prerequisites_completed() -> bool:
	if impostor_prerequisite_task_ids.is_empty():
		return false

	for tid in impostor_prerequisite_task_ids:
		var task: TaskDefinition = tasks_by_id.get(tid, null)
		if task == null or not task.is_completed:
			return false

	return true

func get_impostor_completed_prereq_count() -> int:
	var count: int = 0
	for tid in impostor_prerequisite_task_ids:
		var task: TaskDefinition = tasks_by_id.get(tid, null)
		if task != null and task.is_completed:
			count += 1
	return count

func handle_player_disconnect(_peer_id: int) -> void:
	# Retain existing task definitions without state corruption
	pass
