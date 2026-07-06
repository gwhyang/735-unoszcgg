shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width : hint_range(0.0, 8.0, 1.0) = 3.0;
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.01;

//Blinking modulates the base color.
//Set blink_time_scale to 0 if you don't want blinking.
uniform vec4 blink_color : source_color = vec4(1.0);
uniform float blink_time_scale : hint_range(0.0, 10.0, 0.1) = 0.0;

const int MAX_OUTLINE_WIDTH = 8;

vec4 sample_group(vec2 uv) {
	vec4 color = textureLod(screen_texture, uv, 0.0);
	if (color.a > 0.0001) {
		color.rgb /= color.a;
	}
	return color;
}

void fragment() {
	vec4 group_color = sample_group(SCREEN_UV);
	vec4 base_color = COLOR * group_color;
	base_color = mix(base_color, base_color * blink_color, 0.5 - 0.5 * cos(TIME * blink_time_scale));

	float center_alpha = group_color.a;
	float sample_alpha = 0.0;
	float radius = min(outline_width, float(MAX_OUTLINE_WIDTH));
	float radius_squared = radius * radius;

	for (int x = -MAX_OUTLINE_WIDTH; x <= MAX_OUTLINE_WIDTH; x++) {
		for (int y = -MAX_OUTLINE_WIDTH; y <= MAX_OUTLINE_WIDTH; y++) {
			vec2 offset = vec2(float(x), float(y));
			float offset_squared = dot(offset, offset);
			if (offset_squared > 0.0 && offset_squared <= radius_squared) {
				sample_alpha = max(sample_alpha, sample_group(SCREEN_UV + SCREEN_PIXEL_SIZE * offset).a);
			}
		}
	}

	if (center_alpha <= alpha_threshold && sample_alpha > alpha_threshold) {
		COLOR = vec4(outline_color.rgb, outline_color.a * sample_alpha * COLOR.a);
	} else {
		COLOR = base_color;
	}
}
