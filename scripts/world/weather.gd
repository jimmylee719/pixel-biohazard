## 天氣（v0.11 開放世界的動態系統）。灰鴉島在 11 月是永夜（北緯 78 度，太陽整天不會升起），所以沒有白天黑夜，
## 只有天氣會變：晴（月光、極光：戶外亮一點、敵人看得遠）、下雪（平常）、暴風雪（暗、風聲蓋過腳步、敵人看不遠、更冷、腳印很快被蓋掉）。
## 只影響戶外（Level.is_indoor_at 為 false 的地方）。狀態存在 WorldState.data.weather，main 每幀呼叫 update()。
class_name Weather
extends RefCounted

const KINDS := {
	"clear": {"name": "Clear - aurora", "sight": 1.2, "noise": 1.1, "cold": 0.85, "tracks": 1.0, "dark": Color(0.26, 0.3, 0.36), "snow": 0.0},
	"snow": {"name": "Snowfall", "sight": 1.0, "noise": 1.0, "cold": 1.0, "tracks": 2.0, "dark": Color(0.2, 0.22, 0.3), "snow": 0.4},
	"blizzard": {"name": "Blizzard", "sight": 0.6, "noise": 0.55, "cold": 1.6, "tracks": 6.0, "dark": Color(0.17, 0.19, 0.25), "snow": 1.0},
}
## 下一個天氣（依現在的天氣抽）
const NEXT := {"clear": ["snow", "snow", "clear"], "snow": ["clear", "blizzard", "snow"], "blizzard": ["snow", "snow"]}
const MIN_TIME := 100.0
const MAX_TIME := 200.0
## 換天氣時慢慢過渡（秒）
const BLEND := 8.0


static func state() -> Dictionary:
	if not WorldState.data.has("weather"):
		WorldState.data["weather"] = {"kind": "snow", "prev": "snow", "t": 140.0, "blend": 1.0}
	return WorldState.data.weather


static func kind() -> String:
	return state().kind


## 天氣的某個數值（換天氣的過渡期間內插）
static func value(key: String) -> Variant:
	var s := state()
	var a: Variant = KINDS[s.prev][key]
	var b: Variant = KINDS[s.kind][key]
	var k: float = clampf(s.blend, 0.0, 1.0)
	if a is Color:
		return (a as Color).lerp(b, k)
	return lerpf(float(a), float(b), k)


## 回傳 true = 這一幀換了天氣（main 用來發通知）
static func update(delta: float) -> bool:
	var s := state()
	s.blend = minf(s.blend + delta / BLEND, 1.0)
	s.t -= delta
	if s.t > 0.0:
		return false
	var options: Array = NEXT[s.kind]
	s.prev = s.kind
	s.kind = options[randi() % options.size()]
	s.blend = 0.0 if s.prev != s.kind else 1.0
	s.t = randf_range(MIN_TIME, MAX_TIME)
	return s.prev != s.kind


## 測試、過場用：直接設定天氣
static func set_kind(id: String, seconds := 150.0) -> void:
	var s := state()
	s.prev = id
	s.kind = id
	s.blend = 1.0
	s.t = seconds


static func display_name() -> String:
	return KINDS[kind()].name
