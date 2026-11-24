## 視線判定工具：兩點之間有沒有被牆壁擋住。
class_name Sight
extends RefCounted

const WALL_MASK := 1


static func is_clear(node: Node2D, from: Vector2, to: Vector2) -> bool:
	var space := node.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	return space.intersect_ray(query).is_empty()


## 從 from 往 to 射線，回傳第一個碰到牆的點；沒碰到就回傳 to。
static func cast(node: Node2D, from: Vector2, to: Vector2) -> Vector2:
	var space := node.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() else to


## point 是否在以 origin 為頂點、朝 facing 方向、半角 half_angle（弧度）、長度 range 的扇形內。
static func in_cone(origin: Vector2, facing: Vector2, point: Vector2, half_angle: float, length: float) -> bool:
	var to_point := point - origin
	if to_point.length() > length:
		return false
	return absf(facing.angle_to(to_point)) <= half_angle
