## 氣候：決定一個區域會不會失溫、失溫多快。
## 本篇（北極的灰鴉島）預設 arctic；之後的資料片（島嶼、森林……）在區域資料設 "climate" 就好，不用改程式。
##   outdoor_loss  戶外每秒失去的體溫
##   cold_loss     室內沒暖氣的地方每秒失去的體溫
##   recover       溫暖的地方每秒恢復的體溫
class_name Climates
extends RefCounted

const DATA := {
	"arctic": {"outdoor_loss": 1.1, "cold_loss": 0.35, "recover": 3.0},
	"temperate": {"outdoor_loss": 0.0, "cold_loss": 0.0, "recover": 3.0},
	"tropical": {"outdoor_loss": 0.0, "cold_loss": 0.0, "recover": 3.0},
}


static func get_climate(id: String) -> Dictionary:
	return DATA.get(id, DATA.arctic)


## 這種氣候會不會失溫（不會的話，畫面上不顯示體溫）
static func has_exposure(id: String) -> bool:
	var c := get_climate(id)
	return c.outdoor_loss > 0.0 or c.cold_loss > 0.0
