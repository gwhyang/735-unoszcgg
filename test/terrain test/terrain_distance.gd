extends RefCounted
class_name TerrainDistance

const LAND:int = 0
const OCEAN:int = 1
const NO_LAND_DISTANCE:int = -1

const TERRAIN_LAND:int = 0
const TERRAIN_SHALLOW_SEA:int = 1
const TERRAIN_TRANSITION_SEA:int = 2
const TERRAIN_DEEP_SEA:int = 3
const TERRAIN_NO_LAND:int = 4

const DIRECTIONS:Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


static func ocean_to_land_distance(grid:Array) -> Array:
	return build_distance_grid(grid)


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

		for direction:Vector2i in DIRECTIONS:
			var next:Vector2i = current + direction
			if next.x < 0 or next.x >= column_count or next.y < 0 or next.y >= row_count:
				continue
			if result[next.y][next.x] != NO_LAND_DISTANCE:
				continue

			result[next.y][next.x] = result[current.y][current.x] + 1
			queue.append(next)

	return result


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


static func build_noise_grid(size:Vector2i, scales:Array, frequencies:Array, seed:int = 1337) -> Array:
	var layer_scales:Array[float] = sanitize_noise_scales(scales)
	var layer_frequencies:Array[float] = sanitize_noise_frequencies(frequencies)
	var result:Array = []
	var noises:Array[FastNoiseLite] = []

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
				var noise_value:float = (noises[i].get_noise_2d(float(x), float(y)) + 1.0) * 0.5
				value += noise_value * layer_scales[i]
			row[x] = value
		result.append(row)
	return result


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


static func duplicate_grid(grid:Array) -> Array:
	var result:Array = []
	for row:Array in grid:
		result.append(row.duplicate())
	return result


static func get_grid_size(grid:Array) -> Vector2i:
	if grid.is_empty():
		return Vector2i.ZERO
	return Vector2i(grid[0].size(), grid.size())


static func get_max_distance(grid:Array) -> int:
	var result:int = 0
	for row:Array in grid:
		for distance:int in row:
			result = max(result, distance)
	return result


static func count_land(grid:Array) -> int:
	var result:int = 0
	for row:Array in grid:
		for value:int in row:
			if value == LAND:
				result += 1
	return result


static func sanitize_noise_scales(scales:Array) -> Array[float]:
	var result:Array[float] = []
	for i:int in range(3):
		if i < scales.size():
			result.append(float(scales[i]))
		else:
			result.append(0.0)
	return result


static func sanitize_noise_frequencies(frequencies:Array) -> Array[float]:
	var result:Array[float] = []
	for i:int in range(3):
		if i < frequencies.size():
			result.append(_sanitize_noise_frequency(float(frequencies[i])))
		else:
			result.append(0.025)
	return result


static func _sanitize_noise_frequency(frequency:float) -> float:
	if is_zero_approx(frequency):
		return 0.0001
	return frequency


static func is_in_grid(grid:Array, cell:Vector2i) -> bool:
	if grid.is_empty():
		return false
	return cell.y >= 0 and cell.y < grid.size() and cell.x >= 0 and cell.x < grid[cell.y].size()
