extends RefCounted

## 地形距离与高度生成工具类。
##
## 这个脚本只负责“根据输入网格生成数据”，不保存任何运行状态，也不直接处理可视化或交互。
## 约定输入网格为二维 Array，访问方式是 grid[y][x]：
## - LAND = 0 表示陆地。
## - OCEAN = 1 表示海洋。
##
## 推荐生成流程：
## 1. build_distance_grid(grid)：由 0/1 地图生成每个海洋格到最近陆地的距离。
## 2. normalize_distance_grid(distance_grid)：把距离压缩到 0-1。
## 3. smooth_height_grid(normalized_grid, distance_grid, ...)：平滑距离场，让等高线更圆滑。
## 4. build_noise_grid(...) + add_noise_to_height_grid(...)：在平滑之后加入噪音扰动。
## 5. classify_terrain_grid(...)：根据阈值把高度分为浅海、过渡带、深海。
class_name TerrainDistance

## 原始输入网格中的陆地值。
const LAND:int = 0
## 原始输入网格中的海洋值。
const OCEAN:int = 1
## 没有任何陆地可达时使用的距离值。
const NO_LAND_DISTANCE:int = -1

## 分类结果：陆地。
const TERRAIN_LAND:int = 0
## 分类结果：浅海。
const TERRAIN_SHALLOW_SEA:int = 1
## 分类结果：浅海与深海之间的过渡带。
const TERRAIN_TRANSITION_SEA:int = 2
## 分类结果：深海。
const TERRAIN_DEEP_SEA:int = 3
## 分类结果：输入中没有陆地时的兜底类型。
const TERRAIN_NO_LAND:int = 4

## 四方向邻接。这里的“相邻距离为 1”只计算上下左右，不计算斜向。
const DIRECTIONS:Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


## 兼容旧调用名；等价于 build_distance_grid(grid)。
static func ocean_to_land_distance(grid:Array) -> Array:
	return build_distance_grid(grid)


## 生成距离网格。
##
## 返回值与输入 grid 尺寸一致：
## - 陆地格为 0。
## - 海洋格为到最近陆地的四方向网格距离。
## - 如果输入中没有陆地，海洋格会保持 NO_LAND_DISTANCE。
##
## 算法使用多源 BFS：所有陆地同时入队，因此第一次访问到海洋格时就是最近陆地距离。
## 时间复杂度 O(width * height)，适合 500x500 这类交互测试网格。
static func build_distance_grid(grid:Array) -> Array:
	if grid.is_empty():
		return []

	var row_count:int = grid.size()
	var column_count:int = 0
	if grid[0] is Array:
		column_count = grid[0].size()
	if column_count == 0:
		return []

	var result:Array = []
	var queue:Array[Vector2i] = []

	# 所有陆地作为 BFS 起点。海洋先标为未访问，后面由 BFS 填距离。
	for y:int in range(row_count):
		var result_row:Array = []
		for x:int in range(column_count):
			if grid[y][x] == LAND:
				result_row.append(0)
				queue.append(Vector2i(x, y))
			else:
				result_row.append(NO_LAND_DISTANCE)
		result.append(result_row)

	var queue_index:int = 0
	while queue_index < queue.size():
		var current:Vector2i = queue[queue_index]
		queue_index += 1

		# 四方向扩散。因为 BFS 按层推进，首次写入的距离就是最短距离。
		for direction:Vector2i in DIRECTIONS:
			var next:Vector2i = current + direction
			if next.x < 0 or next.x >= column_count or next.y < 0 or next.y >= row_count:
				continue
			if result[next.y][next.x] != NO_LAND_DISTANCE:
				continue

			result[next.y][next.x] = result[current.y][current.x] + 1
			queue.append(next)

	return result


## 把距离网格压缩到 0-1 区间。
##
## 压缩规则：
## - 陆地、无陆地距离和其他非正距离都记为 0.0。
## - 海洋距离使用 distance / max_distance。
##
## 这个结果通常作为后续平滑的基础高度图。越靠近陆地越接近 0，越远离陆地越接近 1。
static func normalize_distance_grid(distance_grid:Array) -> Array:
	var max_distance:int = get_max_distance(distance_grid)
	var result:Array = []
	if distance_grid.is_empty():
		return result

	var denominator:int = max(max_distance, 1)
	for y:int in range(distance_grid.size()):
		var row:Array = []
		row.resize(distance_grid[y].size())
		for x:int in range(distance_grid[y].size()):
			var distance:int = distance_grid[y][x]
			if distance <= 0:
				row[x] = 0.0
			else:
				row[x] = clamp(float(distance) / float(denominator), 0.0, 1.0)
		result.append(row)
	return result


## 生成噪音网格。
##
## scales 和 frequencies 最多读取前三层，用来叠加 3 层 simplex smooth 噪音：
## - scale 控制该层噪音强度，可以为负数；负数会产生反向扰动。
## - frequency 控制碎度，越大越碎。
## - seed 控制随机形态，同一个 seed 会得到稳定结果。
##
## 返回值不强制限制在 0-1，因为它表示“要加到高度上的扰动量”。
## 后续 add_noise_to_height_grid 会负责把最终高度夹回 0-1。
static func build_noise_grid(size:Vector2i, scales:Array, frequencies:Array, seed:int = 1337) -> Array:
	var layer_scales:Array[float] = sanitize_noise_scales(scales)
	var layer_frequencies:Array[float] = sanitize_noise_frequencies(frequencies)
	var result:Array = []
	var noises:Array[FastNoiseLite] = []

	# 每一层使用不同 seed，避免三层噪音形状完全重合。
	for i:int in range(layer_scales.size()):
		var noise:FastNoiseLite = FastNoiseLite.new()
		noise.seed = seed + i * 101
		noise.frequency = layer_frequencies[i]
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noises.append(noise)

	for y:int in range(size.y):
		var row:Array = []
		row.resize(size.x)
		for x:int in range(size.x):
			var value:float = 0.0
			for i:int in range(noises.size()):
				if is_zero_approx(layer_scales[i]):
					continue
				# FastNoiseLite 原始输出约为 -1 到 1，这里先映射到 0 到 1 再乘强度。
				var noise_value:float = (noises[i].get_noise_2d(float(x), float(y)) + 1.0) * 0.5
				value += noise_value * layer_scales[i]
			row[x] = value
		result.append(row)
	return result


## 把噪音扰动叠加到高度图上。
##
## height_grid 通常传入“平滑后的距离高度图”，noise_grid 来自 build_noise_grid。
## 陆地格保持 0.0；海洋格会执行 height + noise，并夹到 0-1。
static func add_noise_to_height_grid(height_grid:Array, distance_grid:Array, noise_grid:Array) -> Array:
	var result:Array = []
	for y:int in range(height_grid.size()):
		var row:Array = []
		row.resize(height_grid[y].size())
		for x:int in range(height_grid[y].size()):
			if distance_grid[y][x] <= 0:
				row[x] = 0.0
			else:
				row[x] = clamp(float(height_grid[y][x]) + float(noise_grid[y][x]), 0.0, 1.0)
		result.append(row)
	return result


## 对高度图做多次盒式平滑。
##
## 参数：
## - iterations：平滑重复次数，越大越柔和。
## - strength：每次向邻域平均值靠拢的程度，0 表示不变，1 表示完全使用邻域平均。
## - radius：采样半径。radius = 2 时是 5x5 卷积核。
##
## 注意：平滑只处理海洋格，陆地始终保持 0。当前项目中噪音建议在平滑之后加入。
static func smooth_height_grid(height_grid:Array, distance_grid:Array, iterations:int = 1, strength:float = 1.0, radius:int = 2) -> Array:
	if height_grid.is_empty() or distance_grid.is_empty():
		return []

	var result:Array = duplicate_grid(height_grid)
	var repeat_count:int = max(iterations, 0)
	var blend_strength:float = clamp(strength, 0.0, 1.0)
	var kernel_radius:int = max(radius, 0)
	for i:int in range(repeat_count):
		result = smooth_once(result, distance_grid, blend_strength, kernel_radius)
	return result


## 执行一次平滑。
##
## 每个海洋格会在原值和邻域平均值之间插值；陆地格固定为 0。
static func smooth_once(source_grid:Array, distance_grid:Array, strength:float, radius:int) -> Array:
	var result:Array = []
	for y:int in range(source_grid.size()):
		var row:Array = []
		row.resize(source_grid[y].size())
		for x:int in range(source_grid[y].size()):
			if distance_grid[y][x] <= 0:
				row[x] = 0.0
			else:
				var average:float = get_neighbor_average(source_grid, distance_grid, Vector2i(x, y), radius)
				row[x] = lerp(float(source_grid[y][x]), average, strength)
		result.append(row)
	return result


## 计算某个格子周围海洋格的平均高度。
##
## 采样范围是以 cell 为中心、radius 为半径的方形区域。
## 陆地格和越界格不会参与平均，避免陆地把海面高度硬拉低。
static func get_neighbor_average(source_grid:Array, distance_grid:Array, cell:Vector2i, radius:int) -> float:
	var total:float = 0.0
	var count:int = 0
	for y:int in range(cell.y - radius, cell.y + radius + 1):
		for x:int in range(cell.x - radius, cell.x + radius + 1):
			var sample_cell:Vector2i = Vector2i(x, y)
			if not is_in_grid(source_grid, sample_cell):
				continue
			if distance_grid[y][x] <= 0:
				continue
			total += source_grid[y][x]
			count += 1

	if count == 0:
		return source_grid[cell.y][cell.x]
	return total / float(count)


## 根据高度阈值生成地形分类网格。
##
## height_grid 应该是 0-1 的最终高度图，一般是平滑后再加噪音得到的 noisy_height_grid。
## shallow_threshold 表示浅海上界；deep_threshold 表示深海下界。
## 规则：
## - height < shallow_threshold：浅海。
## - shallow_threshold <= height < deep_threshold：过渡带。
## - height >= deep_threshold：深海。
##
## 阈值会被夹到 0-1。如果 shallow_threshold 大于 deep_threshold，会把 deep_threshold 提到 shallow_threshold。
static func classify_terrain_grid(distance_grid:Array, height_grid:Array, shallow_threshold:float, deep_threshold:float) -> Array:
	var result:Array = []
	var shallow:float = clamp(shallow_threshold, 0.0, 1.0)
	var deep:float = clamp(deep_threshold, 0.0, 1.0)
	if shallow > deep:
		deep = shallow

	for y:int in range(distance_grid.size()):
		var row:Array = []
		row.resize(distance_grid[y].size())
		for x:int in range(distance_grid[y].size()):
			row[x] = classify_cell(distance_grid[y][x], height_grid[y][x], shallow, deep)
		result.append(row)
	return result


## 分类单个格子。
##
## distance 决定是否是陆地或无陆地兜底；normalized_height 决定海洋类型。
static func classify_cell(distance:int, normalized_height:float, shallow_threshold:float, deep_threshold:float) -> int:
	if distance == 0:
		return TERRAIN_LAND
	if distance < 0:
		return TERRAIN_NO_LAND
	if normalized_height < shallow_threshold:
		return TERRAIN_SHALLOW_SEA
	if normalized_height < deep_threshold:
		return TERRAIN_TRANSITION_SEA
	return TERRAIN_DEEP_SEA


## 把地形分类值转成可读名称，主要用于调试显示。
static func terrain_type_to_name(terrain_type:int) -> String:
	if terrain_type == TERRAIN_LAND:
		return "Land"
	if terrain_type == TERRAIN_SHALLOW_SEA:
		return "Shallow"
	if terrain_type == TERRAIN_TRANSITION_SEA:
		return "Transition"
	if terrain_type == TERRAIN_DEEP_SEA:
		return "Deep"
	return "No land"


## 复制二维数组的每一行。
##
## GDScript 的 Array 是引用类型；这里只复制行数组，避免平滑时修改原始输入。
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


## 获取距离网格中的最大距离。
##
## 如果没有陆地，所有格子可能都是 NO_LAND_DISTANCE，返回值会保持 0。
static func get_max_distance(grid:Array) -> int:
	var result:int = 0
	for row:Array in grid:
		for distance:int in row:
			result = max(result, distance)
	return result


## 统计原始输入网格中的陆地数量。
static func count_land(grid:Array) -> int:
	var result:int = 0
	for row:Array in grid:
		for value:int in row:
			if value == LAND:
				result += 1
	return result


## 整理噪音强度数组。
##
## 目前固定输出 3 层强度。没有传入的层补 0。
## 不限制正负范围：正数增强高度，负数降低高度，0 表示禁用该层。
static func sanitize_noise_scales(scales:Array) -> Array[float]:
	var result:Array[float] = []
	for i:int in range(3):
		if i < scales.size():
			result.append(float(scales[i]))
		else:
			result.append(0.0)
	return result


## 整理噪音频率数组。
##
## 目前固定输出 3 层频率。没有传入的层补默认值 0.025。
## 频率不做范围限制，但会避免精确为 0，因为 FastNoiseLite 的 frequency 为 0 时没有实际意义。
static func sanitize_noise_frequencies(frequencies:Array) -> Array[float]:
	var result:Array[float] = []
	for i:int in range(3):
		if i < frequencies.size():
			result.append(_sanitize_noise_frequency(float(frequencies[i])))
		else:
			result.append(0.025)
	return result


## 避免传入 0 频率。
##
## 这里不是限制 UI 参数范围，而是给噪音库一个可工作的极小频率。
static func _sanitize_noise_frequency(frequency:float) -> float:
	if is_zero_approx(frequency):
		return 0.0001
	return frequency


## 判断 cell 是否在二维 grid 范围内。
static func is_in_grid(grid:Array, cell:Vector2i) -> bool:
	if grid.is_empty():
		return false
	return cell.y >= 0 and cell.y < grid.size() and cell.x >= 0 and cell.x < grid[cell.y].size()
