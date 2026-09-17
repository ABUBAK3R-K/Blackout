class_name MeetingConfig
extends RefCounted

## Centralized configuration and constants for the Authoritative Meeting & Voting System.

## Default duration for the discussion phase in seconds.
const DEFAULT_DISCUSSION_DURATION_SEC: float = 30.0

## Default duration for the voting phase in seconds.
const DEFAULT_VOTING_DURATION_SEC: float = 30.0

## Sentinel target ID representing a 'Skip' vote.
const VOTE_SKIP: int = -1

enum MeetingPhase {
	NONE,
	DISCUSSION,
	VOTING,
	RESULTS
}

static func get_meeting_phase_name(phase: MeetingPhase) -> String:
	match phase:
		MeetingPhase.DISCUSSION:
			return "DISCUSSION"
		MeetingPhase.VOTING:
			return "VOTING"
		MeetingPhase.RESULTS:
			return "RESULTS"
		_:
			return "NONE"
