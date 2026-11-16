# plugin.gd
# 插件：生命游戏（life_game）。
#
# 本插件的核心不是直播场景，而是可复制到其它插件的装饰组件：
#   life_game/life_game.tscn   （组件场景）
#   life_game/life_game.gd     （推演 + 纹理 + 着色器链驱动）
#   life_game/life_board.gd    （纯逻辑棋盘，可单独测试）
#   life_game/shaders/         （默认两层 shader）
#
# scenes/life_game_demo.tscn 只是一个可切换的演示场景，用来验证组件。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "life_game"
	metadata.name = "生命游戏"
	metadata.description = "可嵌入的康威生命游戏装饰组件（X×X 格点、可调速度、多层 shader）"
	return metadata


func on_enable() -> void:
	print("[life_game] 已启用；演示场景 id: life_game_demo；组件模板: life_game/life_game.tscn")
