## 配電箱：切換一個區域的暖氣。關掉暖氣後，那一區的感染者會變慢、變遲鈍。
## 但扳動開關的聲音很大，會引來附近的敵人。
class_name Breaker
extends Interactable

const NOISE_TILES := 8.0
const HEAT_ON_COLOR := Color(1.0, 0.45, 0.25)
const HEAT_OFF_COLOR := Color(0.4, 0.75, 1.0)

var zone_name := ""

var _indicator: PointLight2D


func _ready() -> void:
	# 小指示燈：在黑暗中也看得到配電箱的位置
	_indicator = PointLight2D.new()
	_indicator.texture = LightTextures.make_radial()
	_indicator.texture_scale = 18.0 / (LightTextures.SIZE * 0.5)
	_indicator.energy = 0.8
	add_child(_indicator)
	level.zone_heat_changed.connect(func(_z, _h): _refresh())
	_refresh()


func sync_from_state() -> void:
	if _indicator:
		_refresh()


func get_prompt(_player: Player) -> String:
	return "Heat OFF (%s)" % zone_name if level.is_zone_heated(zone_name) else "Heat ON (%s)" % zone_name


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func interact(_player: Player) -> void:
	level.set_zone_heated(zone_name, not level.is_zone_heated(zone_name))
	NoiseBus.emit_noise(global_position, NOISE_TILES * Level.TILE, self)


func _refresh() -> void:
	_indicator.color = HEAT_ON_COLOR if level.is_zone_heated(zone_name) else HEAT_OFF_COLOR
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-5, -6, 10, 12), Color(0.35, 0.36, 0.38))
	draw_rect(Rect2(-5, -6, 10, 12), Color(0.55, 0.56, 0.6), false, 1.0)
	var led := HEAT_ON_COLOR if level.is_zone_heated(zone_name) else HEAT_OFF_COLOR
	draw_rect(Rect2(-1, -4, 2, 2), led)
	draw_rect(Rect2(-2, 0, 4, 4), Color(0.2, 0.2, 0.22))
