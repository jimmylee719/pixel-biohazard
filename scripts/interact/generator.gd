## 發電機：倒入燃料就能恢復研究站的電力。
## 電力會改變整張地圖：燈亮（看得清楚，但也更容易被發現）、暖氣恢復（凍眠體會醒）。
## 啟動時的轟鳴聲非常大。
class_name Generator
extends Interactable

signal powered

const NOISE_TILES := 14.0

var _lamp: PointLight2D


func _ready() -> void:
	_lamp = PointLight2D.new()
	_lamp.texture = LightTextures.make_radial()
	_lamp.texture_scale = 20.0 / (LightTextures.SIZE * 0.5)
	_lamp.energy = 0.7
	add_child(_lamp)
	sync_from_state()


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	if WorldState.power_on:
		return "Generator (running)"
	return "Refuel and start generator" if WorldState.carrying == "fuel" else "Generator (no fuel)"


func counts_as_interaction(_player: Player) -> bool:
	return WorldState.carrying == "fuel" and not WorldState.power_on


func interact(_player: Player) -> void:
	if WorldState.power_on or WorldState.carrying != "fuel":
		return
	Sfx.play("generator_start", global_position)
	WorldState.carrying = ""
	WorldState.set_flag("power_on")
	NoiseBus.emit_noise(global_position, NOISE_TILES * Level.TILE, self)
	sync_from_state()
	powered.emit()


func sync_from_state() -> void:
	if _lamp:
		_lamp.color = Color(0.4, 1.0, 0.5) if WorldState.power_on else Color(1.0, 0.3, 0.2)
	queue_redraw()


func _draw() -> void:
	if draw_art("generator"):
		draw_rect(Rect2(3, -9, 2, 2), Color(0.4, 1.0, 0.5) if WorldState.power_on else Color(1.0, 0.3, 0.2))
		return
	draw_rect(Rect2(-6, -6, 12, 12), Color(0.3, 0.32, 0.3))
	draw_rect(Rect2(-6, -6, 12, 12), Color(0.55, 0.58, 0.5), false, 1.0)
	var led := Color(0.4, 1.0, 0.5) if WorldState.power_on else Color(1.0, 0.3, 0.2)
	draw_rect(Rect2(-1, -4, 2, 2), led)
