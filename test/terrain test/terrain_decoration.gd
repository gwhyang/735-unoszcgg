extends RefCounted
class_name TerrainDecoration

## 装饰物生成工具类。
##
## 这个脚本只负责生成装饰物分布数据，不负责 TileMap 显示和鼠标交互。
## 当前框架把装饰物生成拆成三个阶段：
## 1. build_initial_points：用噪音和随机概率生成初始点。
## 2. spread_points：从初始点向周围扩散若干轮。
## 3. polish_grid：对整体结果做简单修饰，比如去孤点、补小洞。
##
## 返回的网格同样使用 grid[y][x] 访问：
## - EMPTY = 0 表示没有装饰物。
## - DECORATION = 1 表示有装饰物。
##
## 使用示例：
## var rule = TerrainDecoration.DecorationRule.new()
## rule.seed_noise_frequency = 0.08
## rule.seed_noise_threshold = 0.72
## rule.spread_iterations = 3
## var steps = TerrainDecoration.generate_steps(Vector2i(500, 500), rule)
## var final_grid = steps["result_grid"]

const EMPTY:int = 0
const DECORATION:int = 1

const POLISH_CELLULAR:int = 0
const POLISH_SEAGRASS_CROSS_ERODE:int = 1
const SPREAD_DIRECTIONAL:int = 0
const SPREAD_FISH:int = 1

const DIRECTIONS_4:Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

const DIRECTIONS_8:Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]


class DecorationRule:
	extends RefCounted

	## 随机种子；同一套参数和种子会得到稳定结果。
	var seed:int = 240714

	## 初始点噪音频率。越大越碎，越小越大片。
	var seed_noise_frequency:float = 0.05
	## 初始点噪音阈值。噪音值高于这个值时会生成初始点。
	var seed_noise_threshold:float = 0.72
	## 除噪音之外的随机初始点概率。
	var seed_random_chance:float = 0.003

	## 初始点向周围扩散的轮数。
	var spread_iterations:int = 3
	## 扩散模式：普通装饰物使用方向扩散，鱼使用密度扩散。
	var spread_mode:int = SPREAD_DIRECTIONAL
	## 每个已存在装饰物向一个邻居扩散的基础概率。
	var spread_chance:float = 0.35
	## 横向扩散概率。小于 0 时使用 spread_chance。
	var spread_horizontal_chance:float = -1.0
	## 纵向扩散概率。小于 0 时使用 spread_chance。
	var spread_vertical_chance:float = -1.0
	## 斜向扩散概率。小于 0 时使用 spread_chance。
	var spread_diagonal_chance:float = -1.0
	## 每轮扩散概率衰减。1 表示不衰减；小于 1 会让后续扩散越来越弱。
	var spread_decay:float = 0.85
	## true 时使用八方向扩散，false 时只使用上下左右。
	var spread_diagonal:bool = true

	## 鱼扩散概率。空格 5x5 范围内鱼数落入生成范围时，会按该概率生成鱼。
	var fish_spread_chance:float = 0.35
	## 鱼在 3x3 范围内删除自己的数量范围。支持 7-9、7~9、7,9、>=7、7+、7 等格式。
	var fish_delete_3x3_range:String = "7-9"
	## 空格在 5x5 范围内生成鱼的数量范围。默认 4-25 表示 4 个及以上。
	var fish_spawn_5x5_range:String = "4-25"
	## 鱼在 5x5 范围内删除自己的数量范围。
	var fish_delete_5x5_range:String = "15-25"

	## 修饰阶段重复次数。
	var polish_iterations:int = 1
	var polish_mode:int = POLISH_CELLULAR
	## 海草修饰的概率删除强度。只有 8 个邻居都是海草时才会按该概率删除。
	var seagrass_erode_chance:float = 0.5
	## 已存在装饰物周围少于该数量邻居时会被移除，用来去掉孤点。
	var polish_keep_min_neighbors:int = 2
	## 空格周围至少有该数量邻居时会被填上，用来补小洞。
	var polish_birth_min_neighbors:int = 5
	## 修饰阶段是否统计斜向邻居。
	var polish_diagonal:bool = true

	## 边缘留空宽度，避免装饰物生成到地图边界。
	var border_padding:int = 0
	## 可选放置遮罩。为空时表示全图都可以放。
	var placement_mask:Array = []
	## 可选允许值列表。placement_mask 不为空时，只有 mask 值在这个数组里才可放置。
	## 如果为空，则 mask 中非 0 / true 的格子都视为可放置。
	var allowed_mask_values:Array = []


## 运行完整三段式流程，只返回最终装饰物网格。
static func generate_grid(size:Vector2i, rule:DecorationRule = null) -> Array:
	return generate_steps(size, rule)["result_grid"] as Array


## 运行完整三段式流程，并返回每个阶段的数据，方便可视化脚本缓存和调试。
static func generate_steps(size:Vector2i, rule:DecorationRule = null) -> Dictionary:
	var active_rule:DecorationRule = _get_rule(rule)
	var seed_grid:Array = build_initial_points(size, active_rule)
	var spread_grid:Array = spread_points(seed_grid, active_rule)
	var result_grid:Array = polish_grid(spread_grid, active_rule)
	return {
		"seed_grid": seed_grid,
		"spread_grid": spread_grid,
		"result_grid": result_grid,
	}


## 阶段 1：用噪音和随机概率生成初始点。
static func build_initial_points(size:Vector2i, rule:DecorationRule = null) -> Array:
	var active_rule:DecorationRule = _get_rule(rule)
	var result:Array = create_empty_grid(size)
	if result.is_empty():
		return result

	var noise:FastNoiseLite = FastNoiseLite.new()
	noise.seed = active_rule.seed
	noise.frequency = _sanitize_noise_frequency(active_rule.seed_noise_frequency)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	var rng:RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = active_rule.seed + 1009

	for y:int in range(size.y):
		for x:int in range(size.x):
			var cell:Vector2i = Vector2i(x, y)
			if not _can_place_at(active_rule, size, cell):
				continue
			var noise_value:float = (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			if noise_value >= active_rule.seed_noise_threshold or rng.randf() < active_rule.seed_random_chance:
				result[y][x] = DECORATION

	return result


## 阶段 2：从已有装饰物向邻居扩散。
##
## 每一轮都基于上一轮结果扩散；同一轮中新生成的点不会立刻继续扩散。
static func spread_points(seed_grid:Array, rule:DecorationRule = null) -> Array:
	var active_rule:DecorationRule = _get_rule(rule)
	var result:Array = duplicate_grid(seed_grid)
	if result.is_empty():
		return result
	if active_rule.spread_mode == SPREAD_FISH:
		return spread_fish_points(result, active_rule)

	var size:Vector2i = get_grid_size(result)
	var directions:Array[Vector2i] = _get_directions(active_rule.spread_diagonal)
	var rng:RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = active_rule.seed + 2003

	var iteration_count:int = max(active_rule.spread_iterations, 0)
	for iteration:int in range(iteration_count):
		var next_grid:Array = duplicate_grid(result)
		var iteration_decay:float = pow(active_rule.spread_decay, iteration)

		for y:int in range(size.y):
			for x:int in range(size.x):
				if result[y][x] != DECORATION:
					continue

				var cell:Vector2i = Vector2i(x, y)
				for direction:Vector2i in directions:
					var next:Vector2i = cell + direction
					if not is_in_grid(result, next):
						continue
					if next_grid[next.y][next.x] == DECORATION:
						continue
					if not _can_place_at(active_rule, size, next):
						continue
					if rng.randf() < _get_spread_chance_for_direction(active_rule, direction, iteration_decay):
						next_grid[next.y][next.x] = DECORATION

		result = next_grid

	return result


## 鱼扩散：不按方向扩散，而是按局部密度更新整张网格。
## - 已有鱼在 3x3 或 5x5 范围内鱼数落入删除范围时会删除自己，避免过密。
## - 空格在 5x5 范围内鱼数落入生成范围时，会按 fish_spread_chance 概率生成鱼。
static func spread_fish_points(seed_grid:Array, rule:DecorationRule = null) -> Array:
	var active_rule:DecorationRule = _get_rule(rule)
	var result:Array = duplicate_grid(seed_grid)
	if result.is_empty():
		return result

	var size:Vector2i = get_grid_size(result)
	var rng:RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = active_rule.seed + 2207
	var iteration_count:int = max(active_rule.spread_iterations, 0)

	for iteration:int in range(iteration_count):
		var next_grid:Array = duplicate_grid(result)
		var spread_chance:float = clamp(active_rule.fish_spread_chance * pow(active_rule.spread_decay, iteration), 0.0, 1.0)

		for y:int in range(size.y):
			for x:int in range(size.x):
				var cell:Vector2i = Vector2i(x, y)
				if not _can_place_at(active_rule, size, cell):
					next_grid[y][x] = EMPTY
					continue

				var count_5x5:int = count_decorations_in_square(result, cell, 2, true)
				if result[y][x] == DECORATION:
					var count_3x3:int = count_decorations_in_square(result, cell, 1, true)
					if is_count_in_range(count_3x3, active_rule.fish_delete_3x3_range, 7, 9):
						next_grid[y][x] = EMPTY
					elif is_count_in_range(count_5x5, active_rule.fish_delete_5x5_range, 15, 25):
						next_grid[y][x] = EMPTY
					continue

				if is_count_in_range(count_5x5, active_rule.fish_spawn_5x5_range, 4, 25) and rng.randf() < spread_chance:
					next_grid[y][x] = DECORATION

		result = next_grid

	return result


## 阶段 3：整体修饰。
##
## 当前是一个简单的 cellular automata 规则：
## - 已有装饰物邻居太少就删除。
## - 空格邻居足够多就补上。
## 后续可以按装饰物类型替换成更具体的修饰规则。
static func polish_grid(source_grid:Array, rule:DecorationRule = null) -> Array:
	var active_rule:DecorationRule = _get_rule(rule)
	var result:Array = duplicate_grid(source_grid)
	if result.is_empty():
		return result

	if active_rule.polish_mode == POLISH_SEAGRASS_CROSS_ERODE:
		return polish_seagrass_cross_erode(result, active_rule)

	var size:Vector2i = get_grid_size(result)
	var directions:Array[Vector2i] = _get_directions(active_rule.polish_diagonal)
	var iteration_count:int = max(active_rule.polish_iterations, 0)

	for iteration:int in range(iteration_count):
		var next_grid:Array = duplicate_grid(result)

		for y:int in range(size.y):
			for x:int in range(size.x):
				var cell:Vector2i = Vector2i(x, y)
				if not _can_place_at(active_rule, size, cell):
					next_grid[y][x] = EMPTY
					continue

				var neighbor_count:int = count_decoration_neighbors(result, cell, directions)
				if result[y][x] == DECORATION:
					if neighbor_count < active_rule.polish_keep_min_neighbors:
						next_grid[y][x] = EMPTY
				elif neighbor_count >= active_rule.polish_birth_min_neighbors:
					next_grid[y][x] = DECORATION

		result = next_grid

	return result


## 海草修饰：如果某格周围 8 格都是海草，则该格可以变为空。
##
## 每次修饰迭代分成两步：
## 1. 概率腐蚀：满足 8 邻居全为海草时，按 seagrass_erode_chance 概率删除。
## 2. 确定腐蚀：在概率腐蚀后的结果上，再把 8 邻居全为海草的格子删除一次。
##
## 两步内部都使用棋盘式更新顺序：先更新 row + column 为偶数的格子，再用更新后的结果更新奇数格子。
static func polish_seagrass_cross_erode(source_grid:Array, rule:DecorationRule = null) -> Array:
	var active_rule:DecorationRule = _get_rule(rule)
	var result:Array = duplicate_grid(source_grid)
	if result.is_empty():
		return result

	var size:Vector2i = get_grid_size(result)
	var rng:RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = active_rule.seed + 3001
	var iteration_count:int = max(active_rule.polish_iterations, 0)
	for iteration:int in range(iteration_count):
		result = _polish_seagrass_cross_erode_parity(result, active_rule, size, 0, rng, true)
		result = _polish_seagrass_cross_erode_parity(result, active_rule, size, 1, rng, true)
		result = _polish_seagrass_cross_erode_parity(result, active_rule, size, 0, rng, false)
		result = _polish_seagrass_cross_erode_parity(result, active_rule, size, 1, rng, false)
	return result


static func _polish_seagrass_cross_erode_parity(
	source_grid:Array,
	rule:DecorationRule,
	size:Vector2i,
	parity:int,
	rng:RandomNumberGenerator,
	use_probability:bool
) -> Array:
	var result:Array = duplicate_grid(source_grid)
	for y:int in range(size.y):
		for x:int in range(size.x):
			if (x + y) % 2 != parity:
				continue
			var cell:Vector2i = Vector2i(x, y)
			if not _can_place_at(rule, size, cell):
				result[y][x] = EMPTY
				continue
			if source_grid[y][x] != DECORATION:
				continue
			if not _has_decoration_in_all_eight_directions(source_grid, cell):
				continue
			if use_probability and rng.randf() >= clamp(rule.seagrass_erode_chance, 0.0, 1.0):
				continue
			result[y][x] = EMPTY
	return result


static func _has_decoration_in_all_eight_directions(grid:Array, cell:Vector2i) -> bool:
	for direction:Vector2i in DIRECTIONS_8:
		var next:Vector2i = cell + direction
		if not is_in_grid(grid, next):
			return false
		if grid[next.y][next.x] != DECORATION:
			return false
	return true

## 创建空装饰物网格。
static func create_empty_grid(size:Vector2i) -> Array:
	var result:Array = []
	if size.x <= 0 or size.y <= 0:
		return result

	for y:int in range(size.y):
		var row:Array = []
		row.resize(size.x)
		for x:int in range(size.x):
			row[x] = EMPTY
		result.append(row)
	return result


## 统计某个格子周围的装饰物数量。
static func count_decoration_neighbors(grid:Array, cell:Vector2i, directions:Array[Vector2i]) -> int:
	var result:int = 0
	for direction:Vector2i in directions:
		var next:Vector2i = cell + direction
		if not is_in_grid(grid, next):
			continue
		if grid[next.y][next.x] == DECORATION:
			result += 1
	return result


## 统计某个方形范围内的装饰物数量。radius 为 1 时是 3x3，radius 为 2 时是 5x5。
static func count_decorations_in_square(grid:Array, cell:Vector2i, radius:int, include_center:bool = false) -> int:
	var result:int = 0
	var safe_radius:int = max(radius, 0)
	for y:int in range(cell.y - safe_radius, cell.y + safe_radius + 1):
		for x:int in range(cell.x - safe_radius, cell.x + safe_radius + 1):
			var current:Vector2i = Vector2i(x, y)
			if not include_center and current == cell:
				continue
			if not is_in_grid(grid, current):
				continue
			if grid[current.y][current.x] == DECORATION:
				result += 1
	return result


## 判断数量是否落入字符串范围。支持 7-9、7~9、7,9、>=7、<=9、7+、单个数字等写法。
static func is_count_in_range(value:int, range_text:String, default_min:int, default_max:int) -> bool:
	var parsed_range:Vector2i = parse_count_range(range_text, default_min, default_max)
	return value >= parsed_range.x and value <= parsed_range.y


static func parse_count_range(range_text:String, default_min:int, default_max:int) -> Vector2i:
	var text:String = range_text.strip_edges()
	if text.is_empty():
		return Vector2i(default_min, default_max)

	text = text.replace("，", ",")
	text = text.replace("～", "~")
	text = text.replace("—", "-")
	text = text.replace("–", "-")
	text = text.replace("至", "-")
	text = text.replace("到", "-")
	text = text.replace(" ", "")

	if text.begins_with(">="):
		return Vector2i(_parse_int_or_default(text.substr(2), default_min), default_max)
	if text.begins_with(">"):
		return Vector2i(_parse_int_or_default(text.substr(1), default_min) + 1, default_max)
	if text.ends_with("+"):
		return Vector2i(_parse_int_or_default(text.substr(0, text.length() - 1), default_min), default_max)
	if text.begins_with("<="):
		return Vector2i(default_min, _parse_int_or_default(text.substr(2), default_max))
	if text.begins_with("<"):
		return Vector2i(default_min, _parse_int_or_default(text.substr(1), default_max) - 1)

	for delimiter:String in ["-", "~", ",", ":", "/"]:
		if text.find(delimiter) < 0:
			continue
		var parts:PackedStringArray = text.split(delimiter, false)
		if parts.size() < 2:
			continue
		var first:int = _parse_int_or_default(parts[0], default_min)
		var second:int = _parse_int_or_default(parts[1], default_max)
		return Vector2i(min(first, second), max(first, second))

	if text.is_valid_int():
		var exact:int = int(text)
		return Vector2i(exact, exact)
	return Vector2i(default_min, default_max)


static func _parse_int_or_default(text:String, default_value:int) -> int:
	var clean_text:String = text.strip_edges()
	if clean_text.is_valid_int():
		return int(clean_text)
	return default_value


## 统计网格里的装饰物总数。
static func count_decorations(grid:Array) -> int:
	var result:int = 0
	for row:Array in grid:
		for value:int in row:
			if value == DECORATION:
				result += 1
	return result


## 把装饰物网格转成坐标数组，方便后续实例化对象或写入 TileMap。
static func get_decoration_cells(grid:Array) -> Array[Vector2i]:
	var result:Array[Vector2i] = []
	for y:int in range(grid.size()):
		for x:int in range(grid[y].size()):
			if grid[y][x] == DECORATION:
				result.append(Vector2i(x, y))
	return result


## 复制二维数组的每一行。
static func duplicate_grid(grid:Array) -> Array:
	var result:Array = []
	for row:Array in grid:
		result.append(row.duplicate())
	return result


## 获取二维 grid 的尺寸，返回 Vector2i(width, height)。
static func get_grid_size(grid:Array) -> Vector2i:
	if grid.is_empty():
		return Vector2i.ZERO
	return Vector2i(grid[0].size(), grid.size())


## 判断 cell 是否在二维 grid 范围内。
static func is_in_grid(grid:Array, cell:Vector2i) -> bool:
	if grid.is_empty():
		return false
	return cell.y >= 0 and cell.y < grid.size() and cell.x >= 0 and cell.x < grid[cell.y].size()


static func _get_rule(rule:DecorationRule) -> DecorationRule:
	if rule == null:
		return DecorationRule.new()
	return rule


static func _get_directions(include_diagonal:bool) -> Array[Vector2i]:
	if include_diagonal:
		return DIRECTIONS_8
	return DIRECTIONS_4




static func _get_spread_chance_for_direction(rule:DecorationRule, direction:Vector2i, iteration_decay:float) -> float:
	var chance:float = rule.spread_chance
	if direction.x != 0 and direction.y == 0 and rule.spread_horizontal_chance >= 0.0:
		chance = rule.spread_horizontal_chance
	elif direction.x == 0 and direction.y != 0 and rule.spread_vertical_chance >= 0.0:
		chance = rule.spread_vertical_chance
	elif direction.x != 0 and direction.y != 0 and rule.spread_diagonal_chance >= 0.0:
		chance = rule.spread_diagonal_chance
	return chance * iteration_decay

static func _can_place_at(rule:DecorationRule, size:Vector2i, cell:Vector2i) -> bool:
	if cell.x < rule.border_padding or cell.y < rule.border_padding:
		return false
	if cell.x >= size.x - rule.border_padding or cell.y >= size.y - rule.border_padding:
		return false
	if rule.placement_mask.is_empty():
		return true
	if not is_in_grid(rule.placement_mask, cell):
		return false

	var mask_value:Variant = rule.placement_mask[cell.y][cell.x]
	if not rule.allowed_mask_values.is_empty():
		return rule.allowed_mask_values.has(mask_value)
	if mask_value is bool:
		return mask_value
	if mask_value is int or mask_value is float:
		return mask_value != 0
	return mask_value != null


static func _sanitize_noise_frequency(frequency:float) -> float:
	if is_zero_approx(frequency):
		return 0.0001
	return frequency
