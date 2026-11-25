## 雪地車：打倒機庫裡的 Boss 之後才能使用，在機庫和天線塔之間來回（區域資料的 snowcat_to）。
## 只是兩點之間的捷徑，不是自由駕駛。
class_name Snowcat
extends Interactable

signal drive(target_area: String)

const BOSS_ID := "tundra_mother"


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	if not _ready_to_go():
		return "Snowcat (not safe yet)"
	return tr("Drive to %s") % tr(Areas.get_area(level.snowcat_destination()).title)


func counts_as_interaction(_player: Player) -> bool:
	return _ready_to_go()


func interact(player: Player) -> void:
	if _ready_to_go() and not player.is_carrying():
		Sfx.play("snowcat_engine", global_position)
		drive.emit(level.snowcat_destination())


func _ready_to_go() -> bool:
	return WorldState.has_flag("defeated:" + BOSS_ID) and level != null and level.snowcat_destination() != ""


func _draw() -> void:
	draw_rect(Rect2(-12, -7, 24, 12), Color(0.85, 0.55, 0.15))
	draw_rect(Rect2(-12, 5, 24, 3), Color(0.2, 0.2, 0.22))
	draw_rect(Rect2(-4, -10, 12, 5), Color(0.6, 0.8, 0.9))
