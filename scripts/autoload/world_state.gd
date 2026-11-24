## 世界狀態：所有需要跨區域、跨重來保存的東西都放這裡。
## 撿過的物品、暖氣開關、任務進度、主角攜帶的物品、取得的情報……
## 之後的存檔功能也只要把 data 存起來。
##
## 檢查點：每次進入一個區域時記錄一次。被抓到時回到最近的檢查點（區域入口）。
extends Node

## 遊戲事件（任務系統監聽）：kind = "enter_area" / "interact" / "collect"，id = 物件或區域名稱
signal game_event(kind: String, id: String)
signal changed

var data := {}
var _checkpoint := {}


func _ready() -> void:
	new_game()


func new_game() -> void:
	data = {
		"area": Areas.START_AREA,
		"entry": Areas.START_ENTRY,
		"bottles": 0,
		"flags": {},
	}
	_checkpoint = data.duplicate(true)


# ── 通用旗標 ──

func has_flag(key: String) -> bool:
	return data.flags.has(key)


func get_flag(key: String, default: Variant = null) -> Variant:
	return data.flags.get(key, default)


func set_flag(key: String, value: Variant = true) -> void:
	data.flags[key] = value
	changed.emit()


# ── 常用的包裝 ──

var bottles: int:
	get:
		return data.bottles
	set(value):
		data.bottles = value
		changed.emit()


func is_taken(item_id: String) -> bool:
	return has_flag("taken:" + item_id)


func mark_taken(item_id: String) -> void:
	set_flag("taken:" + item_id)


func is_zone_heated(area_id: String, zone: String, default: bool) -> bool:
	return get_flag("heat:%s:%s" % [area_id, zone], default)


func set_zone_heated(area_id: String, zone: String, heated: bool) -> void:
	set_flag("heat:%s:%s" % [area_id, zone], heated)


func emit_event(kind: String, id: String) -> void:
	if id != "":
		game_event.emit(kind, id)


# ── 檢查點 ──

## 進入區域時呼叫：記住現在的狀態，被抓到時回到這裡。
func save_checkpoint(area_id: String, entry: String) -> void:
	data.area = area_id
	data.entry = entry
	_checkpoint = data.duplicate(true)


func restore_checkpoint() -> void:
	data = _checkpoint.duplicate(true)
	changed.emit()


func checkpoint_area() -> String:
	return _checkpoint.area


func checkpoint_entry() -> String:
	return _checkpoint.entry
