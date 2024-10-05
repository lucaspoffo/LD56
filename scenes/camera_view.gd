@tool
class_name CameraView extends Node2D

@export var rect: Rect2i = Rect2i(0, 0, 320, 240)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(rect, Color.RED, false, 2)
