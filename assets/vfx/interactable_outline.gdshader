shader_type canvas_item;

// Interactable Outline Shader
// Renders a crisp 1px golden outline around interactive props when players enter interaction proximity.
// Designed by Member 7 (Fatima - 2D Environment & Technical Artist).

uniform vec4 outline_color : source_color = vec4(1.0, 0.84, 0.0, 1.0); // Gold #ffd600
uniform float outline_width : hint_range(0.0, 5.0) = 1.0;
uniform bool is_active = true;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	
	if (!is_active || outline_width <= 0.0) {
		COLOR = base_color;
	} else {
		// Sample 4 cardinal neighbors
		vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
		float a_up = texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
		float a_down = texture(TEXTURE, UV + vec2(0.0, ps.y)).a;
		float a_left = texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a;
		float a_right = texture(TEXTURE, UV + vec2(ps.x, 0.0)).a;
		
		float outline_alpha = max(max(a_up, a_down), max(a_left, a_right));
		
		if (base_color.a < 0.1 && outline_alpha > 0.1) {
			COLOR = outline_color;
		} else {
			COLOR = base_color;
		}
	}
}
