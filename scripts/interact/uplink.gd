## 上行終端機（天線塔頂層）：對外發出訊號，選擇要求救援、隔離或摧毀研究站（結局方向）。
## 天線碟結冰時（除冰器沒開＝ dish 區域是冷的）發不出去。訊號只能發一次。
## 選擇介面在 main.gd（_open_signal_panel）；這裡只決定能不能打開。
class_name Uplink
extends Interactable

signal opened
signal message_shown(text: String)

## 天線碟所在的溫度區域
const DISH_ZONE := "dish"

var _glow: PointLight2D


func _ready() -> void:
	_glow = PointLight2D.new()
	_glow.texture = LightTextures.make_radial()
	_glow.texture_scale = 30.0 / (LightTextures.SIZE * 0.5)
	_glow.color = Color(1.0, 0.55, 0.3)
	_glow.energy = 0.9
	add_child(_glow)
	level.zone_heat_changed.connect(func(_z, _h): _refresh())
	_refresh()


func sync_from_state() -> void:
	if _glow:
		_refresh()


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	if WorldState.signal_choice() != "":
		return "Uplink (signal sent)"
	return "Transmit" if dish_ready() else "Uplink (no signal)"


## 任務步驟在選完訊息之後才算完成（main.gd 發出事件），打開介面不算。
func counts_as_interaction(_player: Player) -> bool:
	return false


func interact(_player: Player) -> void:
	if WorldState.signal_choice() != "":
		message_shown.emit("The uplink is silent. Whatever comes now, you already called it.")
	elif not dish_ready():
		message_shown.emit("NO CARRIER. The dish outside is iced over - the de-icer must be off.")
	else:
		opened.emit()


func dish_ready() -> bool:
	return level != null and level.is_zone_heated(DISH_ZONE)


func _refresh() -> void:
	# 綠燈 = 可以發訊；橘燈 = 天線碟結冰
	_glow.color = Color(0.4, 1.0, 0.55) if dish_ready() else Color(1.0, 0.55, 0.3)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-8, -7, 16, 12), Color(0.2, 0.22, 0.25))
	draw_rect(Rect2(-6, -5, 12, 6), Color(0.25, 0.6, 0.4) if dish_ready() else Color(0.6, 0.35, 0.2))
	draw_line(Vector2(5, -7), Vector2(8, -12), Color(0.7, 0.72, 0.75), 1.0)
