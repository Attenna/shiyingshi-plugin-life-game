# test_life_game_component.gd
# 组件生命周期测试（无头）：
#   godot --headless --path core res://plugins/life_game/_tests/test_life_game_component.tscn
# 验证初始化、暂停/单步、手动改细胞、改棋盘大小、重建 shader 链。

extends Node

var _failures: int = 0
var _checks: int = 0
@onready var _life: Control = $LifeGame


func _ready() -> void:
	await get_tree().process_frame
	if _life == null:
		push_error("[test_life_game_component] 组件未实例化")
		get_tree().quit(1)
		return

	_check(_life.get_grid_size() == 64, "默认棋盘应为 64")
	_check(_life.get_generation() == 0, "autostart=false 时初始代数为 0")
	_check(_life.get_layer_material(0) != null, "第一层材质应已创建")

	_life.step_once()
	_check(_life.get_generation() == 1, "step_once 后应到第 1 代")

	_life.set_cell(1, 1, true)
	_life.refresh()
	_check(_life.get_cell(1, 1), "set_cell + refresh 后应能读到活细胞")

	_life.grid_size = 32
	await get_tree().process_frame
	_check(_life.get_grid_size() == 32, "改 grid_size 后应为 32")
	_check(_life.get_generation() == 0, "改 grid_size 后代数应归零")

	_life.rebuild_layers()
	await get_tree().process_frame
	_check(_life.get_layer_material(0) != null, "rebuild_layers 后第一层材质应存在")

	if _failures == 0:
		print("[test_life_game_component] 全部通过（%d 项断言）" % _checks)
		get_tree().quit(0)
	else:
		push_error("[test_life_game_component] 失败 %d 项 / 共 %d 项断言" % [_failures, _checks])
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL: ", message)
