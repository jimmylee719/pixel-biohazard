## 任務系統：主線（Main Ops）＋支線（Side Ops）。
## 任務用資料定義，每個任務有幾個步驟，每個步驟等待一種遊戲事件（見 WorldState.game_event）。
## 進度存在 WorldState 裡，所以會跟著檢查點和存檔走。
##
## 步驟類型：
##   enter_area  進入某個區域（target = 區域 id）
##   interact    和某個有名字的物件互動（target = 物件名稱，見 Areas 的 names）
##   collect     撿到某個有名字的物件
## requires：前置任務，全部完成後這個任務才會出現。
## reward：完成時給的東西（bottles = 空瓶數、intel = 取得某區域的巡邏情報）。
extends Node

signal mission_updated(mission_id: String)
signal mission_completed(mission_id: String)

const DATA := [
	{
		"id": "enter_station", "main": true,
		"title": "Get inside the station",
		"desc": "The blizzard will kill you out here. Find a way into the research station.",
		"steps": [{"type": "enter_area", "target": "station_1f"}],
	},
	{
		"id": "find_stairs", "main": true, "requires": ["enter_station"],
		"title": "Reach the upper floor",
		"desc": "The radio mast is on the roof. Find the stairs.",
		"steps": [{"type": "interact", "target": "stairs_up"}],
	},
	{
		"id": "supply_drop", "main": false,
		"title": "Supply drop",
		"desc": "A supply crate fell from the helicopter somewhere on the shore.",
		"steps": [{"type": "collect", "target": "supply_crate_shore"}],
		"reward": {"bottles": 1},
	},
	{
		"id": "lost_tape", "main": false, "requires": ["enter_station"],
		"title": "The researcher's tape",
		"desc": "Someone recorded the first days of the outbreak. Find the tape in the lab.",
		"steps": [{"type": "collect", "target": "tape_lab"}],
		"reward": {"intel": "station_1f"},
	},
	{
		"id": "cold_lounge", "main": false, "requires": ["enter_station"],
		"title": "Cut the heat",
		"desc": "The infected slow down in the cold. Shut off the lounge heating from the lab breaker.",
		"steps": [{"type": "interact", "target": "lounge_breaker"}],
	},
]


func _ready() -> void:
	WorldState.game_event.connect(_on_game_event)


func get_mission(mission_id: String) -> Dictionary:
	for m in DATA:
		if m.id == mission_id:
			return m
	return {}


func step_index(mission_id: String) -> int:
	return WorldState.get_flag("mission:" + mission_id, 0)


func is_done(mission_id: String) -> bool:
	return step_index(mission_id) >= get_mission(mission_id).steps.size()


func is_available(mission_id: String) -> bool:
	for req in get_mission(mission_id).get("requires", []):
		if not is_done(req):
			return false
	return true


func is_active(mission_id: String) -> bool:
	return is_available(mission_id) and not is_done(mission_id)


## 畫面上追蹤的任務：第一個進行中的主線任務。
func tracked_mission() -> Dictionary:
	for m in DATA:
		if m.main and is_active(m.id):
			return m
	return {}


func list_visible() -> Array:
	return DATA.filter(func(m): return is_available(m.id))


func _on_game_event(kind: String, id: String) -> void:
	for m in DATA:
		if not is_active(m.id):
			continue
		var idx := step_index(m.id)
		var step: Dictionary = m.steps[idx]
		if step.type == kind and step.target == id:
			WorldState.set_flag("mission:" + m.id, idx + 1)
			mission_updated.emit(m.id)
			if is_done(m.id):
				_give_reward(m.get("reward", {}))
				mission_completed.emit(m.id)


func _give_reward(reward: Dictionary) -> void:
	if reward.has("bottles"):
		WorldState.bottles = WorldState.bottles + int(reward.bottles)
	if reward.has("intel"):
		WorldState.set_flag("intel:" + String(reward.intel))
