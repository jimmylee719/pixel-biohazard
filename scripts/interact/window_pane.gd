## 窗戶：靠過去看 = 切換成第一人稱視角往窗外看（main 的 FirstPersonView）。
## 站在窗前往窗戶推一下也會自動切換；往後退或按互動離開。
class_name WindowPane
extends Interactable

signal look(window: WindowPane, from_pos: Vector2)


func _init() -> void:
	interact_range = 22.0


func get_prompt(_player: Player) -> String:
	return "Look through the window"


func interact(player: Player) -> void:
	look.emit(self, player.global_position)


func _draw() -> void:
	pass
