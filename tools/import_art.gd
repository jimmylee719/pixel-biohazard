## 把 art_raw/ 裡 ComfyUI 生成的 1024x1024 圖轉成遊戲用的小像素圖，輸出到 assets/sprites/。
## 執行：Godot --headless --path . --script res://tools/import_art.gd
## 之後要再跑一次 --import 讓 Godot 匯入新的 png。
##
## 每張圖的處理：
##   1. 縮到 256（背景是平滑的漸層，先縮小讓去背更快）
##   2. 從四邊開始「淹水」去背（背景色附近、或和相鄰的背景像素很像的都算背景）
##   3. 去掉偏背景色調的陰影、只保留最大的那一塊（去掉 AI 生成的小雜點）
##   4. 裁到角色的範圍，縮到目標高度：每個輸出像素取「區塊裡最多的顏色」，保持像素畫的硬邊
##   5. 角色加 1px 深色外框，在黑暗的遊戲畫面裡比較看得清楚
## 要換圖：改 MANIFEST 裡的來源檔名，重跑這支工具。
extends SceneTree

const SRC := "res://art_raw/"
const OUT := "res://assets/sprites/"
const WORK := 256

const DIRS := ["down", "downright", "right", "upright", "up"]

## 角色：{輸出資料夾: {height, prefix, anims: {動畫: {方向: [來源（不含 _00001_.png）...]}}}}
const CHARACTERS := {
	"player": {
		"folder": "characters/shen_ruoning/", "prefix": "player_shen_",
		"anims": {
			"idle": {"height": 28, "down": ["idle_down_01", "idle_down_02"],
				"downright": ["idle_downright_01", "idle_downright_02"],
				"right": ["idle_right_01", "idle_right_02"],
				"upright": ["idle_upright_02_v3", "idle_upright_02_v3"],
				"up": ["idle_up_01_v3", "idle_up_02_v3"]},
			"walk": {"height": 28, "down": ["walk_down_01", "walk_down_02"],
				"downright": ["walk_downright_01", "walk_downright_02"],
				"right": ["walk_right_01", "walk_right_02"],
				"upright": ["walk_upright_02_v3", "walk_upright_02_v3"],
				"up": ["walk_up_01_v3", "walk_up_02_v3"]},
			"sneak": {"height": 21, "down": ["sneak_down_01", "sneak_down_02"],
				"downright": ["sneak_downright_01", "sneak_downright_02"],
				"right": ["sneak_right_01", "sneak_right_02"],
				"upright": ["sneak_upright_02_v3", "sneak_upright_02_v3"],
				"up": ["sneak_up_01_v3", "sneak_up_02_v3"]},
		},
	},
	"watcher": {
		"folder": "enemies/watcher/", "prefix": "enemy_watcher_",
		"anims": {
			"walk": {"height": 28, "down": ["walk_down_01", "walk_down_02"],
				"downright": ["walk_downright_01", "walk_downright_02"],
				"right": ["walk_right_01", "walk_right_02"],
				"upright": ["walk_upright_01_v3", "walk_upright_02_v3"],
				"up": ["walk_up_01_v3", "walk_up_02_v3"]},
		},
	},
	"listener": {
		"folder": "enemies/listener/", "prefix": "enemy_listener_",
		"anims": {
			"walk": {"height": 28, "down": ["walk_down_01"], "downright": ["walk_downright_01"],
				"right": ["walk_right_01"], "upright": ["walk_upright_01_v3"], "up": ["walk_up_01_v3"]},
			"listen": {"height": 27, "down": ["listen_down_01"], "downright": ["listen_downright_01"],
				"right": ["listen_right_01"], "upright": ["listen_upright_01_v3"], "up": ["listen_up_01_v3"]},
		},
	},
}

## 道具：[來源, 輸出名, 寬, 高]（寬或高 = 0 表示依比例）
const PROPS := [
	["props/prop_locker_closed_01", "props/locker", 0, 26],
	["props/prop_locker_open_01", "props/locker_open", 0, 26],
	["props/prop_breaker_panel_01", "props/breaker", 12, 0],
	["props/prop_filing_cabinet_01", "props/cabinet", 0, 22],
	["props/prop_lab_bench_01", "props/bench", 32, 0],
	["props/prop_bottle_floor_01", "props/bottle", 0, 10],
	["icons/icon_first_aid_small_01", "props/med", 0, 11],
	["icons/icon_antibacterial_01", "props/antibiotic", 0, 11],
]

## 地板、牆：整張縮小（不去背）。[來源, 輸出名, 尺寸, 裁切比例（0～0.5，從四邊往內）]
const TILES := [
	["tiles/tile_concrete_floor_02", "tiles/floor_concrete", 64, 0.01],
	["tiles/tile_frost_floor_02", "tiles/floor_frost", 64, 0.0],
	["tiles/tile_lab_floor_02", "tiles/floor_lab", 64, 0.05],
	["tiles/tile_wall_concrete_02", "tiles/wall_concrete", 32, 0.3],
]

## 頭像：[來源, 輸出名, 尺寸, 裁切比例]
const PORTRAITS := [
	["portraits/portrait_shen_determined_01_v2", "portraits/shen_fine", 48, 0.12],
	["portraits/portrait_shen_worried_01_v2", "portraits/shen_caution", 48, 0.12],
	["portraits/portrait_shen_exhausted_01_v2", "portraits/shen_danger", 48, 0.12],
]

var _count := 0


func _initialize() -> void:
	for char_id in CHARACTERS:
		var c: Dictionary = CHARACTERS[char_id]
		for anim in c.anims:
			var a: Dictionary = c.anims[anim]
			for dir in DIRS:
				var frames: Array = a[dir]
				for i in frames.size():
					var img := _cutout(SRC + c.folder + c.prefix + frames[i] + "_00001_.png", 0, a.height, true)
					_save(img, "%s/%s_%s_%d" % [char_id, anim, dir, i])
	for p in PROPS:
		_save(_cutout(SRC + p[0] + "_00001_.png", p[2], p[3], false), p[1])
	for t in TILES + PORTRAITS:
		_save(_whole(SRC + t[0] + "_00001_.png", t[2], t[3]), t[1])
	print("done: %d images" % _count)
	quit()


func _save(img: Image, name: String) -> void:
	if img == null:
		return
	var path := OUT + name + ".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	img.save_png(ProjectSettings.globalize_path(path))
	_count += 1


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("找不到 " + path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


# ── 去背、裁切、縮小 ─────────────────────────────────────

func _cutout(path: String, out_w: int, out_h: int, outline: bool) -> Image:
	var img := _load(path)
	if img == null:
		return null
	img.resize(WORK, WORK, Image.INTERPOLATE_BILINEAR)
	var bg := _corner_color(img)
	var mask := _flood_background(img, bg)
	_drop_shadows(img, mask, bg)
	_keep_main_blob(mask)
	var box := _bbox(mask)
	if box.size.x <= 0:
		push_error("去背後是空的：" + path)
		return null
	if out_w == 0:
		out_w = maxi(1, roundi(box.size.x * float(out_h) / box.size.y))
	if out_h == 0:
		out_h = maxi(1, roundi(box.size.y * float(out_w) / box.size.x))
	var out := _mode_downscale(img, mask, box, out_w, out_h)
	if outline:
		out = _add_outline(out)
	return out


func _whole(path: String, size: int, crop: float) -> Image:
	var img := _load(path)
	if img == null:
		return null
	img.resize(WORK, WORK, Image.INTERPOLATE_BILINEAR)
	var mask := PackedByteArray()
	mask.resize(WORK * WORK)
	mask.fill(1)
	var m := int(WORK * crop)
	return _mode_downscale(img, mask, Rect2i(m, m, WORK - 2 * m, WORK - 2 * m), size, size)


func _corner_color(img: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for corner in [Vector2i(0, 0), Vector2i(WORK - 6, 0), Vector2i(0, WORK - 6), Vector2i(WORK - 6, WORK - 6)]:
		for y in 6:
			for x in 6:
				var c := img.get_pixel(corner.x + x, corner.y + y)
				sum += c
				n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n, 1.0)


static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## 回傳 mask：1 = 角色，0 = 背景
func _flood_background(img: Image, bg: Color) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(WORK * WORK)
	mask.fill(1)
	var queue: Array[Vector2i] = []
	for i in WORK:
		for p in [Vector2i(i, 0), Vector2i(i, WORK - 1), Vector2i(0, i), Vector2i(WORK - 1, i)]:
			if mask[p.y * WORK + p.x] == 1 and _dist(img.get_pixelv(p), bg) < 0.25:
				mask[p.y * WORK + p.x] = 0
				queue.append(p)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var pc := img.get_pixelv(p)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= WORK or q.y >= WORK or mask[q.y * WORK + q.x] == 0:
				continue
			var qc := img.get_pixelv(q)
			var to_bg := _dist(qc, bg)
			if to_bg < 0.2 or (to_bg < 0.4 and _dist(qc, pc) < 0.035):
				mask[q.y * WORK + q.x] = 0
				queue.append(q)
	return mask


## 背景是洋紅色時，色調接近洋紅、又有點飽和的像素是投影：去掉
func _drop_shadows(img: Image, mask: PackedByteArray, bg: Color) -> void:
	if bg.s < 0.25:
		return
	for y in WORK:
		for x in WORK:
			if mask[y * WORK + x] == 0:
				continue
			var c := img.get_pixel(x, y)
			var dh := absf(c.h - bg.h)
			dh = minf(dh, 1.0 - dh)
			if dh < 0.06 and c.s > 0.2:
				mask[y * WORK + x] = 0


## 只保留最大的一塊（以及和它一樣大到不像雜點的塊）
func _keep_main_blob(mask: PackedByteArray) -> void:
	var label := PackedInt32Array()
	label.resize(WORK * WORK)
	label.fill(-1)
	var sizes: Array[int] = []
	for start in WORK * WORK:
		if mask[start] == 0 or label[start] != -1:
			continue
		var id := sizes.size()
		var count := 0
		var stack: Array[int] = [start]
		label[start] = id
		while not stack.is_empty():
			var i: int = stack.pop_back()
			count += 1
			var x := i % WORK
			var y := i / WORK
			for j in [i - 1 if x > 0 else -1, i + 1 if x < WORK - 1 else -1,
					i - WORK if y > 0 else -1, i + WORK if y < WORK - 1 else -1]:
				if j >= 0 and mask[j] == 1 and label[j] == -1:
					label[j] = id
					stack.append(j)
		sizes.append(count)
	if sizes.is_empty():
		return
	var biggest: int = sizes.max()
	for i in WORK * WORK:
		if mask[i] == 1 and sizes[label[i]] < biggest * 0.15:
			mask[i] = 0


func _bbox(mask: PackedByteArray) -> Rect2i:
	var lo := Vector2i(WORK, WORK)
	var hi := Vector2i(-1, -1)
	for y in WORK:
		for x in WORK:
			if mask[y * WORK + x] == 1:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## 每個輸出像素：區塊裡出現最多的顏色（量化後統計，再取那一群的平均），透明度看覆蓋率。
func _mode_downscale(img: Image, mask: PackedByteArray, box: Rect2i, out_w: int, out_h: int) -> Image:
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	var sx := float(box.size.x) / out_w
	var sy := float(box.size.y) / out_h
	for oy in out_h:
		for ox in out_w:
			var x0 := box.position.x + int(ox * sx)
			var x1 := maxi(x0 + 1, box.position.x + int((ox + 1) * sx))
			var y0 := box.position.y + int(oy * sy)
			var y1 := maxi(y0 + 1, box.position.y + int((oy + 1) * sy))
			var buckets := {}
			var total := 0
			var opaque := 0
			for y in range(y0, mini(y1, WORK)):
				for x in range(x0, mini(x1, WORK)):
					total += 1
					if mask[y * WORK + x] == 0:
						continue
					opaque += 1
					var c := img.get_pixel(x, y)
					var key := (int(c.r * 7.99) << 6) | (int(c.g * 7.99) << 3) | int(c.b * 7.99)
					if not buckets.has(key):
						buckets[key] = [0, Color(0, 0, 0, 0)]
					buckets[key][0] += 1
					buckets[key][1] += c
			if total == 0 or float(opaque) / total < 0.4:
				continue
			var best_key = null
			for k in buckets:
				if best_key == null or buckets[k][0] > buckets[best_key][0]:
					best_key = k
			var n: int = buckets[best_key][0]
			var s: Color = buckets[best_key][1]
			out.set_pixel(ox, oy, Color(s.r / n, s.g / n, s.b / n, 1.0))
	return out


## 1px 深色外框（加大畫布 2px 放外框）
func _add_outline(src: Image) -> Image:
	var w := src.get_width() + 2
	var h := src.get_height() + 2
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w - 2, h - 2), Vector2i(1, 1))
	var edge := Color(0.05, 0.05, 0.08, 1.0)
	var copy := out.duplicate()
	for y in h:
		for x in w:
			if copy.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and copy.get_pixelv(q).a > 0.5:
					out.set_pixel(x, y, edge)
					break
	return out
