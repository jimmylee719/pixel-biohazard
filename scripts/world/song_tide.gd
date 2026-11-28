## 唱潮（v0.17，原創機制，綁世界觀）：冰層下的菌落不是一直用同樣的音量在唱，126.05 的歌每隔幾分鐘會「漲潮」一次。
## 燈籠監聽站在 1962 年裝了一支自動防空喇叭：訊號強度超過門檻就響（當年是用來叫值班的人戴上耳罩）。
## 那支喇叭到 2026 年還接著電，所以每次漲潮，整座島都聽得到。
##   CALM（平靜）→ WARNING（預告：無線電雜訊變大、柯瓦奇提醒，WARNING_TIME 秒）→ TIDE（唱潮：喇叭響、TIDE_TIME 秒）→ CALM
## 唱潮中：感染者（非人類、非 Boss）醒來在附近遊走、聽覺變好；睡著的凍眠體起身；結束後沒在追你的就地躺回去睡（地圖每次都不一樣）。
## 人類不受影響（他們只是又聽到那支喇叭）。1962 年的記憶、Boss 戰暫停計時（main 呼叫 update 時判斷）。
## 狀態存在 WorldState.data.tide。
class_name SongTide
extends RefCounted

enum Phase { CALM, WARNING, TIDE }

const CALM_MIN := 240.0
const CALM_MAX := 380.0
const WARNING_TIME := 30.0
const TIDE_TIME := 60.0
## 唱潮中感染者的聽覺倍率、遊走的範圍（格）
const HEARING_MULT := 1.5
const ROAM_TILES := 6.0
## 第一次唱潮前比較久（讓玩家先熟悉地圖）
const FIRST_CALM := 420.0

## 測試用：關掉整個系統
static var enabled := true


static func state() -> Dictionary:
	if not WorldState.data.has("tide"):
		WorldState.data["tide"] = {"phase": Phase.CALM, "t": FIRST_CALM, "count": 0}
	return WorldState.data.tide


static func phase() -> int:
	return state().phase if enabled else Phase.CALM


## 唱潮中（感染者醒著遊走）
static func active() -> bool:
	return phase() == Phase.TIDE


static func warning() -> bool:
	return phase() == Phase.WARNING


## 這個階段剩幾秒
static func time_left() -> float:
	return maxf(float(state().t), 0.0)


## 推進計時。回傳這一幀進入的階段（沒換就是 -1），main 用來放喇叭、發通知
static func update(delta: float) -> int:
	if not enabled:
		return -1
	var s := state()
	s.t -= delta
	if s.t > 0.0:
		return -1
	match int(s.phase):
		Phase.CALM:
			_go(Phase.WARNING, WARNING_TIME)
		Phase.WARNING:
			_go(Phase.TIDE, TIDE_TIME)
			s.count += 1
		_:
			_go(Phase.CALM, randf_range(CALM_MIN, CALM_MAX))
	return int(s.phase)


## 測試、除錯用：直接切到某個階段
static func set_phase(p: int, seconds := -1.0) -> void:
	var t := seconds
	if t < 0.0:
		t = WARNING_TIME if p == Phase.WARNING else (TIDE_TIME if p == Phase.TIDE else CALM_MAX)
	_go(p, t)


static func _go(p: int, seconds: float) -> void:
	var s := state()
	s.phase = p
	s.t = seconds
