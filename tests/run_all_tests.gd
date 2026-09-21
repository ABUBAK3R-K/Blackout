extends SceneTree

## Master Test Runner & QA Suite Manifest for BLACKOUT
## Authored & Maintained by Member 8 (Sahil — Audio Designer & QA / Production Lead)
##
## Tracks and coordinates all 13 automated test suites across:
##   1. Foundation & Backend State (Steps 2–10)
##   2. Server-Authority & Anti-Cheat Validation Suites (Member 8 QA)

const TEST_SUITES: Array[Dictionary] = [
	{
		"id": "step_2",
		"name": "Multiplayer Server & Connection Foundation",
		"script": "res://tests/test_multiplayer_server.gd",
		"category": "Backend Core",
		"target_tests": 8
	},
	{
		"id": "step_3",
		"name": "Lobby Lifecycle & 8-Player Ready-Up",
		"script": "res://tests/test_lobby_system.gd",
		"category": "Session Management",
		"target_tests": 10
	},
	{
		"id": "step_4",
		"name": "Role Assignment & Secret Reveal Authority",
		"script": "res://tests/test_role_assignment.gd",
		"category": "Security & Roles",
		"target_tests": 10
	},
	{
		"id": "step_5",
		"name": "Authoritative Task System & Assignment",
		"script": "res://tests/test_task_system.gd",
		"category": "Gameplay Tasks",
		"target_tests": 20
	},
	{
		"id": "step_6",
		"name": "Blackout Core & Remote Trigger Countdown",
		"script": "res://tests/test_blackout_system.gd",
		"category": "Blackout Mechanics",
		"target_tests": 23
	},
	{
		"id": "step_7",
		"name": "Recovery Systems & Impostor Blackout Objectives",
		"script": "res://tests/test_blackout_recovery_objectives.gd",
		"category": "Blackout Mechanics",
		"target_tests": 34
	},
	{
		"id": "step_8",
		"name": "Evidence Generation & Investigation System",
		"script": "res://tests/test_evidence_system.gd",
		"category": "Evidence & Investigation",
		"target_tests": 30
	},
	{
		"id": "step_9",
		"name": "Emergency Meeting & Authoritative Voting Resolution",
		"script": "res://tests/test_meeting_voting_system.gd",
		"category": "Social Deduction",
		"target_tests": 30
	},
	{
		"id": "step_10",
		"name": "Meltdown Protocol & Deterministic Endgame System",
		"script": "res://tests/test_meltdown_system.gd",
		"category": "Endgame & Meltdown",
		"target_tests": 28
	},
	# --- Dedicated Member 8 Anti-Cheat Test Suites ---
	{
		"id": "qa_anti_cheat_tasks",
		"name": "Anti-Cheat: Task Spoofing & Replay Mitigation",
		"script": "res://tests/server_authority_tests/test_anti_cheat_tasks.gd",
		"category": "QA Server Authority",
		"target_tests": 5
	},
	{
		"id": "qa_anti_cheat_blackout",
		"name": "Anti-Cheat: Blackout Trigger & Recovery Authority",
		"script": "res://tests/server_authority_tests/test_anti_cheat_blackout.gd",
		"category": "QA Server Authority",
		"target_tests": 6
	},
	{
		"id": "qa_anti_cheat_voting",
		"name": "Anti-Cheat: Meeting Hijack & Vote Spam Mitigation",
		"script": "res://tests/server_authority_tests/test_anti_cheat_voting.gd",
		"category": "QA Server Authority",
		"target_tests": 5
	},
	{
		"id": "qa_anti_cheat_meltdown",
		"name": "Anti-Cheat: Meltdown Sabotage & Endgame Lockdown",
		"script": "res://tests/server_authority_tests/test_anti_cheat_meltdown.gd",
		"category": "QA Server Authority",
		"target_tests": 6
	},
	{
		"id": "qa_anti_cheat_roles",
		"name": "Anti-Cheat: Role Assignment & Identity Authority",
		"script": "res://tests/server_authority_tests/test_anti_cheat_roles.gd",
		"category": "QA Server Authority",
		"target_tests": 7
	},
	{
		"id": "qa_anti_cheat_timers",
		"name": "Anti-Cheat: Timers, Disconnects & Input Validation",
		"script": "res://tests/server_authority_tests/test_anti_cheat_timers.gd",
		"category": "QA Server Authority",
		"target_tests": 8
	},
	{
		"id": "qa_audio_integration",
		"name": "Audio Manager & Gameplay Audio Bridge Integration",
		"script": "res://tests/test_audio_manager.gd",
		"category": "Audio & Presentation",
		"target_tests": 11
	}
]

var total_suites: int = 0
var total_expected_tests: int = 0

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — QA MASTER TEST MANIFEST & RUNNER")
	print("  Maintained by Member 8 (Sahil: Audio & QA / Production Lead)")
	print("========================================================\n")
	
	total_suites = TEST_SUITES.size()
	for suite in TEST_SUITES:
		total_expected_tests += suite["target_tests"]
	
	print("  Configured Test Suites: %d" % total_suites)
	print("  Total Verification Tests: %d\n" % total_expected_tests)
	
	print("--------------------------------------------------------")
	print("  SUITE REGISTRY:")
	print("--------------------------------------------------------")
	for i in range(total_suites):
		var s: Dictionary = TEST_SUITES[i]
		print("  [%2d/%2d] [%s] %s (%d tests)" % [
			i + 1,
			total_suites,
			s["category"],
			s["name"],
			s["target_tests"]
		])
		print("         Script: %s" % s["script"])
	print("--------------------------------------------------------\n")
	
	print("[BLACKOUT QA] To run a specific suite headlessly in Godot 4:")
	print("  godot --headless -s tests/server_authority_tests/test_anti_cheat_tasks.gd\n")
	
	quit(0)
