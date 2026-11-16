# test_small_preview.gd
# 多实例 / 小尺寸视觉预览（需要真实窗口）：
#   godot --path core res://plugins/life_game/_tests/test_small_preview.tscn

extends Control

const WAIT_SECONDS := 2.0

func _ready() -> void:
	await get_tree().create_timer(WAIT_SECONDS).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://life_game_small_preview.png"
	var error := image.save_png(path)
	if error == OK:
		print("[test_small_preview] 截图已保存: ", ProjectSettings.globalize_path(path))
	else:
		push_error("[test_small_preview] 截图保存失败: %s" % error)
	get_tree().quit(0 if error == OK else 1)
