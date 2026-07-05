shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float inside_process:hint_range(0.0,1.5) = 0.0;
uniform float outside_process:hint_range(0.0,1.5) = 0.0;
uniform

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float dist = length((SCREEN_UV - vec2(0.5)));
	color = vec3(1.) - color;

	if ((dist > inside_process) && (dist<= outside_process) ){
		COLOR.rgb = color;
	}else{COLOR.a = 0.;}

}
