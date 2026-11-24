## 全域聲音事件。任何會發出聲音的行為都呼叫 emit_noise()，
## 敵人透過 noise_emitted 訊號「聽到」。
extends Node

signal noise_emitted(position: Vector2, radius: float, source: Node)


func emit_noise(position: Vector2, radius: float, source: Node = null) -> void:
	noise_emitted.emit(position, radius, source)
