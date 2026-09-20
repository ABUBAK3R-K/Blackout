shader_type canvas_item;

// Vision Vignette Shader
// Smooth radial darkening around screen edges for enhanced claustrophobic atmosphere during Blackout.
// Designed by Member 7 (Fatima - 2D Environment & Technical Artist).

uniform float vignette_radius : hint_range(0.0, 1.5) = 0.65;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.03, 0.04, 0.07, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.2;
uniform float pulse_intensity : hint_range(0.0, 0.2) = 0.04;
uniform bool is_active = true;

void fragment() {
	if (!is_active) {
		COLOR = vec4(0.0);
	} else {
		vec2 center = vec2(0.5, 0.5);
		float dist = distance(UV, center);
		
		// Subtle breathing pulse
		float pulse = sin(TIME * pulse_speed) * pulse_intensity;
		float current_radius = clamp(vignette_radius + pulse, 0.1, 1.5);
		
		// Smoothstep radial alpha transition
		float alpha = smoothstep(current_radius - vignette_softness, current_radius + vignette_softness, dist);
		
		COLOR = vec4(vignette_color.rgb, alpha * vignette_color.a);
	}
}
