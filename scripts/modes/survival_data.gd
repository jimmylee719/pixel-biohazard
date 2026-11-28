## 生存模式「長夜」的資料：地圖、波次的敵人組合、分數、補給、解鎖（設計見 docs/SURVIVAL_MODE.md）。
class_name SurvivalData
extends RefCounted

## 地圖：區域 id、入口（玩家出生、撤離點）、需要的解鎖（"" = 一開始就有）
const MAPS := {
	"station_1f": {"name": "Station 1F", "entry": "front", "unlock": "", "power": true,
		"desc": "Corridors, labs and lockers. Close quarters - nowhere to run far."},
	"weather_huts": {"name": "Weather Huts", "entry": "huts", "unlock": "",
		"desc": "Open snow between the huts. Hounds come fast in the open."},
	"north_harbor": {"name": "North Harbor", "entry": "harbor", "unlock": "map_harbor",
		"desc": "The docks. Gatekeeper troops join the night - and they carry radios."},
}

## 每一波的敵人：最早出現的波數、權重
const SPAWNS := [
	{"type": "patroller", "from": 1, "weight": 6},
	{"type": "listener", "from": 2, "weight": 3},
	{"type": "crawler", "from": 3, "weight": 3},
	{"type": "hound", "from": 4, "weight": 2},
	{"type": "chorister", "from": 5, "weight": 1},
	{"type": "husk", "from": 6, "weight": 1},
	{"type": "runner", "from": 2, "weight": 3},
	{"type": "spitter", "from": 4, "weight": 2},
	{"type": "brute", "from": 8, "weight": 1},
]
## 北港另外混進武裝人員
const HUMAN_MAPS := ["north_harbor"]
## 每 5 波的「深夜潮」一定出現的敵人
const SURGE := ["husk", "chorister", "brute"]

## 擊倒分數（Enemy.get_species()）
const KILL_SCORE := {
	"watcher": 100, "sleeper": 80, "listener": 150, "crawler": 120, "husk": 300,
	"chorister": 200, "hound": 150, "guard": 200, "runner": 120, "spitter": 180, "brute": 400,
}
const COMBO_WINDOW := 5.0
const COMBO_STEP := 0.25
const COMBO_MAX := 3.0
const STEALTH_MULT := 1.5
const WAVE_BONUS := 500
const NO_DAMAGE_BONUS := 300
## 波與波之間休息幾秒（可以撤離的那一次比較長）
const BREAK_TIME := 12.0
const EXTRACT_BREAK_TIME := 25.0
## 每幾波可以撤離
const EXTRACT_EVERY := 5
## 死掉時帶回的殘響點數比例
const DEATH_KEEP := 0.3
## 分數 → 殘響點數（每 100 分 1 點）
const POINTS_PER_SCORE := 0.01
## 評價（分數門檻）
const RANKS := [["S", 30000], ["A", 15000], ["B", 6000], ["C", 0]]

## 波間空投：[物品, 數量, 最早波數]
const SUPPLIES := [
	["ammo", 8, 1], ["med", 1, 1], ["stone", 2, 1], ["shells", 3, 2], ["heat_pack", 1, 2],
	["molotov", 1, 3], ["song_radio", 1, 3], ["nails", 12, 3], ["flares", 1, 4], ["rifle_rounds", 3, 5], ["antibiotic", 1, 4],
]

## 起始武器（生存模式用）：需要的解鎖、附帶的彈藥
const LOADOUTS := {
	"pistol": {"unlock": "", "ammo": ["ammo", 16]},
	"shotgun": {"unlock": "weapon_shotgun", "ammo": ["shells", 6]},
	"nailgun": {"unlock": "weapon_nailgun", "ammo": ["nails", 24]},
	"flare_gun": {"unlock": "weapon_flare_gun", "ammo": ["flares", 3]},
	"rifle": {"unlock": "weapon_rifle", "ammo": ["rifle_rounds", 6]},
}

## 商店：解鎖 id → 價格、名稱、說明
const UNLOCKS := {
	"weapon_shotgun": {"cost": 30, "name": "Shotgun loadout", "desc": "Start survival runs with the shotgun."},
	"weapon_nailgun": {"cost": 40, "name": "Nail gun loadout", "desc": "Start survival runs with the silent nail gun."},
	"weapon_flare_gun": {"cost": 50, "name": "Flare gun loadout", "desc": "Start survival runs with the flare gun."},
	"weapon_rifle": {"cost": 80, "name": "Hunting rifle loadout", "desc": "Start survival runs with the rifle."},
	"melee_axe": {"cost": 40, "name": "Fire axe", "desc": "Carry the fire axe in every survival run."},
	"perk_med": {"cost": 25, "name": "Extra first aid", "desc": "One more first aid kit at the start of each run."},
	"map_harbor": {"cost": 60, "name": "Map: North Harbor", "desc": "Unlock the harbor map, with Gatekeeper troops."},
	"cache_1": {"cost": 50, "name": "Story cache I", "desc": "New story games: a first aid kit and pistol rounds wait in the safe room box."},
	"cache_2": {"cost": 120, "name": "Story cache II", "desc": "New story games: a nail gun and nails wait in the safe room box."},
}

## 主線的「補給箱」解鎖：新遊戲時放進儲物箱的東西
const STORY_CACHES := {
	"cache_1": {"med": 1, "ammo": 8},
	"cache_2": {"nailgun": 1, "nails": 12},
}


static func rank_for(score: int) -> String:
	for r in RANKS:
		if score >= r[1]:
			return r[0]
	return "C"


static func wave_size(wave: int) -> int:
	return mini(3 + 2 * wave, 24)


static func map_unlocked(map: String) -> bool:
	var need: String = MAPS[map].unlock
	return need == "" or WorldState.is_unlocked(need)


static func loadout_unlocked(weapon: String) -> bool:
	var need: String = LOADOUTS[weapon].unlock
	return need == "" or WorldState.is_unlocked(need)
