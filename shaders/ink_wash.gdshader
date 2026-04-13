shader_type canvas_item;

// ── 屏幕纹理（Godot 4 后处理标准写法）────────────────────────────
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// ── 可调参数 ──────────────────────────────────────────────────
/// 宣纸泛黄强度（0=不泛黄，0.08=淡淡宣纸感，0.3=很黄）
uniform float paper_strength   : hint_range(0.0, 0.3)  = 0.08;

/// 暗角强度（越大四角越暗）
uniform float vignette_intensity : hint_range(0.0, 3.0) = 0.70;

/// 暗角形状（1.0=菱形, 1.5=圆角, 2.0=更圆）
uniform float vignette_shape   : hint_range(0.8, 2.5)  = 1.4;

/// 墨迹渗透模糊半径（占屏幕宽度比例，0.003≈轻微柔化）
uniform float blur_radius      : hint_range(0.0, 0.008) = 0.0025;


void fragment() {
	vec2 uv = SCREEN_UV;

	// ── 1. 轻微模糊：墨迹在宣纸上的渗透/晕染感 ──────────────────
	// 5-tap 十字采样（比9-tap省 GPU，轻量手机可用）
	vec4 col  = texture(SCREEN_TEXTURE, uv)                               * 0.500;
	col      += texture(SCREEN_TEXTURE, uv + vec2( blur_radius, 0.0))    * 0.125;
	col      += texture(SCREEN_TEXTURE, uv + vec2(-blur_radius, 0.0))    * 0.125;
	col      += texture(SCREEN_TEXTURE, uv + vec2(0.0,  blur_radius))    * 0.125;
	col      += texture(SCREEN_TEXTURE, uv + vec2(0.0, -blur_radius))    * 0.125;

	// ── 2. 暗角：四角稍暗，中央保持亮度 ────────────────────────
	// 用幂次距离让暗角集中在真正的角落，不影响中间区域
	vec2  c    = uv - 0.5;
	float dist = pow(abs(c.x), vignette_shape) + pow(abs(c.y), vignette_shape);
	float vig  = 1.0 - smoothstep(0.16, 0.52, dist * vignette_intensity);
	col.rgb   *= vig;

	// ── 3. 宣纸泛黄：叠加一层极淡的暖黄 ─────────────────────────
	// 宣纸色 #faf3df ≈ (0.98, 0.95, 0.87)
	vec3 paper = vec3(0.98, 0.95, 0.87);
	col.rgb    = mix(col.rgb, paper, paper_strength);

	COLOR = col;
}
