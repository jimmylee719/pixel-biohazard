## 地上的屍體（純裝飾）。外觀刻意做得和睡著的凍眠體幾乎一樣：
## 唯一的差別是凍眠體身上偶爾會閃一下結晶的微光（見 DebugOverlay 的 glint）。
## 有像素圖時用和凍眠體一樣的圖、一樣躺平、一樣的顏色。
class_name CorpseDecor
extends Node2D

## 和凍眠體睡著時的外觀一致（色塊版）
const COLOR := Color(0.62, 0.68, 0.74) * Color(0.4, 0.4, 0.4, 1.0)
## 和 enemy_sleeper.tscn 的 sprite_tint、Enemy._update_sprite 的睡著變暗一致
const SPRITE_SHADE := Color(0.62, 0.78, 0.92, 1)


func _ready() -> void:
	var tex := Art.tex("watcher/walk_down_0")
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.rotation = PI * 0.5
	s.modulate = SPRITE_SHADE.darkened(0.35)
	add_child(s)


func _draw() -> void:
	if Art.tex("watcher/walk_down_0") == null:
		draw_rect(Rect2(-6, -3, 12, 6), COLOR)
