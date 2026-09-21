extends Control

## In-Engine Audio & Music Test Lab for BLACKOUT
## Provides interactive buttons to test all 29 sounds, music tracks, and game scenario transitions.

const AudioRegistry = preload("res://assets/audio/audio_registry.gd")
const AudioManager = preload("res://client/audio/audio_manager.gd")

var _audio_manager: AudioManager = null
var _status_label: Label = null

func _ready() -> void:
	# Instantiate AudioManager
	_audio_manager = AudioManager.new()
	_audio_manager.name = "AudioManager"
	add_child(_audio_manager)

	_status_label = $VBoxContainer/StatusLabel
	_setup_buttons()

func _setup_buttons() -> void:
	# Scenario buttons
	$VBoxContainer/ScenarioContainer/BtnNormal.pressed.connect(func():
		_audio_manager.stop_match_audio()
		_audio_manager.play_ambience(AudioRegistry.AMBIENCE_FACILITY_HUM, 1.0)
		_audio_manager.play_music(AudioRegistry.MUSIC_NORMAL, 1.0)
		_set_status("Scenario: Normal Facility Active")
	)

	$VBoxContainer/ScenarioContainer/BtnBlackout.pressed.connect(func():
		_audio_manager.start_blackout_audio()
		_set_status("Scenario: Blackout Triggered")
	)

	$VBoxContainer/ScenarioContainer/BtnMeltdown.pressed.connect(func():
		_audio_manager.start_meltdown_audio()
		_set_status("Scenario: Meltdown Emergency Active")
	)

	$VBoxContainer/ScenarioContainer/BtnMeeting.pressed.connect(func():
		_audio_manager.stop_match_audio()
		_audio_manager.play_stinger(AudioRegistry.UI_MEETING_CALLED)
		_set_status("Scenario: Meeting Called")
	)

	$VBoxContainer/ScenarioContainer/BtnStopAll.pressed.connect(func():
		_audio_manager.stop_match_audio()
		_set_status("All Audio Stopped")
	)

	# Sound grid buttons
	var grid: GridContainer = $VBoxContainer/ScrollContainer/GridContainer
	for event_id in AudioRegistry.AUDIO_DEFINITIONS.keys():
		var def: Dictionary = AudioRegistry.get_definition(event_id)
		var btn := Button.new()
		btn.text = "%s (%s)" % [event_id, def.get("bus", "SFX")]
		btn.custom_minimum_size = Vector2(220, 36)
		var id_capture: StringName = event_id
		var cat: int = def.get("category", AudioRegistry.Category.SFX)
		btn.pressed.connect(func():
			_play_event(id_capture, cat)
		)
		grid.add_child(btn)

func _play_event(event_id: StringName, category: int) -> void:
	match category:
		AudioRegistry.Category.MUSIC:
			_audio_manager.play_music(event_id, 0.5)
			_set_status("Playing Music: %s" % event_id)
		AudioRegistry.Category.AMBIENCE:
			_audio_manager.play_ambience(event_id, 0.5)
			_set_status("Playing Ambience: %s" % event_id)
		AudioRegistry.Category.STINGER:
			_audio_manager.play_stinger(event_id)
			_set_status("Playing Stinger: %s" % event_id)
		AudioRegistry.Category.SFX:
			_audio_manager.play_sfx(event_id)
			_set_status("Playing SFX: %s" % event_id)

func _set_status(msg: String) -> void:
	if _status_label != null:
		_status_label.text = "Status: %s" % msg
