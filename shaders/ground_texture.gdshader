shader_type canvas_item;

// 地面纹理 shader：以 ColorRect.color 为基色，叠加水墨晕染质感
// 参数：grain=高频颗粒；blot=低频色斑；blot_scale=色斑密度；
//      wood_grain=木纹强度（0=纯石地）；wood_freq=木纹横线密度

uniform vec4  base_color : source_color = vec4(0.5, 0.4, 0.3, 1.0);
uniform float grain      : hint_range(0.0, 0.15) = 0.04;
uniform float blot       : hint_range(0.0, 0.25) = 0.08;
uniform float blot_scale : hint_range(1.0, 20.0) = 5.0;
uniform float wood_grain : hint_range(0.0, 0.25) = 0.0;
uniform float wood_freq  : hint_range(0.0, 120.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 col = base_color.rgb;
	vec2 uv = UV;

	// 低频色斑（像宣纸上散开的淡墨）
	float b = smooth_noise(uv * blot_scale);
	col -= (b - 0.5) * blot;

	// 高频颗粒
	float g = hash(uv * 500.0);
	col += (g - 0.5) * grain;

	// 木纹横线（带低频噪声扰动模拟真实木纹）
	// uv.x 驱动 → 条纹随 x 周期变化 → 横向延伸的木纹
	// 中心化（abs - 0.5）让条纹有亮有暗，不会系统性偏暗
	if (wood_grain > 0.001) {
		float wave = sin(uv.x * wood_freq + smooth_noise(uv * 2.0) * 3.0);
		col += (abs(wave) - 0.5) * wood_grain * 0.6;
	}

	COLOR = vec4(col, base_color.a);
}
