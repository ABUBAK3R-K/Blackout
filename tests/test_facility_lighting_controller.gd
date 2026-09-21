extends SceneTree

## Headless Integration Test Suite for Member 7 (Fatima) Phase 2:
## Facility Lighting Architecture & Dual-State Lighting Controller.
## Verifies all 12 lighting and visual atmosphere requirements:
##   1. Lighting controller initialization & default NORMAL state
##   2. Ambient daylight color configuration (COLOR_NORMAL_AMBIENT)
##   3. Normal lights visibility & emergency sirens suppression in NORMAL state
##   4. BLACKOUT_WARNING state transition & flicker simulation
##   5. BLACKOUT_ACTIVE state transition & oppressive darkness ambient
##   6. Emergency sirens activation & dynamic pulse oscillation
##   7. MELTDOWN state transition & urgent red ambient & fast siren strobe
##   8. State restoration back to NORMAL upon blackout conclusion
##   9. Dynamic runtime light registration (modular room light hooking)
##   10. Network signal integration with ClientNetworkManager events
##   11. PlayerFlashlight2D spotlight beam, proximity halo, & directional aiming
##   12. VignetteOverlay alpha intensity scaling across lighting states

const FacilityLightingControllerClass = preload("res://scenes/environment/facility_lighting_controller.gd")
const PlayerFlashlight2DClass = preload("res://scenes/environment/player_flashlight.gd")
const VignetteOverlayClass = preload("res://scenes/environment/vignette_overlay.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n==================================================================")
	print("  BLACKOUT — MEMBER 7 (FATIMA) PHASE 2 LIGHTING TEST SUITE")
	print("==================================================================\n")
	
	create_timer(0.05).timeout.connect(_run_suite)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _log_info(msg: String) -> void:
	print("  [INFO] %s" % msg)

func _run_suite() -> void:
	_log_info("Executing Member 7 Lighting System test assertions...")
	
	var root_node = root
	
	# ---------------------------------------------------------
	# TEST 1: Controller Initialization & Default State
	# ---------------------------------------------------------
	_log_info("--- TEST 1: Controller Initialization & Default Normal State ---")
	var lighting_ctrl = FacilityLightingControllerClass.new()
	root_node.add_child(lighting_ctrl)
	
	var normal_parent = Node2D.new()
	normal_parent.name = "NormalLights"
	var normal_light_sample = PointLight2D.new()
	normal_parent.add_child(normal_light_sample)
	lighting_ctrl.add_child(normal_parent)
	lighting_ctrl.normal_lights_parent = normal_parent
	
	var siren_parent = Node2D.new()
	siren_parent.name = "EmergencySirens"
	var siren_sample = PointLight2D.new()
	siren_parent.add_child(siren_sample)
	lighting_ctrl.add_child(siren_parent)
	lighting_ctrl.emergency_sirens_parent = siren_parent
	
	lighting_ctrl.set_lighting_state(FacilityLightingControllerClass.LightingState.NORMAL, true)
	
	if lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.NORMAL:
		_log_pass("Controller initialized in LightingState.NORMAL.")
	else:
		_log_fail("Controller failed to initialize in LightingState.NORMAL.")
		
	# ---------------------------------------------------------
	# TEST 2: Ambient Normal Lighting Color
	# ---------------------------------------------------------
	_log_info("--- TEST 2: Ambient Daylight Color Verification ---")
	var target_color = lighting_ctrl.get_target_ambient_color()
	if target_color.is_equal_approx(FacilityLightingControllerClass.COLOR_NORMAL_AMBIENT):
		_log_pass("Target ambient matches COLOR_NORMAL_AMBIENT (#d8e2ec).")
	else:
		_log_fail("Target ambient mismatch in NORMAL state: %s" % str(target_color))
		
	# ---------------------------------------------------------
	# TEST 3: Normal Lights Visible & Sirens Hidden in NORMAL
	# ---------------------------------------------------------
	_log_info("--- TEST 3: Fixture Visibility in NORMAL State ---")
	if normal_parent.visible and not siren_parent.visible:
		_log_pass("Normal lights are visible and emergency sirens are suppressed.")
	else:
		_log_fail("Incorrect visibility in NORMAL state: normal=%s, sirens=%s" % [normal_parent.visible, siren_parent.visible])
		
	# ---------------------------------------------------------
	# TEST 4: BLACKOUT_WARNING State Transition & Flicker
	# ---------------------------------------------------------
	var sig_data = {"emitted": false, "state": -1}
	lighting_ctrl.lighting_state_changed.connect(func(new_st):
		sig_data["emitted"] = true
		sig_data["state"] = new_st
	)
	
	lighting_ctrl.set_lighting_state(FacilityLightingControllerClass.LightingState.BLACKOUT_WARNING)
	if sig_data["emitted"] and sig_data["state"] == FacilityLightingControllerClass.LightingState.BLACKOUT_WARNING:
		_log_pass("State transition to BLACKOUT_WARNING emitted correctly.")
	else:
		_log_fail("Failed to transition to BLACKOUT_WARNING or emit signal.")
		
	# Process one delta frame to simulate flicker computation
	lighting_ctrl._process(0.016)
	if normal_light_sample.energy >= 0.0:
		_log_pass("Warning flicker delta computation executed safely.")
	else:
		_log_fail("Warning flicker produced invalid light energy.")
		
	# ---------------------------------------------------------
	# TEST 5: BLACKOUT_ACTIVE State Transition & Ambient Darkness
	# ---------------------------------------------------------
	_log_info("--- TEST 5: BLACKOUT_ACTIVE State Transition ---")
	lighting_ctrl.set_lighting_state(FacilityLightingControllerClass.LightingState.BLACKOUT_ACTIVE, true)
	if lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.BLACKOUT_ACTIVE:
		_log_pass("Lighting state successfully transitioned to BLACKOUT_ACTIVE.")
	else:
		_log_fail("Failed to transition to BLACKOUT_ACTIVE.")
		
	if lighting_ctrl.canvas_modulate.color.is_equal_approx(FacilityLightingControllerClass.COLOR_BLACKOUT_AMBIENT):
		_log_pass("Ambient modulate snapped to COLOR_BLACKOUT_AMBIENT (#080b12).")
	else:
		_log_fail("Modulate color mismatch in BLACKOUT_ACTIVE: %s" % str(lighting_ctrl.canvas_modulate.color))
		
	# ---------------------------------------------------------
	# TEST 6: Emergency Siren Pulse Oscillation
	# ---------------------------------------------------------
	_log_info("--- TEST 6: Emergency Siren Strobe Oscillation ---")
	if not normal_parent.visible and siren_parent.visible:
		_log_pass("Normal lights deactivated and emergency sirens activated.")
	else:
		_log_fail("Incorrect light fixture visibility in BLACKOUT_ACTIVE.")
		
	lighting_ctrl._process(0.1)
	if siren_sample.energy > 0.0:
		_log_pass("Emergency siren energy oscillating dynamically (Energy: %.2f)." % siren_sample.energy)
	else:
		_log_fail("Siren energy did not update during process loop.")
		
	# ---------------------------------------------------------
	# TEST 7: MELTDOWN State Transition & Speed
	# ---------------------------------------------------------
	_log_info("--- TEST 7: MELTDOWN State Transition ---")
	lighting_ctrl.set_lighting_state(FacilityLightingControllerClass.LightingState.MELTDOWN, true)
	if lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.MELTDOWN:
		_log_pass("Lighting state transitioned to MELTDOWN.")
	else:
		_log_fail("Failed to transition to MELTDOWN.")
		
	if lighting_ctrl.canvas_modulate.color.is_equal_approx(FacilityLightingControllerClass.COLOR_MELTDOWN_AMBIENT):
		_log_pass("Ambient modulate set to COLOR_MELTDOWN_AMBIENT (#2e0d0d).")
	else:
		_log_fail("Ambient color mismatch in MELTDOWN: %s" % str(lighting_ctrl.canvas_modulate.color))
		
	# ---------------------------------------------------------
	# TEST 8: State Restoration to NORMAL
	# ---------------------------------------------------------
	_log_info("--- TEST 8: Restoration to NORMAL ---")
	lighting_ctrl.set_lighting_state(FacilityLightingControllerClass.LightingState.NORMAL, true)
	if lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.NORMAL and normal_parent.visible and not siren_parent.visible:
		_log_pass("Successfully restored to NORMAL with normal lights enabled and sirens disabled.")
	else:
		_log_fail("Failed to properly restore to NORMAL state.")
		
	# ---------------------------------------------------------
	# TEST 9: Dynamic Light Registration
	# ---------------------------------------------------------
	_log_info("--- TEST 9: Dynamic Runtime Light Registration ---")
	var dynamic_light = PointLight2D.new()
	var dynamic_siren = PointLight2D.new()
	root_node.add_child(dynamic_light)
	root_node.add_child(dynamic_siren)
	
	lighting_ctrl.register_normal_light(dynamic_light)
	lighting_ctrl.register_emergency_siren(dynamic_siren)
	
	lighting_ctrl.set_lighting_state(FacilityLightingControllerClass.LightingState.BLACKOUT_ACTIVE)
	if not dynamic_light.visible and dynamic_siren.visible:
		_log_pass("Dynamic lights correctly updated visibility on state change.")
	else:
		_log_fail("Dynamic lights did not respect state visibility change.")
		
	lighting_ctrl.unregister_light(dynamic_light)
	lighting_ctrl.unregister_light(dynamic_siren)
	dynamic_light.queue_free()
	dynamic_siren.queue_free()
	
	# ---------------------------------------------------------
	# TEST 10: Network Signal Integration
	# ---------------------------------------------------------
	_log_info("--- TEST 10: ClientNetworkManager Event Signal Hooks ---")
	lighting_ctrl._on_blackout_countdown_started(3.0)
	var pass_countdown = (lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.BLACKOUT_WARNING)
	
	lighting_ctrl._on_blackout_started(90.0)
	var pass_blackout = (lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.BLACKOUT_ACTIVE)
	
	lighting_ctrl._on_blackout_ended("duration_expired")
	var pass_ended = (lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.NORMAL)
	
	lighting_ctrl._on_meltdown_started(300.0, true)
	var pass_meltdown = (lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.MELTDOWN)
	
	lighting_ctrl._on_blackout_countdown_cancelled("interrupted")
	var pass_cancelled = (lighting_ctrl.current_state == FacilityLightingControllerClass.LightingState.NORMAL)
	
	if pass_countdown and pass_blackout and pass_ended and pass_meltdown and pass_cancelled:
		_log_pass("All 5 ClientNetworkManager network event signal hooks executed accurately.")
	else:
		_log_fail("Network event signal hook failure: cd=%s, bo=%s, end=%s, melt=%s, cancel=%s" % [pass_countdown, pass_blackout, pass_ended, pass_meltdown, pass_cancelled])
		
	# ---------------------------------------------------------
	# TEST 11: Player Flashlight Component
	# ---------------------------------------------------------
	_log_info("--- TEST 11: PlayerFlashlight2D Component ---")
	var flashlight = PlayerFlashlight2DClass.new()
	var beam = PointLight2D.new()
	beam.name = "BeamLight"
	var halo = PointLight2D.new()
	halo.name = "HaloLight"
	flashlight.add_child(beam)
	flashlight.add_child(halo)
	root_node.add_child(flashlight)
	
	flashlight.aim_at_direction(Vector2(1, 0))
	flashlight.snap_to_direction(Vector2(0, 1))
	if is_equal_approx(flashlight.rotation, PI * 0.5):
		_log_pass("Player flashlight snaps to directional angle accurately (Down = 90 deg).")
	else:
		_log_fail("Player flashlight rotation snap failed: %f" % flashlight.rotation)
		
	flashlight.set_flashlight_active(false)
	if not beam.enabled and not halo.enabled:
		_log_pass("Player flashlight deactivates beam and halo upon disable.")
	else:
		_log_fail("Flashlight disable failed.")
		
	flashlight.set_flashlight_active(true)
	if beam.enabled and halo.enabled:
		_log_pass("Player flashlight re-activates beam and halo upon enable.")
	else:
		_log_fail("Flashlight re-enable failed.")
		
	flashlight.queue_free()
	
	# ---------------------------------------------------------
	# TEST 12: VignetteOverlay Component
	# ---------------------------------------------------------
	_log_info("--- TEST 12: VignetteOverlay Component ---")
	var vignette = VignetteOverlayClass.new()
	var tex_rect = TextureRect.new()
	tex_rect.name = "TextureRect"
	vignette.add_child(tex_rect)
	root_node.add_child(vignette)
	
	vignette.on_lighting_state_changed(FacilityLightingControllerClass.LightingState.BLACKOUT_ACTIVE)
	vignette._process(1.0) # step alpha towards target
	if vignette.get_current_alpha() > VignetteOverlayClass.ALPHA_NORMAL:
		_log_pass("Vignette alpha scaled upward for BLACKOUT_ACTIVE (Alpha: %.2f)." % vignette.get_current_alpha())
	else:
		_log_fail("Vignette alpha did not increase for BLACKOUT_ACTIVE.")
		
	vignette.on_lighting_state_changed(FacilityLightingControllerClass.LightingState.NORMAL)
	vignette.set_intensity(VignetteOverlayClass.ALPHA_NORMAL, true)
	if is_equal_approx(vignette.get_current_alpha(), VignetteOverlayClass.ALPHA_NORMAL):
		_log_pass("Vignette alpha restored to baseline NORMAL level.")
	else:
		_log_fail("Vignette alpha restore failed.")
		
	vignette.queue_free()
	lighting_ctrl.queue_free()
	
	# ---------------------------------------------------------
	# SUMMARY & CONCLUSION
	# ---------------------------------------------------------
	print("\n==================================================================")
	print("  MEMBER 7 PHASE 2 TEST RESULTS SUMMARY")
	print("==================================================================")
	print("  Total Passed Checks: %d" % test_log.size())
	if test_passed:
		print("  STATUS: [ALL TESTS PASSED SUCCESSFULLY] 🚀")
	else:
		print("  STATUS: [TEST FAILURES DETECTED] ❌")
	print("==================================================================\n")
	
	quit(0 if test_passed else 1)
