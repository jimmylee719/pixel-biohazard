## 頻率誘餌（v0.15）：調到 126.05 MHz 的收音機丟在地上，一段一段放出「歌」。
## 怪物（霜鳴菌的宿主）聽到會走過去聽（不會因此警戒）；附近睡著的凍眠體會被吵醒（歌就是讓它們醒來的東西）；
## 人類聽到的只是收音機的雜音，會過去查看。放完 DURATION 秒，收音機燒壞、安靜下來。
class_name SongLure
extends Node2D

const DURATION := 14.0
## 多久放一段（每一段 = 一次聲音事件）
const PULSE := 1.6
## 歌傳多遠（格）
const RANGE_TILES := 9.0

var _t := 0.0
var _next := 0.0
var _rings: Array[float] = []


func _ready() -> void:
	add_to_group("song_lures")
	WorldState.set_flag("seen:lure")
	z_index = 2


func _physics_process(delta: float) -> void:
	_t += delta
	for i in _rings.size():
		_rings[i] += delta
	_rings = _rings.filter(func(r): return r < 1.4)
	if _t >= DURATION:
		if _rings.is_empty():
			Sfx.play("radio_static", global_position, 0.1, -6.0)
			queue_free()
		queue_redraw()
		return
	if _t >= _next:
		_next = _t + PULSE
		_rings.append(0.0)
		NoiseBus.emit_noise(global_position, RANGE_TILES * Player.TILE, self)
		Sfx.play("radio_tune" if int(_t / PULSE) % 2 == 0 else "radio_static", global_position, 0.15, -4.0)
	queue_redraw()


func is_playing() -> bool:
	return _t < DURATION


func _draw() -> void:
	var tex := Art.tex("props/song_radio")
	if tex:
		draw_texture(tex, -tex.get_size() * 0.5 + Vector2(0, -2), Color(1, 1, 1) if is_playing() else Color(0.5, 0.5, 0.55))
	else:
		draw_rect(Rect2(-3, -3, 6, 5), Color(0.35, 0.38, 0.4))
	# 歌：往外擴的波紋（126.05 的「迴頻」，淡青色、有一點起伏）
	for r in _rings:
		var k := r / 1.4
		var radius := 4.0 + k * 34.0
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			var wob := sin(a * 6.0 + r * 9.0) * 1.2 * (1.0 - k)
			pts.append(Vector2.RIGHT.rotated(a) * (radius + wob) * Vector2(1.0, 0.6))
		draw_polyline(pts, Color(0.55, 0.95, 0.95, 0.55 * (1.0 - k)), 1.0)
