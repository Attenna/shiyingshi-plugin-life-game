# life_board.gd
# 纯逻辑的康威生命游戏棋盘：不依赖场景树、渲染或内核服务。
#
# 规则与边界：
# - X×X 格点，X = size；四周之外一律视为死细胞（不环绕、不无限扩张）。
# - 只负责推演与提供 RGBA8 的显示字节；屏幕坐标、缩放、shader 由 life_game.gd 处理。
# - 因此组件被父节点裁切、移出屏幕或缩小显示时，整张 X×X 棋盘仍然照常推演。
#
# 本脚本由 life_game.gd 以自身目录为基准 load，不使用 class_name：
# 复制到多个插件时不会产生全局类名冲突。

extends RefCounted

const ALIVE := 1
const DEAD := 0

const MODE_RANDOM := 0
const MODE_PRESET := 1
const MODE_CUSTOM := 2

# 内置初始图案。字符约定：# / 1 / * / O / X 为活细胞，其余（含 . 与空格）为死细胞。
# 图案会居中放置；超过棋盘的部分被裁掉。
const PRESETS := {
	"glider": [
		".#.",
		"..#",
		"###",
	],
	"blinker": [
		"###",
	],
	"pulsar": [
		"..###...###..",
		".............",
		"#....#.#....#",
		"#....#.#....#",
		"#....#.#....#",
		"..###...###..",
		".............",
		"..###...###..",
		"#....#.#....#",
		"#....#.#....#",
		"#....#.#....#",
		".............",
		"..###...###..",
	],
	"acorn": [
		".#.....",
		"...#...",
		"##..###",
	],
	"r_pentomino": [
		".##",
		"##.",
		".#.",
	],
	"gosper_glider_gun": [
		"........................#...........",
		"......................#.#...........",
		"............##......##............##",
		"...........#...#....##............##",
		"##........#.....#...##..............",
		"##........#...#.##....#.#...........",
		"..........#.....#.......#...........",
		"...........#...#....................",
		"............##......................",
	],
}

var size: int = 64
var generation: int = 0

var _cells: PackedByteArray
var _next: PackedByteArray
var _pixels: PackedByteArray


func _init(grid_size: int = 64) -> void:
	resize(grid_size)


## 重建为新的 X×X 棋盘；所有细胞清空，代数归零。
func resize(grid_size: int) -> void:
	size = maxi(2, grid_size)
	_cells = PackedByteArray()
	_cells.resize(size * size)
	_next = PackedByteArray()
	_next.resize(size * size)
	_pixels = PackedByteArray()
	_pixels.resize(size * size * 4)
	_cells.fill(DEAD)
	_next.fill(DEAD)
	_pixels.fill(0)
	generation = 0


func clear() -> void:
	_cells.fill(DEAD)
	_next.fill(DEAD)
	_pixels.fill(0)
	generation = 0


## 统一入口：mode 使用 MODE_RANDOM / MODE_PRESET / MODE_CUSTOM。
## random_seed 为 0 时每次随机；非 0 时结果可复现。
func reset(mode: int, preset_key: String = "glider", custom_text: String = "",
		density: float = 0.28, random_seed: int = 0) -> void:
	clear()
	match mode:
		MODE_RANDOM:
			randomize_cells(density, random_seed)
		MODE_PRESET:
			var rows: Array = PRESETS.get(preset_key, PRESETS["glider"])
			apply_pattern(rows)
		MODE_CUSTOM:
			apply_pattern(parse_pattern(custom_text))
		_:
			randomize_cells(density, random_seed)


func randomize_cells(density: float = 0.28, seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var d := clampf(density, 0.0, 1.0)
	for i in _cells.size():
		var alive := rng.randf() < d
		_cells[i] = ALIVE if alive else DEAD
		var p := i * 4
		var value := 255 if alive else 0
		_pixels[p] = value
		_pixels[p + 1] = value
		_pixels[p + 2] = value
		_pixels[p + 3] = value
	generation = 0


## 把多行文本解析为图案行。会去掉首尾空行和共同缩进，方便在检查器里粘贴缩进文本。
func parse_pattern(text: String) -> Array:
	var rows: Array = []
	if text.is_empty():
		return rows
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n")
	for line in normalized.split("\n", true):
		rows.append(line)

	while not rows.is_empty() and str(rows[0]).strip_edges().is_empty():
		rows.pop_front()
	while not rows.is_empty() and str(rows[rows.size() - 1]).strip_edges().is_empty():
		rows.pop_back()

	var min_indent := 0x7fffffff
	for line in rows:
		var raw := str(line)
		if raw.strip_edges().is_empty():
			continue
		var indent := 0
		while indent < raw.length() and (raw.unicode_at(indent) == 32 or raw.unicode_at(indent) == 9):
			indent += 1
		min_indent = mini(min_indent, indent)
	if min_indent > 0 and min_indent < 0x7fffffff:
		for i in rows.size():
			rows[i] = str(rows[i]).substr(min_indent)
	return rows


## 将图案行居中放入棋盘；超出边界的部分裁掉。
func apply_pattern(rows: Array) -> void:
	if rows.is_empty():
		return
	var pattern_height := rows.size()
	var pattern_width := 0
	for line in rows:
		pattern_width = maxi(pattern_width, str(line).length())
	var origin_x := (size - pattern_width) / 2
	var origin_y := (size - pattern_height) / 2

	for y in pattern_height:
		var line := str(rows[y])
		for x in line.length():
			if not _is_alive_char(line.unicode_at(x)):
				continue
			var grid_x := origin_x + x
			var grid_y := origin_y + y
			if grid_x < 0 or grid_y < 0 or grid_x >= size or grid_y >= size:
				continue
			_cells[grid_y * size + grid_x] = ALIVE
			var p := (grid_y * size + grid_x) * 4
			_pixels[p] = 255
			_pixels[p + 1] = 255
			_pixels[p + 2] = 255
			_pixels[p + 3] = 255
	generation = 0


## 推演一代。边界外恒为死细胞；整张 X×X 棋盘全部参与计算。
func step() -> void:
	var n := size
	var src := _cells
	var dst := _next
	var pixels := _pixels

	for y in n:
		var row := y * n
		var above := row - n
		var below := row + n
		var has_above := y > 0
		var has_below := y < n - 1
		for x in n:
			var count := 0
			if has_above:
				if x > 0:
					count += src[above + x - 1]
				count += src[above + x]
				if x < n - 1:
					count += src[above + x + 1]
			if x > 0:
				count += src[row + x - 1]
			if x < n - 1:
				count += src[row + x + 1]
			if has_below:
				if x > 0:
					count += src[below + x - 1]
				count += src[below + x]
				if x < n - 1:
					count += src[below + x + 1]

			var alive := src[row + x] == ALIVE
			var next_alive := count == 3 or (alive and count == 2)
			dst[row + x] = ALIVE if next_alive else DEAD
			var p := (row + x) * 4
			if next_alive:
				pixels[p] = 255
				pixels[p + 1] = 255
				pixels[p + 2] = 255
				pixels[p + 3] = 255
			else:
				pixels[p] = 0
				pixels[p + 1] = 0
				pixels[p + 2] = 0
				pixels[p + 3] = 0

	_cells = dst
	_next = src
	generation += 1


func is_alive(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	return _cells[y * size + x] == ALIVE


## 供外部（如暂停时手动画图）设置单个细胞；调用后需 refresh 才会刷新显示。
func set_cell(x: int, y: int, alive: bool) -> void:
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	var index := y * size + x
	_cells[index] = ALIVE if alive else DEAD
	var p := index * 4
	var value := 255 if alive else 0
	_pixels[p] = value
	_pixels[p + 1] = value
	_pixels[p + 2] = value
	_pixels[p + 3] = value


func count_alive() -> int:
	var total := 0
	for cell in _cells:
		total += cell
	return total


## 0/255 的 RGBA8 显示字节：白色不透明 = 活，透明 = 死。长度 = size*size*4。
## 用 RGBA8（而不是无 alpha 的 L8）是为了让 shader 直接用 alpha 区分死活。
## 外部只读，不要修改。
func get_display_bytes() -> PackedByteArray:
	return _pixels


func _is_alive_char(code: int) -> bool:
	# # 1 * O o X x
	return code == 35 or code == 49 or code == 42 or code == 79 or code == 111 or code == 88 or code == 120
