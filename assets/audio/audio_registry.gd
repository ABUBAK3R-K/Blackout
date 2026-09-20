class_name AudioRegistry
extends RefCounted

## Audio Registry for BLACKOUT (Member 8: Audio & QA Lead)
## Defines identifiers, default filepaths, audio buses, and procedural synthesis parameters
## for ambient soundscapes, gameplay SFX, and UI event stingers.

# --- BUS IDENTIFIERS ---
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_UI: StringName = &"UI"

# --- AUDIO EVENT IDENTIFIERS ---
# Ambience
const AMBIENCE_FACILITY_HUM: StringName = &"ambience_facility_hum"
const AMBIENCE_BLACKOUT_DRONE: StringName = &"ambience_blackout_drone"
const AMBIENCE_MELTDOWN_ALARM: StringName = &"ambience_meltdown_alarm"

# Blackout & Power SFX
const SFX_BLACKOUT_TRIGGER: StringName = &"sfx_blackout_trigger"
const SFX_BLACKOUT_COUNTDOWN: StringName = &"sfx_blackout_countdown"
const SFX_POWER_CUT: StringName = &"sfx_power_cut"
const SFX_POWER_RESTORE: StringName = &"sfx_power_restore"

# Task & Mini-game SFX
const SFX_TASK_CLICK: StringName = &"sfx_task_click"
const SFX_TASK_SUCCESS: StringName = &"sfx_task_success"
const SFX_TASK_ERROR: StringName = &"sfx_task_error"
const SFX_DOOR_JAM: StringName = &"sfx_door_jam"
const SFX_SABOTAGE_EXECUTE: StringName = &"sfx_sabotage_execute"
const SFX_EVIDENCE_FOUND: StringName = &"sfx_evidence_found"

# Social Deduction & UI
const UI_CLICK: StringName = &"ui_click"
const UI_MEETING_CALLED: StringName = &"ui_meeting_called"
const UI_VOTING_TICK: StringName = &"ui_voting_tick"
const UI_EJECTION_REVEAL: StringName = &"ui_ejection_reveal"
const UI_CREW_VICTORY: StringName = &"ui_crew_victory"
const UI_IMPOSTOR_VICTORY: StringName = &"ui_impostor_victory"

# --- ASSET METADATA & PROCEDURAL FALLBACK DEFINITIONS ---
const AUDIO_DEFINITIONS: Dictionary = {
	AMBIENCE_FACILITY_HUM: {
		"bus": BUS_AMBIENCE,
		"path": "res://assets/audio/ambience/facility_hum.ogg",
		"loop": true,
		"default_volume_db": -12.0,
		"synth_frequency": 65.41, # C2 low drone
		"synth_type": "sine",
		"fade_duration": 1.5
	},
	AMBIENCE_BLACKOUT_DRONE: {
		"bus": BUS_AMBIENCE,
		"path": "res://assets/audio/ambience/blackout_drone.ogg",
		"loop": true,
		"default_volume_db": -8.0,
		"synth_frequency": 43.65, # F1 dark drone
		"synth_type": "sawtooth",
		"fade_duration": 1.0
	},
	AMBIENCE_MELTDOWN_ALARM: {
		"bus": BUS_MUSIC,
		"path": "res://assets/audio/music/meltdown_alarm.ogg",
		"loop": true,
		"default_volume_db": -6.0,
		"synth_frequency": 440.0, # A4 siren
		"synth_type": "pulse",
		"fade_duration": 0.5
	},
	SFX_BLACKOUT_TRIGGER: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/blackout_trigger.wav",
		"loop": false,
		"default_volume_db": -4.0,
		"synth_frequency": 220.0,
		"synth_type": "noise",
		"duration": 0.8
	},
	SFX_BLACKOUT_COUNTDOWN: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/blackout_countdown.wav",
		"loop": false,
		"default_volume_db": -2.0,
		"synth_frequency": 880.0, # High warning beep
		"synth_type": "square",
		"duration": 0.25
	},
	SFX_POWER_CUT: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/power_cut.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 110.0,
		"synth_type": "noise",
		"duration": 1.2
	},
	SFX_POWER_RESTORE: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/power_restore.wav",
		"loop": false,
		"default_volume_db": -3.0,
		"synth_frequency": 523.25,
		"synth_type": "sine",
		"duration": 1.5
	},
	SFX_TASK_CLICK: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/task_click.wav",
		"loop": false,
		"default_volume_db": -10.0,
		"synth_frequency": 1200.0,
		"synth_type": "triangle",
		"duration": 0.05
	},
	SFX_TASK_SUCCESS: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/task_success.wav",
		"loop": false,
		"default_volume_db": -4.0,
		"synth_frequency": 784.0, # G5 chime
		"synth_type": "sine",
		"duration": 0.6
	},
	SFX_TASK_ERROR: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/task_error.wav",
		"loop": false,
		"default_volume_db": -6.0,
		"synth_frequency": 150.0, # Low buzz
		"synth_type": "sawtooth",
		"duration": 0.4
	},
	SFX_DOOR_JAM: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/door_jam.wav",
		"loop": false,
		"default_volume_db": -4.0,
		"synth_frequency": 280.0,
		"synth_type": "noise",
		"duration": 0.7
	},
	SFX_SABOTAGE_EXECUTE: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/sabotage_execute.wav",
		"loop": false,
		"default_volume_db": -5.0,
		"synth_frequency": 180.0,
		"synth_type": "square",
		"duration": 0.8
	},
	SFX_EVIDENCE_FOUND: {
		"bus": BUS_SFX,
		"path": "res://assets/audio/sfx/evidence_found.wav",
		"loop": false,
		"default_volume_db": -6.0,
		"synth_frequency": 659.25, # E5 cue
		"synth_type": "sine",
		"duration": 0.7
	},
	UI_CLICK: {
		"bus": BUS_UI,
		"path": "res://assets/audio/ui/ui_click.wav",
		"loop": false,
		"default_volume_db": -12.0,
		"synth_frequency": 1000.0,
		"synth_type": "triangle",
		"duration": 0.04
	},
	UI_MEETING_CALLED: {
		"bus": BUS_UI,
		"path": "res://assets/audio/ui/meeting_called.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 587.33, # D5 alarm stinger
		"synth_type": "pulse",
		"duration": 2.0
	},
	UI_VOTING_TICK: {
		"bus": BUS_UI,
		"path": "res://assets/audio/ui/voting_tick.wav",
		"loop": false,
		"default_volume_db": -8.0,
		"synth_frequency": 900.0,
		"synth_type": "square",
		"duration": 0.08
	},
	UI_EJECTION_REVEAL: {
		"bus": BUS_UI,
		"path": "res://assets/audio/ui/ejection_reveal.wav",
		"loop": false,
		"default_volume_db": -2.0,
		"synth_frequency": 220.0,
		"synth_type": "sawtooth",
		"duration": 2.5
	},
	UI_CREW_VICTORY: {
		"bus": BUS_UI,
		"path": "res://assets/audio/ui/crew_victory.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 523.25,
		"synth_type": "sine",
		"duration": 3.0
	},
	UI_IMPOSTOR_VICTORY: {
		"bus": BUS_UI,
		"path": "res://assets/audio/ui/impostor_victory.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 130.81,
		"synth_type": "sawtooth",
		"duration": 3.0
	}
}

static func get_definition(event_id: StringName) -> Dictionary:
	return AUDIO_DEFINITIONS.get(event_id, {})

static func has_event(event_id: StringName) -> bool:
	return AUDIO_DEFINITIONS.has(event_id)
