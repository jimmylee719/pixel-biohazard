## 檢查正式地圖：python3 tools/area_patch.py 改完之後跑
##   Godot --headless --path . --script res://tools/check_maps.gd [-- print <區域>]
## 檢查：合併時房間沒有蓋到別的區域的地板、門兩邊都有、巡邏點都在、所有地板連在一起。
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var bad := 0
	for id in Areas.all():
		var a: Dictionary = Areas.all()[id]
		for d in a.doors:
			var to: String = a.doors[d].to
			if not Areas.all().has(to) or not Areas.all()[to].doors.has(d):
				print("!! %s 的門 %s：%s 沒有對應的門" % [id, d, to])
				bad += 1
			var c: Vector2i = a.doors[d].cell
			if String(a.map[c.y])[c.x] != "D":
				print("!! %s 的門 %s 不在 D 上" % [id, d])
				bad += 1
		for e in a.get("enemies", []):
			for ch in String(e.get("route", "")):
				if Areas._find_char(a.map, ch).x < 0:
					print("!! %s 缺少巡邏點 %s" % [id, ch])
					bad += 1
	for id in Areas.all():
		if Areas.rooms().has(id):
			continue
		var data := Areas.get_area(id)
		var parts := 0
		var shared := 0
		for pid in data.offsets:
			for row in Areas.all()[pid].map:
				for ch in String(row):
					if ch != "#":
						parts += 1
			if Areas.rooms().has(pid):
				shared += 1 + Areas.rooms()[pid].get("also", []).size()
		var total := 0
		var open := {}
		for y in data.map.size():
			var row: String = data.map[y]
			for x in row.length():
				if row[x] != "#":
					total += 1
				if not "#CH=~".contains(row[x]):
					open[Vector2i(x, y)] = true
		if total != parts - shared:
			print("!! %s：合併後有格子重疊（%d 格，各區域加起來 %d）" % [id, total, parts - shared])
			bad += 1
		# 連通
		var seen := {}
		var comps := 0
		var biggest := 0
		for start in open:
			if seen.has(start):
				continue
			comps += 1
			var n := 0
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				n += 1
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if open.has(c + d) and not seen.has(c + d):
						seen[c + d] = true
						stack.append(c + d)
			biggest = maxi(biggest, n)
			if n < 40 and comps > 1:
				print("!! %s：有 %d 格走不到（例如 %s）" % [id, n, start])
				bad += 1
		print("%-18s %3d x %-3d 地板 %d 格" % [id, String(data.map[0]).length() if data.map.size() > 0 else 0, data.map.size(), open.size()])
		if args.has("print") and args.has(id):
			for row in data.map:
				print(row)
	print("問題：%d" % bad)
	quit(1 if bad > 0 else 0)
