## 生存模式的撤離點（每 5 波出現在地圖入口）：站上去按互動 = 撤離，這一局的獎勵全部帶走。
class_name SurvivalExtraction
extends Interactable

signal extracted

var _glow: PointLight2D
var _t := 0.0


func _ready() -> void:
	interact_range = 22.0
	_glow = PointLight2D.new()
	_glow.texture = LightTextures.make_radial()
	_glow.texture_scale = 56.0 / (LightTextures.SIZE * 0.5)
	_glow.color = Color(0.45, 1.0, 0.55)
	_glow.energy = 1.0
	add_child(_glow)
	z_index = 1


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return tr("Extract (keep everything)")


func interact(_player: Player) -> void:
	Sfx.play("stairs", global_position)
	enabled = false
	extracted.emit()


func _process(delta: float) -> void:
	_t += delta
	_glow.energy = 0.8 + sin(_t * 4.0) * 0.3
	queue_redraw()


func _draw() -> void:
	var a := 0.5 + sin(_t * 4.0) * 0.3
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(0.45, 1.0, 0.55, a), 2.0)
	draw_rect(Rect2(-2, -10 - sin(_t * 3.0) * 2.0, 4, 6), Color(0.45, 1.0, 0.55, a))
