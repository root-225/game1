shader_type spatial;
// Inverted-hull toon outline (next_pass). Width is in object units: callers divide by scale.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform float width = 0.03;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
