## 全島地圖（v0.11，開放世界）：地圖畫面的第一頁。灰鴉島的輪廓、每個地點、彼此怎麼走、你在哪、任務在哪。
## 地點 = 一個或幾個主地圖（樓上樓下算同一個地點）。pos 是在島的方框裡的位置（0～1）。
class_name Island
extends RefCounted

const PLACES := {
	"station": {"name": "North Latitude Station", "pos": Vector2(0.5, 0.74),
		"roots": ["south_shore", "station_2f", "station_b1", "drill_shaft", "shaft_bottom"], "safe": true},
	"hangar": {"name": "Hangar", "pos": Vector2(0.4, 0.56), "roots": ["hangar"]},
	"tower": {"name": "Antenna Tower", "pos": Vector2(0.83, 0.46), "roots": ["tower_yard", "tower_top"]},
	"huts": {"name": "Weather Camp", "pos": Vector2(0.17, 0.58), "roots": ["weather_huts"], "safe": true},
	"harbor": {"name": "North Harbor / Gate One", "pos": Vector2(0.42, 0.27), "roots": ["north_harbor"], "safe": true},
	"ship": {"name": "MV Boreal Star", "pos": Vector2(0.6, 0.06), "roots": ["cruise_deck", "cruise_hold", "cruise_sundeck"]},
}
## 路（[地點, 地點, 怎麼走]）
const ROUTES := [["station", "hangar", "foot"], ["station", "huts", "foot"], ["hangar", "tower", "snowcat"],
	["huts", "harbor", "foot"], ["harbor", "ship", "gangway"]]
## 海岸線（島的方框裡 0～1）
const COAST := [Vector2(0.08, 0.5), Vector2(0.12, 0.36), Vector2(0.24, 0.24), Vector2(0.3, 0.16), Vector2(0.44, 0.14),
	Vector2(0.56, 0.2), Vector2(0.66, 0.18), Vector2(0.78, 0.26), Vector2(0.92, 0.36), Vector2(0.95, 0.5), Vector2(0.9, 0.62),
	Vector2(0.78, 0.7), Vector2(0.66, 0.84), Vector2(0.54, 0.9), Vector2(0.4, 0.88), Vector2(0.28, 0.8), Vector2(0.14, 0.7)]


static func place_of(root: String) -> String:
	for id in PLACES:
		if PLACES[id].roots.has(root):
			return id
	return ""
