shader_type canvas_item;

// Meltdown Heat Distortion Shader
// Distorts screen pixels using sinusoidal heat wave displacement and thermal chromatic aberration.
// Designed by Member 7 (Fatima - 2D Environment & Technical Artist) for the ORION Core chamber and climax.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float distortion_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float wave_speed : hint_range(0.0, 10.0) = 3.0;
uniform float wave_frequency : hint_range(1.0, 50.0) = 25.0;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.008;
uniform vec4 heat_tint : source_color = vec4(1.0, 0.25, 0.05, 0.12);
uniform bool is_active = true;

void fragment() {
	if (!is_active || distortion_intensity <= 0.0) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		// Calculate dual sinusoidal heat wave UV offsets
		float time = TIME * wave_speed;
		vec2 uv = SCREEN_UV;
		
		float wave_x = sin(uv.y * wave_frequency + time) * 0.01 * distortion_intensity;
		float wave_y = cos(uv.x * wave_frequency * 0.8 + time * 1.2) * 0.008 * distortion_intensity;
		vec2 distorted_uv = uv + vec2(wave_x, wave_y);
		
		// Chromatic Aberration (R/G/B channel separation)
		float ca_offset = chromatic_aberration * distortion_intensity;
		float r = texture(screen_texture, distorted_uv + vec2(ca_offset, 0.0)).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, distorted_uv - vec2(ca_offset, 0.0)).b;
		
		vec4 base_color = vec4(r, g, b, 1.0);
		
		// Blend thermal heat tint
		vec4 final_color = mix(base_color, vec4(heat_tint.rgb, 1.0), heat_tint.a * distortion_intensity);
		COLOR = final_color;
	}
}
