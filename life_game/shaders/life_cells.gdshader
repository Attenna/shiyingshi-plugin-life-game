shader_type canvas_item;
render_mode unshaded;

// 生命游戏 · 第一层（调色板）
//
// 输入：input_texture —— 最内层 BaseViewport 的 X×X RGBA8 掩码
//       （白色不透明 = 活，透明 = 死）。拖到 shader_layers 的第一层。
// 输出：圆角细胞 + 可选淡背景。默认死细胞全透明，露出父场景背景。
//
// 本层通过公共 uniform 与组件联动（life_game.gd 自动写入）：
//   input_texture  上一层/掩码（ViewportTexture）
//   grid_size      X×X 的尺寸
//   generation     当前代数
//   display_size   本层 Viewport 的像素尺寸（可用于自定义分辨率相关效果）

uniform sampler2D input_texture : repeat_disable, filter_nearest;

uniform vec4 alive_color : source_color = vec4(0.32, 0.95, 0.82, 1.0);
uniform vec4 dead_color : source_color = vec4(0.02, 0.05, 0.07, 0.0);
uniform float cell_inset : hint_range(0.0, 0.45) = 0.14;
uniform float cell_roundness : hint_range(0.0, 0.5) = 0.12;
uniform float edge_softness : hint_range(0.0, 4.0) = 1.0;
uniform vec2 grid_size = vec2(64.0, 64.0);
uniform vec2 display_size = vec2(320.0, 320.0);
uniform float generation = 0.0;

void fragment() {
	// 当前像素所在格的格内坐标（0..1）与格中心（UV）。
	vec2 cell = fract(UV * grid_size);
	vec2 cell_center_uv = (floor(UV * grid_size) + 0.5) / grid_size;
	float alive = step(0.5, texture(input_texture, cell_center_uv).a);

	// 圆角方块的近似 SDF（单位为「格」）。fwidth 做屏幕空间抗锯齿。
	vec2 half_extent = vec2(0.5 - cell_inset);
	vec2 q = abs(cell - 0.5) - half_extent + vec2(cell_roundness);
	float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - cell_roundness;
	float aa = max(fwidth(dist) * edge_softness, 0.0001);
	float shape = 1.0 - smoothstep(-aa, aa, dist);

	// 活细胞画圆角块；死细胞保留 dead_color（默认透明）。
	// 间隙同样使用 dead_color，所以 inset > 0 时能看到网格。
	vec4 col = mix(dead_color, alive_color, alive * shape);
	// 随代数极轻微的呼吸，避免画面完全静止；不需要时把 0.03 改成 0.0。
	col.rgb *= 1.0 + 0.03 * sin(generation * 0.08);
	COLOR = col;
}
