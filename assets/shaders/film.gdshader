// 畫面後製：底片顆粒、暗角、一點點 80 年代霓虹的色調（暗部偏紫藍、亮部偏洋紅）、
// 很淡的 CRT 掃描線和邊緣的色差（賽博龐克感）。只蓋在遊戲畫面上（HUD 不受影響）。Compatibility 渲染器可用。
// era：0 = 現在（2026）、1 = 過去（1962，泛黃的老底片、會閃）、2 = 未來（2099 的訊號幻象，青／洋紅的霓虹）
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float grain = 0.055;
uniform float vignette = 0.55;
uniform float saturation = 0.82;
uniform float contrast = 1.1;
uniform float neon = 0.35;
uniform float scanlines = 0.035;
uniform float aberration = 1.0;
uniform float era = 0.0;

vec3 sample_screen(vec2 uv) {
	return textureLod(screen_texture, uv, 0.0).rgb;
}

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	// 色差：越靠邊緣，紅和藍錯開越多（最多約 1 像素）
	vec2 shift = d * SCREEN_PIXEL_SIZE * 4.0 * aberration;
	vec3 c;
	c.r = sample_screen(SCREEN_UV + shift).r;
	c.g = sample_screen(SCREEN_UV).g;
	c.b = sample_screen(SCREEN_UV - shift).b;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;

	// 霓虹色調：暗部偏紫藍、亮部帶一點洋紅
	vec3 shadow_tint = vec3(0.55, 0.45, 1.0);
	vec3 high_tint = vec3(1.0, 0.82, 0.95);
	c = mix(c, c * mix(shadow_tint, high_tint, smoothstep(0.15, 0.8, l)) * 1.08, neon);

	vec2 px = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	float frame = floor(TIME * 18.0);
	float n = fract(sin(dot(px + frame * vec2(13.1, 7.7), vec2(12.9898, 78.233))) * 43758.5453);
	float g = grain;

	if (era > 0.5 && era < 1.5) {
		// 1962：泛黃、低對比、顆粒粗、整個畫面偶爾閃一下
		float sl = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(sl) * vec3(1.08, 0.94, 0.72), 0.85);
		c = (c - 0.5) * 0.9 + 0.52;
		float flick = fract(sin(frame * 91.7) * 4375.85);
		c *= 0.93 + 0.07 * flick;
		g = grain * 2.2;
		// 底片刮痕
		float scratch = step(0.9985, fract(sin(floor(px.x * 0.5) * 17.3 + frame * 0.37) * 9152.3));
		c += scratch * 0.12;
	} else if (era > 1.5) {
		// 2099：青／洋紅的霓虹幻象，掃描線變明顯
		float sl = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, mix(vec3(0.05, 0.9, 1.0), vec3(1.0, 0.2, 0.85), sl) * (0.3 + sl), 0.55);
	}

	c += (n - 0.5) * g;
	float lines = era > 1.5 ? scanlines * 3.0 : scanlines;
	c *= 1.0 - lines * mod(px.y, 2.0);
	c *= 1.0 - vignette * dot(d, d) * 2.0;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
