shader_type canvas_item;

uniform vec2 center_uv = vec2(0.5, 0.5);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float vision_radius_px = 144.0;
uniform float darkness_alpha = 0.94;

void fragment() {
	vec2 pixel_pos = UV * viewport_size;
	vec2 center_pos = center_uv * viewport_size;
	float dist_px = distance(pixel_pos, center_pos);
	float fade = smoothstep(vision_radius_px, vision_radius_px * 1.8, dist_px);
	float alpha = clamp(fade * darkness_alpha, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
