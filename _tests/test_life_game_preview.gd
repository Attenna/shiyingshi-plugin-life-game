# test_life_game_preview.gd
# 视觉预览（需要真实窗口，不能 --headless）：
#   godot --path core res://plugins/life_game/_tests/test_life_game_preview.tscn
# 2 秒后把画面保存到 user://life_game_preview.png，并打印绝对路径。

extends Control

const WAIT_SECONDS := 2.0

func _ready() -> void:
	var life = $LifeGame
	var alive := 0
	for y in life.get_grid_size():
		for x in life.get_grid_size():
			if life.get_cell(x, y):
				alive += 1
	print("[test_life_game_preview] grid=%d gen=%d alive=%d speed=%s paused=%s processing=%s" % [
		life.get_grid_size(), life.get_generation(), alive,
		str(life.steps_per_second), str(life.is_paused()), str(life.is_processing())])
	await get_tree().create_timer(WAIT_SECONDS).timeout
	print("[test_life_game_preview] after wait gen=%d alive_now=%s" % [life.get_generation(), str(life.get_cell(48, 48))])
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://life_game_preview.png"
	var error := image.save_png(path)
	if error == OK:
		print("[test_life_game_preview] 截图已保存: ", ProjectSettings.globalize_path(path))
	else:
		push_error("[test_life_game_preview] 截图保存失败: %s" % error)
	get_tree().quit(0 if error == OK else 1)
