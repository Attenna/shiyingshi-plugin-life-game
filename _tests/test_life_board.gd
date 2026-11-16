# test_life_board.gd
# 生命游戏纯逻辑测试：不依赖渲染，可在无头模式下运行。
#
# 运行（把插件放进 core 的 plugins/life_game 后）：
#   godot --headless --path core res://plugins/life_game/_tests/test_life_board.tscn

extends Node

var _failures: int = 0
var _checks: int = 0
var _board_script: Script = null


func _ready() -> void:
	_board_script = load(_script_dir().path_join("../life_game/life_board.gd"))
	if _board_script == null:
		push_error("[test_life_board] 无法加载 life_board.gd")
		get_tree().quit(1)
		return

	_test_block()
	_test_blinker()
	_test_glider()
	_test_boundary()
	_test_far_from_origin()
	_test_pattern_parse()
	_test_random()
	_test_reset_modes()
	_test_resize()

	if _failures == 0:
		print("[test_life_board] 全部通过（%d 项断言）" % _checks)
		get_tree().quit(0)
	else:
		push_error("[test_life_board] 失败 %d 项 / 共 %d 项断言" % [_failures, _checks])
		get_tree().quit(1)


func _new_board(n: int):
	return _board_script.new(n)


func _script_dir() -> String:
	var script_object = get_script()
	var script_path: String = script_object.resource_path
	return script_path.get_base_dir()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL: ", message)


func _alive_set(board) -> Dictionary:
	var result := {}
	for y in board.size:
		for x in board.size:
			if board.is_alive(x, y):
				result[Vector2i(x, y)] = true
	return result


func _check_cells(board, expected: Array, label: String) -> void:
	var alive := _alive_set(board)
	_check(alive.size() == expected.size(), "%s：活细胞数量 %d，期望 %d" % [label, alive.size(), expected.size()])
	for cell in expected:
		_check(alive.has(cell), "%s：缺少活细胞 %s" % [label, cell])


# ── 规则 ─────────────────────────────────────────────────────────────────────

func _test_block() -> void:
	var b = _new_board(6)
	b.set_cell(2, 2, true)
	b.set_cell(3, 2, true)
	b.set_cell(2, 3, true)
	b.set_cell(3, 3, true)
	b.step()
	_check_cells(b, [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)], "方块静物")
	_check(b.generation == 1, "方块静物：代数应为 1")


func _test_blinker() -> void:
	var b = _new_board(5)
	b.set_cell(1, 2, true)
	b.set_cell(2, 2, true)
	b.set_cell(3, 2, true)
	b.step()
	_check_cells(b, [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)], "闪烁器第 1 代")
	b.step()
	_check_cells(b, [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)], "闪烁器第 2 代")


func _test_glider() -> void:
	var b = _new_board(10)
	b.apply_pattern([".#.", "..#", "###"])
	var before := _alive_set(b)
	_check(before.size() == 5, "滑翔机：初始应为 5 个活细胞")
	for _i in 4:
		b.step()
	_check(b.count_alive() == 5, "滑翔机：4 代后仍为 5 个活细胞")
	for cell in before.keys():
		var moved: Vector2i = cell + Vector2i(1, 1)
		_check(b.is_alive(moved.x, moved.y), "滑翔机：4 代后应移动到 %s" % moved)


# ── 边界与屏幕独立性 ─────────────────────────────────────────────────────────

func _test_boundary() -> void:
	var b = _new_board(3)
	b.set_cell(0, 0, true)
	b.step()
	_check(b.count_alive() == 0, "3×3 角落单细胞：边界外为死细胞，应死亡")
	_check(not b.is_alive(-1, 0), "负坐标应视为死细胞")
	_check(not b.is_alive(3, 0), "越界坐标应视为死细胞")

	var corner_block = _new_board(2)
	corner_block.set_cell(0, 0, true)
	corner_block.set_cell(1, 0, true)
	corner_block.set_cell(0, 1, true)
	corner_block.set_cell(1, 1, true)
	corner_block.step()
	_check(corner_block.count_alive() == 4, "2×2 角落方块：不环绕，应保持 4 个活细胞")


func _test_far_from_origin() -> void:
	# 第 51 列附近的闪烁器：屏幕/原点附近什么都看不到，但整张棋盘照常推演。
	var b = _new_board(64)
	b.set_cell(50, 40, true)
	b.set_cell(51, 40, true)
	b.set_cell(52, 40, true)
	b.step()
	_check_cells(b, [Vector2i(51, 39), Vector2i(51, 40), Vector2i(51, 41)], "远离原点的闪烁器")


# ── 初始状态 ─────────────────────────────────────────────────────────────────

func _test_pattern_parse() -> void:
	var b = _new_board(5)
	var rows: Array = b.parse_pattern("  #\n  ###\n")
	b.apply_pattern(rows)
	_check_cells(b, [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)], "自定义图案居中 + 共同缩进")


func _test_random() -> void:
	var b = _new_board(16)
	b.randomize_cells(0.0, 123)
	_check(b.count_alive() == 0, "密度 0：应全死")
	b.randomize_cells(1.0, 123)
	_check(b.count_alive() == 256, "密度 1：应全活")

	b.randomize_cells(0.35, 42)
	var signature := _signature(b)
	b.randomize_cells(0.35, 42)
	_check(_signature(b) == signature, "固定随机种子：两次结果应一致")


func _test_reset_modes() -> void:
	var b = _new_board(32)
	b.reset(b.MODE_PRESET, "glider", "", 0.3, 0)
	_check(b.count_alive() == 5, "reset 预设：滑翔机 5 个活细胞")
	b.reset(b.MODE_CUSTOM, "glider", "##\n##", 0.3, 0)
	_check(b.count_alive() == 4, "reset 自定义：2×2 方块 4 个活细胞")
	b.reset(b.MODE_RANDOM, "glider", "", 1.0, 0)
	_check(b.count_alive() == 32 * 32, "reset 随机：密度 1 应全活")

	for key in b.PRESETS:
		b.reset(b.MODE_PRESET, key, "", 0.3, 0)
		_check(b.count_alive() > 0, "预设图案 %s 应至少有一个活细胞" % key)


func _test_resize() -> void:
	var b = _new_board(8)
	b.set_cell(1, 1, true)
	b.step()
	b.resize(7)
	_check(b.size == 7, "resize：尺寸应为 7")
	_check(b.generation == 0, "resize：代数应归零")
	_check(b.count_alive() == 0, "resize：细胞应清空")


func _signature(board) -> String:
	var parts := PackedStringArray()
	for y in board.size:
		for x in board.size:
			parts.append("1" if board.is_alive(x, y) else "0")
	return "".join(parts)
