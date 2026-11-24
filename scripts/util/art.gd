## 讀取 assets/sprites/ 裡的像素圖（tools/import_art.gd 產生）。沒有圖就回傳 null，呼叫端改畫色塊。
class_name Art
extends RefCounted

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "res://assets/sprites/%s.png" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = t
	return t
