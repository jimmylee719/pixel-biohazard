// 畫面後製：惡靈古堡早期的質感（稍微去飽和、對比、底片顆粒、四周暗角）。
// 只蓋在遊戲畫面上（HUD 不受影響）。Compatibility 渲染器可用。
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float grain = 0.055;
uniform float vignette = 0.55;
uniform float saturation = 0.8;
uniform float contrast = 1.1;

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	vec2 px = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	float frame = floor(TIME * 18.0);
	float n = fract(sin(dot(px + frame * vec2(13.1, 7.7), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 2.0;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
