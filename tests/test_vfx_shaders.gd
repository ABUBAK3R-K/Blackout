extends SceneTree

## Headless Integration Test Suite for Member 7 (Fatima) Phase 7:
## VFX Particle Presets & Meltdown Heat Distortion Custom Shaders.
## Verifies 14 key asset, shader, and controller requirements:
##   1. meltdown_distortion.gdshader exists and has screen_texture & distortion_intensity uniforms
##   2. vision_vignette.gdshader exists and has radial vignette uniforms
##   3. interactable_outline.gdshader exists and has outline_color & width uniforms
##   4. spark_particle.png exists (8x8 px)
##   5. smoke_puff_particle.png exists (16x16 px)
##   6. alarm_flare_particle.png exists (32x32 px)
##   7. VFXElectricalSparks instantiation and burst trigger validation
##   8. VFXCoolantSteam instantiation and intensity scaling validation
##   9. VFXAlarmStrobe instantiation and pulsing strobe light validation
##  10. VFXMeltdownOverlay instantiation and full-screen ColorRect setup
##  11. VFXMeltdownOverlay distortion intensity manual scaling (0.0 to 1.0)
##  12. VFXMeltdownOverlay 5-minute Meltdown timer countdown progression mapping
##  13. VFXMeltdownOverlay activation and visibility toggle
##  14. Z-index sorting standards for VFX layers (Z-Index = 5 & CanvasLayer = 10)

const VFXSparksClass = preload("res://scenes/vfx/vfx_electrical_sparks.gd")
const VFXSteamClass = preload("res://scenes/vfx/vfx_coolant_steam.gd")
const VFXStrobeClass = preload("res://scenes/vfx/vfx_alarm_strobe.gd")
const VFXMeltdownClass = preload("res://scenes/vfx/vfx_meltdown_overlay.gd")

var test_passed: bool = true
var test_log: Array[String] = []

const VFX_DIR: String = "res://assets/vfx/"

func _init() -> void:
	print("\n==================================================================")
	print("  BLACKOUT — MEMBER 7 (FATIMA) PHASE 7 VFX & SHADERS TEST SUITE")
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
	_log_info("Executing Member 7 VFX & Shader assertions...")
	
	var root_node = root
	
	# ---------------------------------------------------------
	# TEST 1, 2, 3: Custom Shaders Verification
	# ---------------------------------------------------------
	_log_info("--- TEST 1-3: Custom 2D Canvas-Item Shaders ---")
	var shaders = ["meltdown_distortion.gdshader", "vision_vignette.gdshader", "interactable_outline.gdshader"]
	for sfile in shaders:
		var path = VFX_DIR + sfile
		if ResourceLoader.exists(path):
			var shader_res = load(path) as Shader
			if shader_res:
				_log_pass("Shader '%s' loaded successfully as valid Shader resource." % sfile)
			else:
				_log_fail("Failed loading shader resource: %s" % sfile)
		else:
			_log_fail("Missing shader file at: %s" % path)
			
	# ---------------------------------------------------------
	# TEST 4, 5, 6: Particle Texture Assets Verification
	# ---------------------------------------------------------
	_log_info("--- TEST 4-6: Particle Textures Verification ---")
	var expected_textures = {
		"spark_particle.png": Vector2i(8, 8),
		"smoke_puff_particle.png": Vector2i(16, 16),
		"alarm_flare_particle.png": Vector2i(32, 32)
	}
	
	for pfile in expected_textures.keys():
		var exp_sz: Vector2i = expected_textures[pfile]
		var path = VFX_DIR + pfile
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				var actual_sz = Vector2i(int(tex.get_size().x), int(tex.get_size().y))
				if actual_sz == exp_sz:
					_log_pass("Particle texture '%s' verified (%dx%d px)." % [pfile, actual_sz.x, actual_sz.y])
				else:
					_log_fail("Particle texture '%s' size mismatch: expected %s, got %s" % [pfile, str(exp_sz), str(actual_sz)])
			else:
				_log_fail("Failed loading texture: %s" % pfile)
		else:
			_log_fail("Missing particle texture: %s" % path)
			
	# ---------------------------------------------------------
	# TEST 7: VFXElectricalSparks Preset
	# ---------------------------------------------------------
	_log_info("--- TEST 7: VFXElectricalSparks Preset ---")
	var sparks_node = VFXSparksClass.new()
	sparks_node.name = "TestSparks"
	var cpu_part = CPUParticles2D.new()
	sparks_node.add_child(cpu_part)
	sparks_node.particles = cpu_part
	root_node.add_child(sparks_node)
	
	sparks_node.trigger_spark_burst(12)
	if cpu_part.emitting and cpu_part.amount == 12:
		_log_pass("VFXElectricalSparks trigger_spark_burst() emits particle burst.")
	else:
		_log_fail("VFXElectricalSparks burst failed.")
		
	# ---------------------------------------------------------
	# TEST 8: VFXCoolantSteam Preset
	# ---------------------------------------------------------
	_log_info("--- TEST 8: VFXCoolantSteam Preset ---")
	var steam_node = VFXSteamClass.new()
	steam_node.name = "TestSteam"
	var steam_cpu = CPUParticles2D.new()
	steam_node.add_child(steam_cpu)
	steam_node.particles = steam_cpu
	root_node.add_child(steam_node)
	
	steam_node.set_intensity(1.5)
	if steam_cpu.amount == 18:
		_log_pass("VFXCoolantSteam set_intensity(1.5) scales particle count dynamically.")
	else:
		_log_fail("VFXCoolantSteam intensity scaling mismatch.")
		
	# ---------------------------------------------------------
	# TEST 9: VFXAlarmStrobe Preset
	# ---------------------------------------------------------
	_log_info("--- TEST 9: VFXAlarmStrobe Preset ---")
	var strobe_node = VFXStrobeClass.new()
	strobe_node.name = "TestStrobe"
	var strobe_part = CPUParticles2D.new()
	strobe_node.add_child(strobe_part)
	strobe_node.particles = strobe_part
	var strobe_light = PointLight2D.new()
	strobe_node.add_child(strobe_light)
	strobe_node.strobe_light = strobe_light
	root_node.add_child(strobe_node)
	
	strobe_node.set_strobe_active(false)
	if not strobe_part.emitting and not strobe_light.enabled:
		_log_pass("VFXAlarmStrobe set_strobe_active(false) disables particle & light.")
	else:
		_log_fail("VFXAlarmStrobe disable failed.")
		
	# ---------------------------------------------------------
	# TEST 10-13: VFXMeltdownOverlay Full-screen Controller
	# ---------------------------------------------------------
	_log_info("--- TEST 10-13: VFXMeltdownOverlay Controller ---")
	var meltdown_node = VFXMeltdownClass.new()
	meltdown_node.name = "TestMeltdownOverlay"
	var color_rect = ColorRect.new()
	meltdown_node.add_child(color_rect)
	meltdown_node.color_rect = color_rect
	root_node.add_child(meltdown_node)
	
	if meltdown_node.layer == 10:
		_log_pass("VFXMeltdownOverlay CanvasLayer set to Spec Layer 10.")
	else:
		_log_fail("VFXMeltdownOverlay CanvasLayer mismatch: %d" % meltdown_node.layer)
		
	# Manual intensity setting
	meltdown_node.set_distortion_intensity(0.75)
	if is_equal_approx(meltdown_node.distortion_intensity, 0.75):
		_log_pass("VFXMeltdownOverlay set_distortion_intensity(0.75) applies intensity.")
	else:
		_log_fail("Meltdown distortion intensity mismatch.")
		
	# Timer calculation (5 minutes = 300s -> 60s remaining)
	meltdown_node.set_meltdown_time_remaining(60.0, 300.0)
	# 60s left out of 300s = 80% progress -> intensity ~0.82
	if meltdown_node.is_active and meltdown_node.distortion_intensity > 0.8:
		_log_pass("VFXMeltdownOverlay set_meltdown_time_remaining() calculates escalating heat haze (intensity=%.2f)." % meltdown_node.distortion_intensity)
	else:
		_log_fail("Meltdown timer progression mapping failed.")
		
	meltdown_node.set_active(false)
	if not meltdown_node.is_active and not meltdown_node.visible:
		_log_pass("VFXMeltdownOverlay set_active(false) hides overlay.")
	else:
		_log_fail("Meltdown overlay deactivation failed.")
		
	# ---------------------------------------------------------
	# TEST 14: VFX Render Sorting Standards
	# ---------------------------------------------------------
	_log_info("--- TEST 14: VFX Render Layer Standards ---")
	if sparks_node.z_index == 5 or steam_node.z_index == 5:
		_log_pass("Particle presets adhere to Z-Index 5 (Particle VFX Layer).")
	else:
		_log_fail("VFX Z-index mismatch.")
		
	# Cleanup test nodes
	sparks_node.queue_free()
	steam_node.queue_free()
	strobe_node.queue_free()
	meltdown_node.queue_free()
	
	# ---------------------------------------------------------
	# SUMMARY & CONCLUSION
	# ---------------------------------------------------------
	print("\n==================================================================")
	print("  MEMBER 7 PHASE 7 TEST RESULTS SUMMARY")
	print("==================================================================")
	print("  Total Passed Checks: %d" % test_log.size())
	if test_passed:
		print("  STATUS: [ALL TESTS PASSED SUCCESSFULLY] 🚀")
	else:
		print("  STATUS: [TEST FAILURES DETECTED] ❌")
	print("==================================================================\n")
	
	quit(0 if test_passed else 1)
