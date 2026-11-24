## 任務系統：主線（Main Ops）＋支線（Side Ops）。
## 任務用資料定義，每個任務有幾個步驟，每個步驟等待一種遊戲事件（見 WorldState.game_event）。
## 進度存在 WorldState 裡，所以會跟著檢查點和存檔走。
##
## 步驟類型：
##   enter_area  進入某個區域（target = 區域 id）
##   interact    和某個有名字的物件互動（target = 物件名稱，見 Areas 的 names）
##   collect     撿到某個有名字的物件
##   defeat      打倒某個 Boss（target = Boss id）
## requires：前置任務，全部完成後這個任務才會出現。
## reward：完成時給的東西（bottles = 空瓶數、intel = 取得某區域的巡邏情報）。
## radio：有這個欄位的支線，要先在安全屋用無線電「聽到」才會出現（內容就是無線電訊息）。
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
		"id": "find_shelter", "main": true, "requires": ["enter_station"],
		"title": "Find somewhere safe",
		"desc": "There has to be a sealed room somewhere off the corridors. Find it and get on the radio.",
		"steps": [
			{"type": "enter_area", "target": "station_safe"},
			{"type": "interact", "target": "radio_safe"},
		],
	},
	{
		"id": "find_stairs", "main": true, "requires": ["find_shelter"],
		"title": "Reach the upper floor",
		"desc": "Kovac says the antenna controls are upstairs. The stairs are in the lounge.",
		"steps": [{"type": "enter_area", "target": "station_2f"}],
	},
	{
		"id": "director_records", "main": true, "requires": ["find_stairs"],
		"title": "Halvorsen's records",
		"desc": "The director's office is at the east end of the upper floor. The door needs a keycard - someone in the dorms had one.",
		"steps": [
			{"type": "collect", "target": "keycard_2f"},
			{"type": "interact", "target": "director_terminal"},
		],
		"reward": {"access": 2},
	},
	{
		"id": "restore_power", "main": true, "requires": ["director_records"],
		"title": "Restore power",
		"desc": "The B1 generator ran dry. There's diesel at the fuel depot east of the shore. Your level 2 card opens the basement door in the lab.",
		"steps": [
			{"type": "collect", "target": "fuel_can"},
			{"type": "interact", "target": "generator_b1"},
		],
	},
	{
		"id": "hangar_snowcat", "main": true, "requires": ["restore_power"],
		"title": "The hangar",
		"desc": "With power back, the hangar door north of the shore will open. The snowcat inside can reach the antenna. Something big was locked in there.",
		"steps": [
			{"type": "enter_area", "target": "hangar"},
			{"type": "defeat", "target": "tundra_mother"},
			{"type": "interact", "target": "snowcat"},
		],
	},
	{
		"id": "send_signal", "main": true, "requires": ["hangar_snowcat"],
		"title": "The antenna",
		"desc": "Climb to the comms deck at the top of the antenna tower and get a message off the island. What you ask for is up to you.",
		"steps": [
			{"type": "enter_area", "target": "tower_top"},
			{"type": "interact", "target": "uplink"},
		],
	},
	{
		"id": "depot_manifest", "main": false, "requires": ["director_records"],
		"radio": "KOVAC: \"Going to the depot? Find the manifest first. Mendez said something nests in that warehouse.\"",
		"title": "Depot manifest",
		"desc": "Read the manifest in the depot warehouse before you go for the fuel.",
		"steps": [{"type": "collect", "target": "manifest_depot"}],
		"reward": {"intel": "fuel_depot"},
	},
	{
		"id": "supply_drop", "main": false,
		"title": "Supply drop",
		"desc": "A supply crate fell from the helicopter somewhere on the shore.",
		"steps": [{"type": "collect", "target": "supply_crate_shore"}],
		"reward": {"bottles": 1},
	},
	{
		"id": "lost_tape", "main": false, "requires": ["find_shelter"],
		"radio": "KOVAC: \"Mendez kept a recorder in the lab. If it's still there, it'll tell you how they hunt.\"",
		"title": "The researcher's tape",
		"desc": "Mendez's recorder should still be in the lab. It may reveal the patrol patterns.",
		"steps": [{"type": "collect", "target": "tape_lab"}],
		"reward": {"intel": "station_1f"},
	},
	{
		"id": "cold_lounge", "main": false, "requires": ["find_shelter"],
		"radio": "KOVAC: \"They go sluggish in the cold. The lab breaker controls the lounge heating. Use it.\"",
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
	var m := get_mission(mission_id)
	if not _requirements_met(m):
		return false
	return not m.has("radio") or WorldState.has_flag("radio:" + mission_id)


func _requirements_met(m: Dictionary) -> bool:
	for req in m.get("requires", []):
		if not is_done(req):
			return false
	return true


## 在安全屋用無線電：收到所有「條件已經滿足、還沒聽過」的委託，回傳訊息文字。
func receive_radio() -> Array[String]:
	var messages: Array[String] = []
	for m in DATA:
		if m.has("radio") and _requirements_met(m) and not WorldState.has_flag("radio:" + m.id):
			WorldState.set_flag("radio:" + m.id)
			messages.append(m.radio)
			mission_updated.emit(m.id)
	return messages


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
	if reward.has("access"):
		WorldState.access_level = int(reward.access)
	if reward.has("intel"):
		WorldState.set_flag("intel:" + String(reward.intel))
