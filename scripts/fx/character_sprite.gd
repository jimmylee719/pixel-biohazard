## 角色的像素圖動畫（assets/sprites/<角色>/<動畫>_<方向>_<格>.png，由 tools/import_art.gd 產生）。
## 方向只有 down、downright、right、upright、up 五個，往左的三個方向用水平翻轉。
## 找不到圖的時候 has_art() 是 false，角色就繼續用原本的色塊。
class_name CharacterSprite
extends AnimatedSprite2D

const DIRS := ["right", "downright", "down", "downright", "right", "upright", "up", "upright"]
## 8 個方向中，哪些要水平翻轉（朝左）
const FLIP := [false, false, false, true, true, true, false, false]
## 腳底離角色中心多遠（像素）
const FEET := 6.0

var char_id := ""
var _anims: Array[String] = []
var _dir := 2
var _flipped := false


func setup(id: String) -> bool:
	char_id = id
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var base := "res://assets/sprites/%s/" % id
	for anim in ["idle", "walk", "sneak", "listen"]:
		for dir in ["down", "downright", "right", "upright", "up"]:
			var i := 0
			while ResourceLoader.exists("%s%s_%s_%d.png" % [base, anim, dir, i]):
				var name := "%s_%s" % [anim, dir]
				if not frames.has_animation(name):
					frames.add_animation(name)
					frames.set_animation_speed(name, 4.0)
					if not _anims.has(anim):
						_anims.append(anim)
				frames.add_frame(name, load("%s%s_%s_%d.png" % [base, anim, dir, i]))
				i += 1
	if _anims.is_empty():
		return false
	sprite_frames = frames
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true


func has_art() -> bool:
	return not _anims.is_empty()


func has_anim(anim: String) -> bool:
	return _anims.has(anim)


## 依面向和動作選擇動畫。speed_scale：走路 1、跑步 1.8。
func show_pose(anim: String, facing: Vector2, playing: bool, speed := 1.0) -> void:
	if not has_art():
		return
	if not has_anim(anim):
		anim = "walk" if has_anim("walk") else _anims[0]
	if facing.length() > 0.1:
		_dir = wrapi(roundi(facing.angle() / (PI / 4.0)), 0, 8)
	var name := "%s_%s" % [anim, DIRS[_dir]]
	flip_h = FLIP[_dir]
	if animation != name:
		var keep := frame
		play(name)
		frame = keep % maxi(sprite_frames.get_frame_count(name), 1)
	speed_scale = speed
	if playing:
		if not is_playing():
			play()
	else:
		pause()
	# 腳底對齊角色中心下方
	var tex := sprite_frames.get_frame_texture(name, frame)
	if tex:
		position.y = FEET - tex.get_height() * 0.5
