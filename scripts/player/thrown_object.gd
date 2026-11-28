## 丟出去的東西（石頭、空瓶、汽油彈、滅火器）：飛一小段拋物線，落地時發出聲音。
## 汽油彈落地會起火（Fire）。碰到牆會提早落地（由丟的人先算好落點）。
class_name ThrownObject
extends Node2D

const FLIGHT_TIME := 0.45
const ARC_HEIGHT := 10.0
const SHARDS_TIME := 0.6

## 物品 id（Items.THROWABLES 的 key），或 "extinguisher"
var kind := "bottle"
var noise_radius := 96.0
var makes_fire := false
var color := Color(0.6, 0.9, 0.7)

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _landed := false


func setup(item_kind: String, noise_tiles: float, fire: bool, c: Color) -> void:
	kind = item_kind
	noise_radius = noise_tiles * Player.TILE
	makes_fire = fire
	color = c


func launch(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	global_position = from


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		var k := minf(_t / FLIGHT_TIME, 1.0)
		global_position = _from.lerp(_to, k)
		if k >= 1.0:
			_land()
	elif _t >= SHARDS_TIME:
		queue_free()
	queue_redraw()


func _land() -> void:
	_landed = true
	_t = 0.0
	NoiseBus.emit_noise(_to, noise_radius, self)
	match kind:
		"stone":
			Sfx.play("stone_land", _to)
		"extinguisher":
			Sfx.play("extinguisher_clang", _to)
		"molotov":
			Sfx.play("bottle_break", _to)
			Sfx.play("molotov_ignite", _to)
		"song_radio":
			Sfx.play("stone_land", _to)
			var lure := SongLure.new()
			get_parent().add_child(lure)
			lure.global_position = _to
		_:
			Sfx.play("bottle_break", _to)
	if makes_fire:
		var fire := Fire.new()
		fire.radius = 26.0
		fire.duration = 7.0
		get_parent().add_child(fire)
		fire.global_position = _to


func _draw() -> void:
	if not _landed:
		var lift := sin(PI * minf(_t / FLIGHT_TIME, 1.0)) * ARC_HEIGHT
		var size := 4.0 if kind == "extinguisher" else 3.0
		draw_rect(Rect2(Vector2(-size * 0.5, -size * 0.5 - lift), Vector2(size, size)), color)
	elif kind != "stone" and kind != "song_radio":
		var spread := 2.0 + _t * 10.0
		for i in 5:
			var dir := Vector2.RIGHT.rotated(TAU * i / 5.0 + 0.4)
			draw_rect(Rect2(dir * spread - Vector2(0.5, 0.5), Vector2(1, 1)), color)
