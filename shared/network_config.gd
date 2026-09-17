class_name NetworkConfig
extends RefCounted

## Central network configuration and constants for BLACKOUT.
## All network settings, limits, game states, roles, and status codes are managed here.

const DEFAULT_PORT: int = 7777
const DEFAULT_HOST: String = "127.0.0.1"
const MAX_PLAYERS: int = 8
const MIN_PLAYERS: int = 8
const IMPOSTOR_COUNT: int = 1
const CREW_COUNT: int = 7

## Socket limit allows the 9th+ connection to establish handshake so the authoritative
## server can explicitly send the rejection RPC before dropping the socket.
const MAX_SOCKET_CONNECTIONS: int = 16

enum GameState {
	LOBBY,
	ROLE_ASSIGNMENT,
	INITIAL_TASK_PHASE,
	BLACKOUT_AVAILABLE,
	BLACKOUT_ACTIVE,
	POST_BLACKOUT_INVESTIGATION,
	MEETING,
	VOTING,
	MELTDOWN,
	GAME_OVER
}

enum PlayerRole {
	NONE,
	CREW,
	IMPOSTOR
}

enum ConnectionStatus {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	REJECTED,
	FAILED
}

enum DisconnectReason {
	USER_REQUESTED,
	SERVER_STOPPED,
	SERVER_FULL,
	CONNECTION_LOST,
	KICKED
}

static func get_game_state_name(state: GameState) -> String:
	match state:
		GameState.LOBBY:
			return "LOBBY"
		GameState.ROLE_ASSIGNMENT:
			return "ROLE_ASSIGNMENT"
		GameState.INITIAL_TASK_PHASE:
			return "INITIAL_TASK_PHASE"
		GameState.BLACKOUT_AVAILABLE:
			return "BLACKOUT_AVAILABLE"
		GameState.BLACKOUT_ACTIVE:
			return "BLACKOUT_ACTIVE"
		GameState.POST_BLACKOUT_INVESTIGATION:
			return "POST_BLACKOUT_INVESTIGATION"
		GameState.MEETING:
			return "MEETING"
		GameState.VOTING:
			return "VOTING"
		GameState.MELTDOWN:
			return "MELTDOWN"
		GameState.GAME_OVER:
			return "GAME_OVER"
		_:
			return "UNKNOWN"

static func get_role_name(role: PlayerRole) -> String:
	match role:
		PlayerRole.CREW:
			return "CREW"
		PlayerRole.IMPOSTOR:
			return "IMPOSTOR"
		_:
			return "NONE"
