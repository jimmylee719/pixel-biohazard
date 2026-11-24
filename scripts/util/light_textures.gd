## 用程式產生燈光貼圖，原型階段不需要美術素材。
## 亮度分成幾階，讓光看起來是像素風的色階，而不是平滑漸層。
class_name LightTextures
extends RefCounted

const SIZE := 256
const STEPS := 5.0

static var _radial_cache: Texture2D


## 圓形光：主角身邊的微光。半徑 = SIZE / 2。
static func make_radial() -> Texture2D:
	if _radial_cache:
		return _radial_cache
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE, SIZE) * 0.5
	var radius := SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(center) / radius
			var a := _quantize(clampf(1.0 - d, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_radial_cache = ImageTexture.create_from_image(img)
	return _radial_cache


## 扇形光：手電筒。頂點在貼圖中心，朝 +X 方向，長度 = SIZE / 2。
static func make_cone(half_angle_deg: float) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE, SIZE) * 0.5
	var radius := SIZE * 0.5
	var half := deg_to_rad(half_angle_deg)
	var soft_edge := deg_to_rad(5.0)
	for y in SIZE:
		for x in SIZE:
			var offset := Vector2(x, y) + Vector2(0.5, 0.5) - center
			var dist := offset.length() / radius
			if dist > 1.0:
				continue
			var angle := absf(offset.angle())
			if angle > half:
				continue
			var edge := clampf((half - angle) / soft_edge, 0.0, 1.0)
			var falloff := pow(1.0 - dist, 0.7)
			img.set_pixel(x, y, Color(1, 1, 1, _quantize(edge * falloff)))
	return ImageTexture.create_from_image(img)


static func _quantize(value: float) -> float:
	return ceilf(value * STEPS) / STEPS if value > 0.0 else 0.0
