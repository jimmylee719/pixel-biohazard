## 角色的像素圖動畫（assets/sprites/<角色>/<動畫>_<方向>_<格>.png，由 tools/gen_pixel_art.py 產生）。
## 方向只有 down、downright、right、upright、up 五個，往左的三個方向用水平翻轉。
## 找不到圖的時候 has_art() 是 false，角色就繼續用原本的色塊。
## 腳下有一個半透明的影子（貼地，讓角色看起來站在地上、有高度）。
class_name CharacterSprite
extends AnimatedSprite2D

const DIRS := ["right", "downright", "down", "downright", "right", "upright", "up", "upright"]
## 8 個方向中，哪些要水平翻轉（朝左）
const FLIP := [false, false, false, true, true, true, false, false]
## 腳底離角色中心多遠（像素）
const FEET := 6.0
## 每種動作的播放速度（格／秒）、會不會循環。沒列出來的用 6、循環。
## 格數多（走路 8 格、近戰 6 格、撲擊 5 格），播放速度跟著提高 → 動作流暢
const ANIMS := {
	"idle": [3.0, true], "walk": [12.0, true], "sneak": [10.0, true], "listen": [3.0, true],
	"aim": [1.0, true], "aim_pistol": [1.0, true], "aim_shotgun": [1.0, true], "aim_rifle": [1.0, true],
	"aim_nailgun": [1.0, true], "aim_flare_gun": [1.0, true],
	"shoot_pistol": [20.0, false], "shoot_shotgun": [16.0, false], "shoot_rifle": [14.0, false],
	"shoot_nailgun": [24.0, false], "shoot_flare_gun": [18.0, false],
	"slash": [22.0, false], "slash_axe": [18.0, false], "punch": [24.0, false], "kick": [20.0, false],
	"attack": [12.0, false], "hurt": [14.0, false], "dodge": [21.0, false], "dodge_back": [21.0, false],
}

var char_id := ""
var _anims: Array[String] = []
var _dir := 2
var _kind := ""
var _shadow: Sprite2D


## 讀過的圖組（同一套圖只讀一次；換裝時很多圖組會重複用到）
static var _frames_cache := {}
## 疊在上面的圖層（紙娃娃：頭部、腳部裝備）
var _layers: Array[AnimatedSprite2D] = []


static func load_frames(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var base := "res://assets/sprites/%s/" % id
	for anim in ANIMS:
		for dir in ["down", "downright", "right", "upright", "up"]:
			var i := 0
			while ResourceLoader.exists("%s%s_%s_%d.png" % [base, anim, dir, i]):
				var name := "%s_%s" % [anim, dir]
				if not frames.has_animation(name):
					frames.add_animation(name)
					frames.set_animation_speed(name, ANIMS[anim][0])
					frames.set_animation_loop(name, ANIMS[anim][1])
				frames.add_frame(name, load("%s%s_%s_%d.png" % [base, anim, dir, i]))
				i += 1
	var result: SpriteFrames = frames if frames.get_animation_names().size() > 0 else null
	_frames_cache[id] = result
	return result


func setup(id: String) -> bool:
	char_id = id
	var frames := load_frames(id)
	if frames == null:
		return false
	_use_frames(frames)
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shadow_tex := Art.tex("fx/shadow")
	if shadow_tex:
		_shadow = Sprite2D.new()
		_shadow.texture = shadow_tex
		_shadow.show_behind_parent = true
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_shadow)
	frame_changed.connect(_sync_layers)
	animation_changed.connect(_sync_layers)
	return true


func _use_frames(frames: SpriteFrames) -> void:
	_anims.clear()
	for name in frames.get_animation_names():
		var kind := String(name).substr(0, String(name).rfind("_"))
		if not _anims.has(kind):
			_anims.append(kind)
	var anim_name := animation
	var keep := frame
	sprite_frames = frames
	if frames.has_animation(anim_name):
		animation = anim_name
		frame = keep % maxi(frames.get_frame_count(anim_name), 1)


## 換裝：本體圖組＋疊上去的圖層（Gear.sprite_sets()）
func set_outfit(sets: Array[String]) -> void:
	if sets.is_empty():
		return
	var base := load_frames(sets[0])
	if base:
		_use_frames(base)
	for l in _layers:
		l.queue_free()
	_layers.clear()
	for i in range(1, sets.size()):
		var lf := load_frames(sets[i])
		if lf == null:
			continue
		var a := AnimatedSprite2D.new()
		a.sprite_frames = lf
		a.centered = true
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(a)
		_layers.append(a)
	_sync_layers()


func layer_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for l in _layers:
		if l.sprite_frames.has_animation(animation):
			out.append(l.sprite_frames.get_frame_texture(animation, mini(frame, l.sprite_frames.get_frame_count(animation) - 1)))
	return out


func _sync_layers() -> void:
	for l in _layers:
		if l.sprite_frames.has_animation(animation):
			l.visible = true
			if l.animation != animation:
				l.animation = animation
			l.frame = mini(frame, l.sprite_frames.get_frame_count(animation) - 1)
			l.flip_h = flip_h
		else:
			l.visible = false


func has_art() -> bool:
	return not _anims.is_empty()


func has_anim(anim: String) -> bool:
	return _anims.has(anim)


## 依面向和動作選擇動畫。speed_scale：走路 1、跑步 1.8。
## 不循環的動作（揮刀、出拳、踢、撲擊）換到它時從第一格開始播。
func show_pose(anim: String, facing: Vector2, playing: bool, speed := 1.0) -> void:
	if not has_art():
		return
	if not has_anim(anim):
		if anim.begins_with("aim_") and has_anim("aim_pistol"):
			anim = "aim_pistol"
		elif anim.begins_with("shoot_") and has_anim("aim_" + anim.substr(6)):
			anim = "aim_" + anim.substr(6)
		elif anim == "hurt" and has_anim("idle"):
			anim = "idle"
		elif anim.begins_with("slash") and has_anim("slash"):
			anim = "slash"
		else:
			anim = "walk" if has_anim("walk") else _anims[0]
	if facing.length() > 0.1:
		_dir = wrapi(roundi(facing.angle() / (PI / 4.0)), 0, 8)
	var name := "%s_%s" % [anim, DIRS[_dir]]
	flip_h = FLIP[_dir]
	var loops: bool = ANIMS.get(anim, [6.0, true])[1]
	var restart := anim != _kind and not loops
	_kind = anim
	if animation != name:
		var keep := 0 if restart else frame
		var keep_progress := frame_progress
		play(name)
		frame = keep % maxi(sprite_frames.get_frame_count(name), 1)
		frame_progress = 0.0 if restart else keep_progress
	elif restart:
		frame = 0
		play(name)
	speed_scale = speed
	if playing:
		if not is_playing() and (sprite_frames.get_animation_loop(name) or frame < sprite_frames.get_frame_count(name) - 1):
			play()
	else:
		pause()
	_sync_layers()
	# 腳底對齊角色中心下方
	var tex := sprite_frames.get_frame_texture(name, frame)
	if tex:
		position.y = FEET - tex.get_height() * 0.5 + 1.0
		if _shadow:
			_shadow.position = Vector2(0, tex.get_height() * 0.5 - 2.0)
			_shadow.flip_h = false


## 躺平（死掉、睡著）時不要影子
func set_shadow_visible(on: bool) -> void:
	if _shadow:
		_shadow.visible = on
