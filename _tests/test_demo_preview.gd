# test_demo_preview.gd
# 视觉预览演示场景（需要真实窗口）：
#   godot --path core res://plugins/life_game/_tests/test_demo_preview.tscn

extends Node

const WAIT_SECONDS := 2.0

func _ready() -> void:
	await get_tree().process_frame
	var demo = $Demo
	var ui: Control = demo.get_node("UI")
	var life: Control = demo.get_node("UI/LifeGame")
	var frame: ColorRect = demo.get_node("UI/Frame")
	print("[test_demo_preview] viewport=%s ui_size=%s ui_pos=%s life_size=%s life_pos=%s frame_rect=%s" % [
		str(get_viewport().get_visible_rect().size), str(ui.size), str(ui.position),
		str(life.size), str(life.position), str(frame.get_global_rect())])
	await get_tree().create_timer(WAIT_SECONDS).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://life_game_demo_preview.png"
	var error := image.save_png(path)
	if error == OK:
		print("[test_demo_preview] 截图已保存: ", ProjectSettings.globalize_path(path))
	else:
		push_error("[test_demo_preview] 截图保存失败: %s" % error)
	get_tree().quit(0 if error == OK else 1)
