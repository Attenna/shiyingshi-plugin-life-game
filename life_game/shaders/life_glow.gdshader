shader_type canvas_item;
render_mode unshaded;

// 生命游戏 · 第二层（泛光 / Bloom）
//
// 输入：input_texture —— 上一层（life_cells）输出的 RGBA。
// 输出：原图 + 8 方向低强度泛光。泛光半径以「格」为单位（bloom_cells），
//       组件放大缩小光晕比例不变。
//
// 这一层演示「若干层 shader」：复制一个 ShaderMaterial、改 shader、追加到
// shader_layers 数组即可；生命游戏脚本会自动设置 input_texture 和公共 uniform。

uniform sampler2D input_texture : repeat_disable, filter_linear;

uniform float bloom_strength : hint_range(0.0, 2.0) = 0.40;
uniform float bloom_cells : hint_range(0.0, 2.0) = 0.35;
uniform vec4 bloom_tint : source_color = vec4(0.40, 0.90, 1.0, 1.0);
uniform vec2 grid_size = vec2(64.0, 64.0);
uniform vec2 display_size = vec2(320.0, 320.0);
uniform float generation = 0.0;

void fragment() {
	vec4 base = texture(input_texture, UV);
	vec2 step_uv = bloom_cells / grid_size;
	vec2 diag = step_uv * 0.70710678;

	vec4 s0 = texture(input_texture, clamp(UV + vec2(step_uv.x, 0.0), vec2(0.0), vec2(1.0)));
	vec4 s1 = texture(input_texture, clamp(UV - vec2(step_uv.x, 0.0), vec2(0.0), vec2(1.0)));
	vec4 s2 = texture(input_texture, clamp(UV + vec2(0.0, step_uv.y), vec2(0.0), vec2(1.0)));
	vec4 s3 = texture(input_texture, clamp(UV - vec2(0.0, step_uv.y), vec2(0.0), vec2(1.0)));
	vec4 s4 = texture(input_texture, clamp(UV + diag, vec2(0.0), vec2(1.0)));
	vec4 s5 = texture(input_texture, clamp(UV - diag, vec2(0.0), vec2(1.0)));
	vec4 s6 = texture(input_texture, clamp(UV + vec2(diag.x, -diag.y), vec2(0.0), vec2(1.0)));
	vec4 s7 = texture(input_texture, clamp(UV + vec2(-diag.x, diag.y), vec2(0.0), vec2(1.0)));

	vec3 sum_rgb = s0.rgb * s0.a + s1.rgb * s1.a + s2.rgb * s2.a + s3.rgb * s3.a
			+ s4.rgb * s4.a + s5.rgb * s5.a + s6.rgb * s6.a + s7.rgb * s7.a;
	float sum_alpha = s0.a + s1.a + s2.a + s3.a + s4.a + s5.a + s6.a + s7.a;
	vec3 bloom = sum_rgb / 8.0;
	float bloom_alpha = sum_alpha / 8.0;

	float pulse = 0.92 + 0.08 * sin(generation * 0.08);
	float strength = bloom_strength * pulse;

	COLOR = vec4(
		base.rgb + bloom * strength * bloom_tint.rgb,
		clamp(base.a + bloom_alpha * strength * bloom_tint.a, 0.0, 1.0)
	);
}
