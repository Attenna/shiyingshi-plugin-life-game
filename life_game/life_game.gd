# life_game.gd
# 可嵌入的康威生命游戏装饰组件（Control）。
#
# 用法：把整个 life_game/ 目录复制到你自己的插件，实例化 life_game.tscn，
# 在检查器里设置棋盘大小、初始状态、推演速度；用 position / size / anchors 决定它显示在哪。
#
# 设计要点：
# - 推演在独立于屏幕的 X×X 棋盘上进行，父节点裁切、移出屏幕、缩放都不影响计算；
# - 边界外恒为死细胞，不环绕；
# - 渲染是 SubViewport 链：BaseViewport 渲染生命掩码，然后按 shader_layers 的顺序
#   逐层渲染到新的 SubViewport，最后一层的 ViewportTexture 由 Output 显示。
#   每层 shader 读取 input_texture（上一层/掩码）并输出 RGBA，层数不限。
# - 本脚本不引用任何内核服务或其它插件，可安全复制到任意插件内部。

extends Control

signal generation_advanced(generation: int)
signal reset_finished

enum InitialMode {
	RANDOM,
	PRESET,
	CUSTOM,
}

# 与 initial_preset 的 @export_enum 顺序一一对应。
const PRESET_KEYS := [
	"glider",
	"blinker",
	"pulsar",
	"acorn",
	"r_pentomino",
	"gosper_glider_gun",
]

# 单帧最多补推的代数：大棋盘 + 高速度时防止无限追帧。超出部分直接丢弃（宁可慢，不累积）。
const MAX_STEPS_PER_FRAME := 4
const DEFAULT_DISPLAY_SIZE := Vector2(320.0, 320.0)

@export_group("棋盘")
## X×X 的边长（细胞数）。改这个值会重建棋盘并重新生成初始状态。
@export_range(2, 512, 1) var grid_size: int = 64:
	set(value):
		var clamped := clampi(value, 2, 512)
		if clamped == grid_size:
			return
		grid_size = clamped
		if is_node_ready():
			_rebuild()

## 每秒推演多少代；0 = 暂停。支持小数（如 0.5 = 每 2 秒一代）。
@export_range(0.0, 60.0, 0.1) var steps_per_second: float = 8.0

## 场景就绪后是否自动开始推演；false 时只显示初始状态。
@export var autostart: bool = true

@export_group("初始状态")
@export var initial_mode: InitialMode = InitialMode.RANDOM

@export_enum("滑翔机", "闪烁器", "脉冲星", "橡果", "R-五连体", "高斯帕滑翔机枪")
var initial_preset: int = 0

## initial_mode = CUSTOM 时使用。多行文本，# / 1 / * / O / X 为活细胞，其余为死细胞。
@export_multiline var custom_pattern: String = ""

@export_range(0.0, 1.0, 0.01) var random_density: float = 0.28
## 0 = 每次重置都随机；非 0 = 可复现的固定随机种子。
@export var random_seed: int = 0

@export_group("Shader 层")
## 从内到外的后处理链。每层一个独立 ShaderMaterial；shader 读取 input_texture 并输出 RGBA。
## 数组顺序 = 应用顺序；默认两层（细胞调色板 → 泛光）。改完数组后调用 rebuild_layers()。
@export var shader_layers: Array[ShaderMaterial] = []

var _board = null
var _board_script: Script = null
var _base_viewport: SubViewport = null
var _mask: TextureRect = null
var _output: TextureRect = null
var _layer_viewports: Array[SubViewport] = []
var _layer_rects: Array[ColorRect] = []
var _layer_materials: Array[ShaderMaterial] = []
var _image: Image = null
var _texture: ImageTexture = null
var _accumulator: float = 0.0
var _paused: bool = false
var _last_emitted_generation: int = -1


func _ready() -> void:
	_base_viewport = get_node_or_null("%BaseViewport") as SubViewport
	_mask = get_node_or_null("%Mask") as TextureRect
	_output = get_node_or_null("%Output") as TextureRect
	if _base_viewport == null or _mask == null or _output == null:
		push_error("[LifeGame] 缺少 BaseViewport / Mask / Output 节点，组件未初始化。")
		set_process(false)
		return

	_board_script = load(_script_dir().path_join("life_board.gd"))
	if _board_script == null:
		push_error("[LifeGame] 无法加载 life_board.gd，组件未初始化。")
		set_process(false)
		return

	_board = _board_script.new(grid_size)
	if size == Vector2.ZERO:
		size = DEFAULT_DISPLAY_SIZE
	resized.connect(_sync_layout)
	_sync_layout()

	_create_texture()
	rebuild_layers()
	reset()
	_paused = not autostart
	set_process(true)


func _process(delta: float) -> void:
	if _paused or _board == null or steps_per_second <= 0.0:
		return

	var interval := 1.0 / steps_per_second
	_accumulator += delta
	var steps := 0
	while _accumulator >= interval and steps < MAX_STEPS_PER_FRAME:
		_board.step()
		_accumulator -= interval
		steps += 1

	if steps == 0:
		return
	if _accumulator >= interval:
		# 达到单帧上限仍未追平：丢弃积压，避免下一帧继续堆积。
		_accumulator = fmod(_accumulator, interval)
	_publish()


# ── 对外 API ─────────────────────────────────────────────────────────────────

## 按当前配置重建初始状态并归零代数；不会改变暂停状态。
func reset() -> void:
	if _board == null:
		return
	var mode := initial_mode
	var preset_key := str(PRESET_KEYS[clampi(initial_preset, 0, PRESET_KEYS.size() - 1)])
	var custom := custom_pattern
	if mode == InitialMode.CUSTOM and custom.strip_edges().is_empty():
		push_warning("[LifeGame] 自定义初始状态为空，回退为滑翔机。")
		mode = InitialMode.PRESET
		preset_key = "glider"

	_board.reset(mode, preset_key, custom, random_density, random_seed)
	_accumulator = 0.0
	_last_emitted_generation = -1
	_publish()
	reset_finished.emit()


## 按当前 shader_layers 重建 SubViewport 链；改层/参数可在暂停时调用。
func rebuild_layers() -> void:
	for viewport in _layer_viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()
	_layer_viewports.clear()
	_layer_rects.clear()
	_layer_materials.clear()
	if _base_viewport == null or _output == null:
		return

	var viewport_size := _viewport_size()
	_base_viewport.size = viewport_size
	_mask.position = Vector2.ZERO
	_mask.size = Vector2(viewport_size)

	var previous_texture: Texture2D = _base_viewport.get_texture()
	for i in shader_layers.size():
		var source_material := shader_layers[i]
		if source_material == null or source_material.shader == null:
			continue
		var material := source_material.duplicate() as ShaderMaterial
		var viewport := SubViewport.new()
		viewport.name = "Layer%d" % i
		viewport.transparent_bg = true
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)

		var rect := ColorRect.new()
		rect.name = "Surface"
		rect.color = Color.WHITE
		rect.position = Vector2.ZERO
		rect.size = Vector2(viewport_size)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = material
		viewport.add_child(rect)

		material.set_shader_parameter("input_texture", previous_texture)
		_layer_viewports.append(viewport)
		_layer_rects.append(rect)
		_layer_materials.append(material)
		previous_texture = viewport.get_texture()

	_output.texture = previous_texture
	_update_shader_params()


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false
	_accumulator = 0.0


func set_paused(value: bool) -> void:
	if value:
		pause()
	else:
		resume()


func is_paused() -> bool:
	return _paused


## 手动推演一代（即使处于暂停状态）。
func step_once() -> void:
	if _board == null:
		return
	_board.step()
	_publish()


func get_generation() -> int:
	return _board.generation if _board != null else 0


func get_grid_size() -> int:
	return grid_size


func get_cell(x: int, y: int) -> bool:
	return _board.is_alive(x, y) if _board != null else false


## 暂停时手动画图用；批量改完细胞后调用 refresh() 刷新纹理。
func set_cell(x: int, y: int, alive: bool) -> void:
	if _board != null:
		_board.set_cell(x, y, alive)


## 把当前棋盘重新上传为显示纹理（不推演、不改变代数）。
func refresh() -> void:
	_publish()


## 取得运行时复制出来的某层材质（改完参数后下一帧生效）。
func get_layer_material(index: int) -> ShaderMaterial:
	if index < 0 or index >= _layer_materials.size():
		return null
	return _layer_materials[index]


# ── 内部 ─────────────────────────────────────────────────────────────────────

func _script_dir() -> String:
	var script_object = get_script()
	var script_path: String = script_object.resource_path
	return script_path.get_base_dir()


func _rebuild() -> void:
	if _board == null:
		return
	_board.resize(grid_size)
	_create_texture()
	_accumulator = 0.0
	reset()


func _viewport_size() -> Vector2i:
	var target := size
	if target.x < 1.0 or target.y < 1.0:
		target = DEFAULT_DISPLAY_SIZE
	return Vector2i(maxi(1, int(round(target.x))), maxi(1, int(round(target.y))))


func _sync_layout() -> void:
	if _base_viewport == null or _mask == null:
		return
	var viewport_size := _viewport_size()
	_base_viewport.size = viewport_size
	_mask.position = Vector2.ZERO
	_mask.size = Vector2(viewport_size)
	for viewport in _layer_viewports:
		if is_instance_valid(viewport):
			viewport.size = viewport_size
	for rect in _layer_rects:
		if is_instance_valid(rect):
			rect.position = Vector2.ZERO
			rect.size = Vector2(viewport_size)
	_update_shader_params()


func _create_texture() -> void:
	_image = Image.create_from_data(grid_size, grid_size, false, Image.FORMAT_RGBA8, _board.get_display_bytes())
	_texture = ImageTexture.create_from_image(_image)
	if _mask != null:
		_mask.texture = _texture


func _publish() -> void:
	if _board == null or _image == null or _texture == null:
		return
	_image.set_data(grid_size, grid_size, false, Image.FORMAT_RGBA8, _board.get_display_bytes())
	_texture.update(_image)
	_update_shader_params()

	var current: int = _board.generation
	if current != _last_emitted_generation:
		_last_emitted_generation = current
		generation_advanced.emit(current)


func _update_shader_params() -> void:
	var grid_size_vec := Vector2(float(grid_size), float(grid_size))
	var generation_value := float(_board.generation) if _board != null else 0.0
	var display_size := Vector2(_viewport_size())
	for material in _layer_materials:
		if material != null:
			material.set_shader_parameter("grid_size", grid_size_vec)
			material.set_shader_parameter("generation", generation_value)
			material.set_shader_parameter("display_size", display_size)
