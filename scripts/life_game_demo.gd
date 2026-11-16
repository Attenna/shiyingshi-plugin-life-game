# life_game_demo.gd
# 演示直播场景：把可嵌入的生命游戏组件放大到 1080×1080 居中显示。
# 真正的复用入口是 life_game/life_game.tscn，而不是这个演示场景。

extends PluginScene

const PRESET_NAMES := ["滑翔机", "闪烁器", "脉冲星", "橡果", "R-五连体", "高斯帕滑翔机枪"]

@onready var _life: Control = $UI/LifeGame
@onready var _info: Label = $UI/Info


func _on_scene_enter() -> void:
	print("[LifeGameDemo] 生命游戏演示场景进入（plugin=%s scene=%s）" % [plugin_id, scene_id])
	if _life == null:
		return
	var side: int = _life.get_grid_size()
	var mode := "随机 %d%%" % roundi(_life.random_density * 100.0)
	if _life.initial_mode == 1:
		mode = "预设：" + PRESET_NAMES[clampi(_life.initial_preset, 0, PRESET_NAMES.size() - 1)]
	elif _life.initial_mode == 2:
		mode = "自定义图案"
	_info.text = "死边界 · 棋盘 %d×%d · %.1f 代/秒 · %s" % [side, side, _life.steps_per_second, mode]
