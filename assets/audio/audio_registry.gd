class_name AudioRegistry
extends RefCounted

## Audio Registry for BLACKOUT (Member 8: Audio & QA Lead)
## Defines identifiers, categories, contexts, default filepaths, audio buses,
## and procedural waveform synthesis parameters for all soundscapes, music, SFX, and stingers.

# --- BUS IDENTIFIERS ---
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_UI: StringName = &"UI"

# --- AUDIO CATEGORIES ---
enum Category {
	MUSIC,
	AMBIENCE,
	SFX,
	STINGER
}

# --- AUDIO CONTEXTS ---
enum Context {
	NORMAL,
	BLACKOUT,
	MELTDOWN,
	TASK,
	SABOTAGE,
	MEETING,
	VOTING,
	EJECTION,
	VICTORY,
	DEFEAT,
	UI
}

# --- AUDIO EVENT IDENTIFIERS ---

# 1. Music
const MUSIC_NORMAL: StringName = &"music_normal"
const MUSIC_BLACKOUT: StringName = &"music_blackout"
const MUSIC_MELTDOWN: StringName = &"music_meltdown"

# 2. Ambience
const AMBIENCE_FACILITY_HUM: StringName = &"ambience_facility_hum"
const AMBIENCE_BLACKOUT_DRONE: StringName = &"ambience_blackout_drone"
const AMBIENCE_MELTDOWN_ALARM: StringName = &"ambience_meltdown_alarm"

# 3. Blackout & Power SFX
const SFX_BLACKOUT_TRIGGER: StringName = &"sfx_blackout_trigger"
const SFX_BLACKOUT_COUNTDOWN: StringName = &"sfx_blackout_countdown"
const SFX_POWER_CUT: StringName = &"sfx_power_cut"
const SFX_POWER_RESTORE: StringName = &"sfx_power_restore"

# 4. Task & Mini-game SFX
const SFX_TASK_CLICK: StringName = &"sfx_task_click"
const SFX_TASK_SUCCESS: StringName = &"sfx_task_success"
const SFX_TASK_ERROR: StringName = &"sfx_task_error"
const SFX_TASK_PROGRESS: StringName = &"sfx_task_progress"
const SFX_DOOR_JAM: StringName = &"sfx_door_jam"
const SFX_SABOTAGE_EXECUTE: StringName = &"sfx_sabotage_execute"
const SFX_EVIDENCE_FOUND: StringName = &"sfx_evidence_found"

# 5. Social Deduction, Voting & UI SFX
const UI_CLICK: StringName = &"ui_click"
const UI_HOVER: StringName = &"ui_hover"
const UI_MEETING_CALLED: StringName = &"ui_meeting_called"
const UI_VOTING_TICK: StringName = &"ui_voting_tick"
const UI_VOTE_CAST: StringName = &"ui_vote_cast"
const UI_EJECTION_REVEAL: StringName = &"ui_ejection_reveal"
const UI_CREW_VICTORY: StringName = &"ui_crew_victory"
const UI_IMPOSTOR_VICTORY: StringName = &"ui_impostor_victory"

# 6. Stingers
const STINGER_BLACKOUT_START: StringName = &"stinger_blackout_start"
const STINGER_MEETING: StringName = &"stinger_meeting"
const STINGER_VICTORY: StringName = &"stinger_victory"
const STINGER_DEFEAT: StringName = &"stinger_defeat"

# --- ASSET METADATA & PROCEDURAL FALLBACK DEFINITIONS ---
const AUDIO_DEFINITIONS: Dictionary = {
	# --- MUSIC ---
	MUSIC_NORMAL: {
		"bus": BUS_MUSIC,
		"category": Category.MUSIC,
		"context": Context.NORMAL,
		"path": "res://assets/audio/music/normal/normal_gameplay_music.wav",
		"loop": true,
		"default_volume_db": -10.0,
		"synth_frequency": 130.81, # C3 warm pad pulse
		"synth_type": "sine",
		"duration": 4.0,
		"fade_duration": 1.5
	},
	MUSIC_BLACKOUT: {
		"bus": BUS_MUSIC,
		"category": Category.MUSIC,
		"context": Context.BLACKOUT,
		"path": "res://assets/audio/music/blackout/blackout_tension_music.wav",
		"loop": true,
		"default_volume_db": -8.0,
		"synth_frequency": 87.31, # F2 dark ostinato
		"synth_type": "sawtooth",
		"duration": 3.0,
		"fade_duration": 1.0
	},
	MUSIC_MELTDOWN: {
		"bus": BUS_MUSIC,
		"category": Category.MUSIC,
		"context": Context.MELTDOWN,
		"path": "res://assets/audio/music/meltdown/meltdown_alarm.wav",
		"loop": true,
		"default_volume_db": -6.0,
		"synth_frequency": 440.0, # A4 siren alarm
		"synth_type": "pulse",
		"duration": 1.5,
		"fade_duration": 0.5
	},

	# --- AMBIENCE ---
	AMBIENCE_FACILITY_HUM: {
		"bus": BUS_AMBIENCE,
		"category": Category.AMBIENCE,
		"context": Context.NORMAL,
		"path": "res://assets/audio/ambience/facility/facility_hum.wav",
		"loop": true,
		"default_volume_db": -12.0,
		"synth_frequency": 65.41, # C2 low hum
		"synth_type": "sine",
		"duration": 4.0,
		"fade_duration": 1.5
	},
	AMBIENCE_BLACKOUT_DRONE: {
		"bus": BUS_AMBIENCE,
		"category": Category.AMBIENCE,
		"context": Context.BLACKOUT,
		"path": "res://assets/audio/ambience/blackout/blackout_drone.wav",
		"loop": true,
		"default_volume_db": -8.0,
		"synth_frequency": 43.65, # F1 sub-bass drone
		"synth_type": "sawtooth",
		"duration": 3.0,
		"fade_duration": 1.0
	},
	AMBIENCE_MELTDOWN_ALARM: {
		"bus": BUS_AMBIENCE,
		"category": Category.AMBIENCE,
		"context": Context.MELTDOWN,
		"path": "res://assets/audio/ambience/meltdown/meltdown_drone.wav",
		"loop": true,
		"default_volume_db": -7.0,
		"synth_frequency": 329.63, # E4 tense resonance
		"synth_type": "pulse",
		"duration": 2.0,
		"fade_duration": 0.5
	},

	# --- BLACKOUT & POWER SFX ---
	SFX_BLACKOUT_TRIGGER: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.BLACKOUT,
		"path": "res://assets/audio/sfx/blackout/blackout_trigger.wav",
		"loop": false,
		"default_volume_db": -4.0,
		"synth_frequency": 220.0,
		"synth_type": "noise",
		"duration": 0.8
	},
	SFX_BLACKOUT_COUNTDOWN: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.BLACKOUT,
		"path": "res://assets/audio/sfx/blackout/blackout_countdown.wav",
		"loop": false,
		"default_volume_db": -2.0,
		"synth_frequency": 880.0, # High warning beep
		"synth_type": "square",
		"duration": 0.25
	},
	SFX_POWER_CUT: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.BLACKOUT,
		"path": "res://assets/audio/sfx/blackout/power_cut.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 110.0,
		"synth_type": "noise",
		"duration": 1.2
	},
	SFX_POWER_RESTORE: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.BLACKOUT,
		"path": "res://assets/audio/sfx/blackout/power_restore.wav",
		"loop": false,
		"default_volume_db": -3.0,
		"synth_frequency": 523.25,
		"synth_type": "sine",
		"duration": 1.5
	},

	# --- TASK SFX ---
	SFX_TASK_CLICK: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.TASK,
		"path": "res://assets/audio/sfx/tasks/task_click.wav",
		"loop": false,
		"default_volume_db": -10.0,
		"synth_frequency": 1200.0,
		"synth_type": "triangle",
		"duration": 0.05
	},
	SFX_TASK_SUCCESS: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.TASK,
		"path": "res://assets/audio/sfx/tasks/task_success.wav",
		"loop": false,
		"default_volume_db": -4.0,
		"synth_frequency": 784.0, # G5 chime
		"synth_type": "sine",
		"duration": 0.6
	},
	SFX_TASK_ERROR: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.TASK,
		"path": "res://assets/audio/sfx/tasks/task_error.wav",
		"loop": false,
		"default_volume_db": -6.0,
		"synth_frequency": 150.0, # Low buzz
		"synth_type": "sawtooth",
		"duration": 0.4
	},
	SFX_TASK_PROGRESS: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.TASK,
		"path": "res://assets/audio/sfx/tasks/task_progress.wav",
		"loop": false,
		"default_volume_db": -8.0,
		"synth_frequency": 659.25,
		"synth_type": "sine",
		"duration": 0.15
	},

	# --- SABOTAGE SFX ---
	SFX_DOOR_JAM: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.SABOTAGE,
		"path": "res://assets/audio/sfx/sabotage/door_jam.wav",
		"loop": false,
		"default_volume_db": -4.0,
		"synth_frequency": 280.0,
		"synth_type": "noise",
		"duration": 0.7
	},
	SFX_SABOTAGE_EXECUTE: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.SABOTAGE,
		"path": "res://assets/audio/sfx/sabotage/sabotage_execute.wav",
		"loop": false,
		"default_volume_db": -5.0,
		"synth_frequency": 180.0,
		"synth_type": "square",
		"duration": 0.8
	},
	SFX_EVIDENCE_FOUND: {
		"bus": BUS_SFX,
		"category": Category.SFX,
		"context": Context.MEETING,
		"path": "res://assets/audio/sfx/meeting/evidence_found.wav",
		"loop": false,
		"default_volume_db": -6.0,
		"synth_frequency": 659.25, # E5 cue
		"synth_type": "sine",
		"duration": 0.7
	},

	# --- SOCIAL DEDUCTION & UI ---
	UI_CLICK: {
		"bus": BUS_UI,
		"category": Category.SFX,
		"context": Context.UI,
		"path": "res://assets/audio/sfx/ui/ui_click.wav",
		"loop": false,
		"default_volume_db": -12.0,
		"synth_frequency": 1000.0,
		"synth_type": "triangle",
		"duration": 0.04
	},
	UI_HOVER: {
		"bus": BUS_UI,
		"category": Category.SFX,
		"context": Context.UI,
		"path": "res://assets/audio/sfx/ui/ui_hover.wav",
		"loop": false,
		"default_volume_db": -16.0,
		"synth_frequency": 800.0,
		"synth_type": "sine",
		"duration": 0.03
	},
	UI_MEETING_CALLED: {
		"bus": BUS_UI,
		"category": Category.STINGER,
		"context": Context.MEETING,
		"path": "res://assets/audio/ui/meeting_called.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 587.33, # D5 alarm stinger
		"synth_type": "pulse",
		"duration": 2.0
	},
	UI_VOTING_TICK: {
		"bus": BUS_UI,
		"category": Category.SFX,
		"context": Context.VOTING,
		"path": "res://assets/audio/sfx/voting/voting_tick.wav",
		"loop": false,
		"default_volume_db": -8.0,
		"synth_frequency": 900.0,
		"synth_type": "square",
		"duration": 0.08
	},
	UI_VOTE_CAST: {
		"bus": BUS_UI,
		"category": Category.SFX,
		"context": Context.VOTING,
		"path": "res://assets/audio/sfx/voting/vote_cast.wav",
		"loop": false,
		"default_volume_db": -5.0,
		"synth_frequency": 493.88,
		"synth_type": "triangle",
		"duration": 0.2
	},
	UI_EJECTION_REVEAL: {
		"bus": BUS_UI,
		"category": Category.STINGER,
		"context": Context.EJECTION,
		"path": "res://assets/audio/sfx/ejection/ejection_reveal.wav",
		"loop": false,
		"default_volume_db": -2.0,
		"synth_frequency": 220.0,
		"synth_type": "sawtooth",
		"duration": 2.5
	},
	UI_CREW_VICTORY: {
		"bus": BUS_UI,
		"category": Category.STINGER,
		"context": Context.VICTORY,
		"path": "res://assets/audio/ui/crew_victory.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 523.25,
		"synth_type": "sine",
		"duration": 3.0
	},
	UI_IMPOSTOR_VICTORY: {
		"bus": BUS_UI,
		"category": Category.STINGER,
		"context": Context.DEFEAT,
		"path": "res://assets/audio/ui/impostor_victory.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 130.81,
		"synth_type": "sawtooth",
		"duration": 3.0
	},

	# --- STINGERS ---
	STINGER_BLACKOUT_START: {
		"bus": BUS_SFX,
		"category": Category.STINGER,
		"context": Context.BLACKOUT,
		"path": "res://assets/audio/stingers/blackout_start/stinger_blackout_start.wav",
		"loop": false,
		"default_volume_db": -1.0,
		"synth_frequency": 185.0, # F#3 drop
		"synth_type": "sawtooth",
		"duration": 1.8
	},
	STINGER_MEETING: {
		"bus": BUS_UI,
		"category": Category.STINGER,
		"context": Context.MEETING,
		"path": "res://assets/audio/stingers/meeting/stinger_meeting.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 587.33,
		"synth_type": "pulse",
		"duration": 2.0
	},
	STINGER_VICTORY: {
		"bus": BUS_UI,
		"category": Category.STINGER,
		"context": Context.VICTORY,
		"path": "res://assets/audio/stingers/victory/stinger_victory.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 659.25, # E5 triumph chord
		"synth_type": "sine",
		"duration": 3.0
	},
	STINGER_DEFEAT: {
		"bus": BUS_UI,
		"category": Category.STINGER,
		"context": Context.DEFEAT,
		"path": "res://assets/audio/stingers/defeat/stinger_defeat.wav",
		"loop": false,
		"default_volume_db": 0.0,
		"synth_frequency": 110.0, # A2 dark failure
		"synth_type": "sawtooth",
		"duration": 3.2
	}
}

static func get_definition(event_id: StringName) -> Dictionary:
	return AUDIO_DEFINITIONS.get(event_id, {})

static func has_event(event_id: StringName) -> bool:
	return AUDIO_DEFINITIONS.has(event_id)

static func get_events_by_category(category: Category) -> Array[StringName]:
	var result: Array[StringName] = []
	for key in AUDIO_DEFINITIONS.keys():
		if AUDIO_DEFINITIONS[key].get("category") == category:
			result.append(key)
	return result

static func get_events_by_context(context: Context) -> Array[StringName]:
	var result: Array[StringName] = []
	for key in AUDIO_DEFINITIONS.keys():
		if AUDIO_DEFINITIONS[key].get("context") == context:
			result.append(key)
	return result
