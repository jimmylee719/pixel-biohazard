## 地上的屍體（純裝飾）。外觀刻意做得和睡著的凍眠體幾乎一樣：
## 唯一的差別是凍眠體身上偶爾會閃一下結晶的微光（見 DebugOverlay 的 glint）。
class_name CorpseDecor
extends Node2D

## 和凍眠體睡著時的外觀一致
const COLOR := Color(0.62, 0.68, 0.74) * Color(0.4, 0.4, 0.4, 1.0)


func _draw() -> void:
	draw_rect(Rect2(-6, -3, 12, 6), COLOR)
