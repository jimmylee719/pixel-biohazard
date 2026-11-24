## 無線電頻率：玩家在安全屋的無線電自己輸入頻率，可以聽到情報。
## 頻率用「百分之一 MHz」的整數表示（12435 = 124.35 MHz），避免浮點誤差。
## 頻段：120.00～129.95 MHz，每格 0.05。
##
## 欄位：
##   freq     頻率
##   label    記在備忘錄裡的名稱
##   lines    聽到的內容（依序顯示）
##   reveal   聽到後設定的旗標（讓地圖上的隱藏物品出現）
##   known    一開始就知道（主角是飛行員，知道航空緊急頻率）
## 頻率線索放在地圖上的錄音帶、筆記裡（Areas 的 learn 欄位）；沒有任何線索的頻率只能靠訊號強度慢慢找。
class_name Frequencies
extends RefCounted

const BAND_MIN := 12000
const BAND_MAX := 12995
const FINE_STEP := 5
const COARSE_STEP := 100
## 調到距離目標多近算「對準」（0.02 MHz）
const LOCK_TOLERANCE := 2
## 訊號強度在多遠的範圍內開始出現（0.60 MHz）
const SIGNAL_RANGE := 60

const DATA := [
	{
		"freq": 12150, "id": "guard", "label": "Air emergency",
		"known": true,
		"lines": [
			"[121.50] ...EMERGENCY LOCATOR. AIRCRAFT B-77031. POSITION GREYCROW ISLAND SOUTH SHORE...",
			"That's your own beacon. Under it, fainter: a second one. B-6204 - the supply flight that vanished three weeks ago.",
		],
	},
	{
		"freq": 12435, "id": "mendez", "label": "Mendez",
		"lines": [
			"MENDEZ (looped): \"Day nine. If someone hears this - security's shotgun is not in the armory.\"",
			"\"I hid it under the floor grate at the far east end of the south corridor. Two shells in it, a few more beside it.\"",
			"\"Don't let Halvorsen find it. He'd rather keep them alive than keep us alive.\"",
		],
		"reveal": "reveal:shotgun_1f",
	},
	{
		"freq": 12780, "id": "ops_log", "label": "Ops log",
		"lines": [
			"[127.80] GREYCROW OPS - AUTOMATED LOG. SUPPLY DROP 11 CACHED, EAST SHORE ROCKS BELOW THE STATION WALL.",
			"CONTENTS: 9MM AMMUNITION. LOG ENDS.",
		],
		"reveal": "reveal:cache_shore",
	},
	{
		"freq": 12605, "id": "hold", "label": "Unknown",
		"lines": [
			"[126.05] ...hold position. Do not transmit. Retrieval is inbound.",
			"\"Sample integrity is priority one. Survivors are... secondary.\"",
		],
		"reveal": "lore:retrieval",
	},
]


static func format(freq: int) -> String:
	return "%d.%02d" % [freq / 100, freq % 100]


static func find_exact(freq: int) -> Dictionary:
	for f in DATA:
		if absi(f.freq - freq) <= LOCK_TOLERANCE:
			return f
	return {}


static func by_freq(freq: int) -> Dictionary:
	for f in DATA:
		if f.freq == freq:
			return f
	return {}


## 0～1：越接近某個電台訊號越強
static func signal_strength(freq: int) -> float:
	var best := 0.0
	for f in DATA:
		var d := absi(f.freq - freq)
		best = maxf(best, clampf(1.0 - float(d) / SIGNAL_RANGE, 0.0, 1.0))
	return best
