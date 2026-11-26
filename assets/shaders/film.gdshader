// 畫面後製：惡靈古堡早期的質感（稍微去飽和、對比、底片顆粒、四周暗角）。
// 只蓋在遊戲畫面上（HUD 不受影響）。Compatibility 渲染器可用。
// era：0 = 現在（2026）、1 = 過去（1962，泛黃的老底片、會閃）、2 = 未來（2099 的幻象，冷白、褪色）
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float grain = 0.055;
uniform float vignette = 0.55;
uniform float saturation = 0.8;
uniform float contrast = 1.1;
uniform float era = 0.0;
// 2.5D 的鏡頭傾斜（0 = 正俯視；0.2 左右 = 像鏡頭往前傾的斜角視角：上面比較遠、比較小）
uniform float tilt = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float k = mix(1.0 - tilt, 1.0, uv.y);
	vec2 suv = vec2((uv.x - 0.5) / k + 0.5, mix(uv.y, uv.y * uv.y * 0.35 + uv.y * 0.65, tilt * 2.0));
	vec3 c = textureLod(screen_texture, clamp(suv, vec2(0.0), vec2(1.0)), 0.0).rgb;
	if (suv.x < 0.0 || suv.x > 1.0) {
		c = vec3(0.01, 0.012, 0.02);
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// 傾斜時，遠處（上方）比較暗、比較霧
	c *= 1.0 - tilt * (1.0 - uv.y) * 1.2;
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	// 冷調的軍事感（偏青灰）：只在現在的時代
	if (era < 0.5) {
		c = mix(c, c * vec3(0.9, 1.0, 1.04), 0.6);
	}
	// 顆粒的大小固定是「畫面高度的 1/270」（原本的像素大小），視窗放大時顆粒不會變細
	float grain_px = max(1.0, floor(1.0 / (SCREEN_PIXEL_SIZE.y * 270.0)));
	vec2 px = floor(SCREEN_UV / SCREEN_PIXEL_SIZE / grain_px);
	float frame = floor(TIME * 18.0);
	float n = fract(sin(dot(px + frame * vec2(13.1, 7.7), vec2(12.9898, 78.233))) * 43758.5453);
	float g = grain;
	if (era > 0.5 && era < 1.5) {
		// 1962：泛黃、低對比、顆粒粗、整個畫面偶爾閃一下、底片刮痕
		c = mix(c, vec3(l) * vec3(1.08, 0.94, 0.72), 0.85);
		c = (c - 0.5) * 0.9 + 0.52;
		c *= 0.93 + 0.07 * fract(sin(frame * 91.7) * 4375.85);
		g = grain * 2.2;
		c += step(0.9985, fract(sin(floor(px.x * 0.5) * 17.3 + frame * 0.37) * 9152.3)) * 0.12;
	} else if (era > 1.5) {
		// 2099：冷白、褪色，像過度曝光的監視畫面
		c = mix(c, vec3(l) * vec3(0.85, 0.97, 1.05) + 0.08, 0.7);
	}
	c += (n - 0.5) * g;
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 2.0;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
