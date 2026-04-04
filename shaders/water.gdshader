// Animated ocean water shader for Godot 4
// Produces scrolling normal-mapped waves with a translucent blue surface.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4  water_color    : source_color = vec4(0.14, 0.44, 0.76, 0.72);
uniform float wave_speed     : hint_range(0.0, 4.0)  = 1.2;
uniform float wave_height    : hint_range(0.0, 1.5)  = 0.28;
uniform float wave_freq      : hint_range(0.5, 12.0) = 3.5;
uniform float foam_threshold : hint_range(0.0, 1.0)  = 0.72;

void vertex() {
	// Two sine-wave layers for organic motion
	float wx = VERTEX.x * wave_freq * 0.06 + TIME * wave_speed * 0.55;
	float wz = VERTEX.z * wave_freq * 0.05 + TIME * wave_speed * 0.42;
	VERTEX.y += sin(wx)           * wave_height * 0.55
			  + cos(wz + 1.3)    * wave_height * 0.35
			  + sin(wx * 1.7 - wz * 0.8) * wave_height * 0.20;
}

void fragment() {
	// Scrolling normal map approximation from two UV sets
	vec2 uv1 = UV + vec2(TIME * 0.038,  TIME * 0.022);
	vec2 uv2 = UV - vec2(TIME * 0.031,  TIME * 0.044);
	float nx = sin(uv1.x * 18.0) * 0.28 + sin(uv2.x * 11.0) * 0.18;
	float nz = cos(uv1.y * 16.0) * 0.28 + cos(uv2.y * 13.0) * 0.18;
	NORMAL_MAP = normalize(vec3(nx, 1.0, nz));

	// Foam highlights on wave crests
	float foam = smoothstep(foam_threshold, 1.0,
		sin(UV.x * wave_freq * 4.0 + TIME * wave_speed) * 0.5 + 0.5);
	vec3 col   = mix(water_color.rgb, vec3(0.95, 0.97, 1.0), foam * 0.35);

	ALBEDO    = col;
	ALPHA     = water_color.a;
	METALLIC  = 0.28;
	ROUGHNESS = 0.06;
	SPECULAR  = 0.95;
}
