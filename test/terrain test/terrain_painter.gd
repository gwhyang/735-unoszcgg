extends Node2D
class_name TerrainPainter

class GridOverlay:
	extends Node2D

	var grid_size:Vector2i = Vector2i.ZERO
	var tile_size:Vector2i = Vector2i(8, 8)
	var hovered_cell:Vector2i = Vector2i(-1, -1)
	var grid_color:Color = Color(1.0, 1.0, 1.0, 0.18)
	var border_color:Color = Color(1.0, 1.0, 1.0, 0.55)
	var hover_color:Color = Color(1.0, 1.0, 1.0, 0.9)

	func _draw() -> void:
		var width:float = float(grid_size.x * tile_size.x)
		var height:float = float(grid_size.y * tile_size.y)

		for x:int in range(grid_size.x + 1):
			var px:float = float(x * tile_size.x)
			draw_line(Vector2(px, 0.0), Vector2(px, height), grid_color)

		for y:int in range(grid_size.y + 1):
			var py:float = float(y * tile_size.y)
			draw_line(Vector2(0.0, py), Vector2(width, py), grid_color)

		draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), border_color, false, 2.0)

		if hovered_cell.x >= 0 and hovered_cell.y >= 0:
			var position:Vector2 = Vector2(float(hovered_cell.x * tile_size.x), float(hovered_cell.y * tile_size.y))
			var size:Vector2 = Vector2(float(tile_size.x), float(tile_size.y))
			draw_rect(Rect2(position, size), hover_color, false, 2.0)


const SOURCE_ID:int = 0
const PLACEHOLDER_TILE_COUNT:int = 5
const SMOOTH_RADIUS:int = 2

const OCEAN_ATLAS:Vector2i = Vector2i(0, 0)
const LAND_ATLAS:Vector2i = Vector2i(1, 0)
const SHALLOW_SEA_ATLAS:Vector2i = Vector2i(2, 0)
const TRANSITION_SEA_ATLAS:Vector2i = Vector2i(3, 0)
const DEEP_SEA_ATLAS:Vector2i = Vector2i(4, 0)

const DIRECTIONS:Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

@export var grid_size:Vector2i = Vector2i(500, 500)
@export var tile_size:Vector2i = Vector2i(8, 8)
@export var brush_radius:int = 2
@export var use_placeholder_tile_set:bool = true
@export_range(0.0, 1.0, 0.01) var shallow_threshold:float = 0.33
@export_range(0.0, 1.0, 0.01) var deep_threshold:float = 0.66
@export_range(0, 20, 1) var smooth_iterations:int = 4
@export_range(0.0, 1.0, 0.01) var smooth_strength:float = 0.85
@export var noise_scale_1:float = 0.1
@export var noise_frequency_1:float = 0.025
@export var noise_scale_2:float = 0.04
@export var noise_frequency_2:float = 0.06
@export var noise_scale_3:float = 0.02
@export var noise_frequency_3:float = 0.14
@export var noise_seed:int = 1337
@export var min_camera_zoom:float = 0.08
@export var max_camera_zoom:float = 4.0
@export var zoom_step:float = 1.15

@onready var terrain_layer:TileMapLayer = %TerrainLayer
@onready var camera:Camera2D = %Camera2D
@onready var generate_button:Button = %GenerateButton
@onready var clear_button:Button = %ClearButton
@onready var bucket_button:Button = %BucketButton
@onready var brush_spin_box:SpinBox = %BrushSpinBox
@onready var shallow_spin_box:SpinBox = %ShallowSpinBox
@onready var deep_spin_box:SpinBox = %DeepSpinBox
@onready var noise_scale_spin_boxes:Array[SpinBox] = [%NoiseScale1SpinBox, %NoiseScale2SpinBox, %NoiseScale3SpinBox]
@onready var noise_frequency_spin_boxes:Array[SpinBox] = [%NoiseFrequency1SpinBox, %NoiseFrequency2SpinBox, %NoiseFrequency3SpinBox]
@onready var info_label:Label = %InfoLabel
@onready var hover_label:Label = %HoverLabel

var grid:Array = []
var distance_grid:Array = []
var normalized_height_grid:Array = []
var noise_grid:Array = []
var noisy_height_grid:Array = []
var smoothed_height_grid:Array = []
var terrain_type_grid:Array = []
var land_count:int = 0
var max_distance:int = 0
var height_generated:bool = false
var is_generating:bool = false
var is_painting_land:bool = false
var is_erasing_land:bool = false
var is_bucket_mode:bool = false
var is_panning:bool = false
var grid_overlay:GridOverlay
var hovered_cell:Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	camera.make_current()
	if use_placeholder_tile_set or terrain_layer.tile_set == null:
		_build_placeholder_tile_set()
	_setup_grid_overlay()
	_create_grid()
	_show_base_grid()
	_center_camera()
	_setup_controls()
	_refresh_info()
	_refresh_hover_label()


func _setup_controls() -> void:
	bucket_button.toggle_mode = true
	bucket_button.button_pressed = is_bucket_mode
	brush_spin_box.value = brush_radius
	shallow_spin_box.value = shallow_threshold
	deep_spin_box.value = deep_threshold
	noise_scale_spin_boxes[0].value = noise_scale_1
	noise_scale_spin_boxes[1].value = noise_scale_2
	noise_scale_spin_boxes[2].value = noise_scale_3
	noise_frequency_spin_boxes[0].value = noise_frequency_1
	noise_frequency_spin_boxes[1].value = noise_frequency_2
	noise_frequency_spin_boxes[2].value = noise_frequency_3

	generate_button.pressed.connect(_on_generate_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	bucket_button.toggled.connect(_on_bucket_button_toggled)
	brush_spin_box.value_changed.connect(_on_brush_spin_box_value_changed)
	shallow_spin_box.value_changed.connect(_on_shallow_threshold_value_changed)
	deep_spin_box.value_changed.connect(_on_deep_threshold_value_changed)
	for spin_box:SpinBox in noise_scale_spin_boxes:
		spin_box.value_changed.connect(_on_noise_parameter_value_changed)
	for spin_box:SpinBox in noise_frequency_spin_boxes:
		spin_box.value_changed.connect(_on_noise_parameter_value_changed)


func _process(delta:float) -> void:
	_update_hovered_cell()


func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button:InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_camera(zoom_step)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_camera(1.0 / zoom_step)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = mouse_button.pressed
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed and not _is_pointer_on_ui():
				if is_bucket_mode:
					_bucket_fill_at_mouse(TerrainDistance.LAND)
				else:
					is_painting_land = true
					_paint_at_mouse(TerrainDistance.LAND)
				get_viewport().set_input_as_handled()
			else:
				is_painting_land = false
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_button.pressed and not _is_pointer_on_ui():
				if is_bucket_mode:
					_bucket_fill_at_mouse(TerrainDistance.OCEAN)
				else:
					is_erasing_land = true
					_paint_at_mouse(TerrainDistance.OCEAN)
				get_viewport().set_input_as_handled()
			else:
				is_erasing_land = false
	elif event is InputEventMouseMotion:
		var mouse_motion:InputEventMouseMotion = event as InputEventMouseMotion
		if is_panning:
			camera.global_position -= mouse_motion.relative / camera.zoom.x
			get_viewport().set_input_as_handled()
		elif is_painting_land:
			_paint_at_mouse(TerrainDistance.LAND)
			get_viewport().set_input_as_handled()
		elif is_erasing_land:
			_paint_at_mouse(TerrainDistance.OCEAN)
			get_viewport().set_input_as_handled()


func get_normalized_height_grid() -> Array:
	return noisy_height_grid


func _build_placeholder_tile_set() -> void:
	var image:Image = Image.create(tile_size.x * PLACEHOLDER_TILE_COUNT, tile_size.y, false, Image.FORMAT_RGBA8)

	for tile_index:int in range(PLACEHOLDER_TILE_COUNT):
		_fill_atlas_tile(image, tile_index, _get_placeholder_tile_color(tile_index))

	var texture:ImageTexture = ImageTexture.create_from_image(image)
	var source:TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = tile_size
	for tile_index:int in range(PLACEHOLDER_TILE_COUNT):
		source.create_tile(Vector2i(tile_index, 0))

	var tile_set:TileSet = TileSet.new()
	tile_set.tile_size = tile_size
	tile_set.add_source(source, SOURCE_ID)
	terrain_layer.tile_set = tile_set


func _fill_atlas_tile(image:Image, tile_index:int, color:Color) -> void:
	var start_x:int = tile_index * tile_size.x
	for y:int in range(tile_size.y):
		for x:int in range(tile_size.x):
			image.set_pixel(start_x + x, y, color)


func _get_placeholder_tile_color(tile_index:int) -> Color:
	if tile_index == OCEAN_ATLAS.x:
		return Color(0.04, 0.18, 0.34, 1.0)
	if tile_index == LAND_ATLAS.x:
		return Color(0.20, 0.58, 0.24, 1.0)
	if tile_index == SHALLOW_SEA_ATLAS.x:
		return Color(0.56, 0.84, 0.82, 1.0)
	if tile_index == TRANSITION_SEA_ATLAS.x:
		return Color(0.18, 0.43, 0.64, 1.0)
	return Color(0.02, 0.07, 0.22, 1.0)


func _setup_grid_overlay() -> void:
	grid_overlay = GridOverlay.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.grid_size = grid_size
	grid_overlay.tile_size = tile_size
	grid_overlay.z_index = 10
	add_child(grid_overlay)


func _create_grid() -> void:
	grid.clear()
	_clear_generated_data()
	land_count = 0
	height_generated = false

	for y:int in range(grid_size.y):
		var row:Array = []
		row.resize(grid_size.x)
		for x:int in range(grid_size.x):
			row[x] = TerrainDistance.OCEAN
		grid.append(row)


func _clear_generated_data() -> void:
	distance_grid.clear()
	normalized_height_grid.clear()
	noise_grid.clear()
	noisy_height_grid.clear()
	smoothed_height_grid.clear()
	terrain_type_grid.clear()
	max_distance = 0


func _show_base_grid() -> void:
	terrain_layer.clear()
	for y:int in range(grid_size.y):
		for x:int in range(grid_size.x):
			var cell:Vector2i = Vector2i(x, y)
			if grid[y][x] == TerrainDistance.LAND:
				terrain_layer.set_cell(cell, SOURCE_ID, LAND_ATLAS)
			else:
				terrain_layer.set_cell(cell, SOURCE_ID, OCEAN_ATLAS)


func _center_camera() -> void:
	camera.global_position = Vector2(float(grid_size.x * tile_size.x), float(grid_size.y * tile_size.y)) * 0.5


func _zoom_camera(factor:float) -> void:
	var next_zoom:float = clamp(camera.zoom.x * factor, min_camera_zoom, max_camera_zoom)
	camera.zoom = Vector2(next_zoom, next_zoom)


func _paint_at_mouse(value:int) -> void:
	if is_generating or _is_pointer_on_ui():
		return

	var center:Vector2i = _get_mouse_cell()
	if not _is_in_bounds(center):
		return

	if height_generated:
		_invalidate_height_display()

	var changed:bool = false
	var radius_squared:int = brush_radius * brush_radius
	for y:int in range(center.y - brush_radius, center.y + brush_radius + 1):
		for x:int in range(center.x - brush_radius, center.x + brush_radius + 1):
			var dx:int = x - center.x
			var dy:int = y - center.y
			if dx * dx + dy * dy > radius_squared:
				continue

			var cell:Vector2i = Vector2i(x, y)
			if _set_grid_cell(cell, value):
				changed = true

	if changed:
		_refresh_info()
		_refresh_hover_label()


func _bucket_fill_at_mouse(value:int) -> void:
	if is_generating or _is_pointer_on_ui():
		return

	var start:Vector2i = _get_mouse_cell()
	if not _is_in_bounds(start):
		return
	if grid[start.y][start.x] == value:
		return

	if height_generated:
		_invalidate_height_display()

	var changed_count:int = _flood_fill(start, value)
	if changed_count > 0:
		_refresh_info("Filled: %d  Land: %d" % [changed_count, land_count])
		_refresh_hover_label()


func _flood_fill(start:Vector2i, value:int) -> int:
	var source_value:int = grid[start.y][start.x]
	var queue:Array[Vector2i] = []
	var queue_index:int = 0
	var changed_count:int = 0

	if _set_grid_cell(start, value):
		changed_count += 1
		queue.append(start)

	while queue_index < queue.size():
		var current:Vector2i = queue[queue_index]
		queue_index += 1

		for direction:Vector2i in DIRECTIONS:
			var next:Vector2i = current + direction
			if not _is_in_bounds(next):
				continue
			if grid[next.y][next.x] != source_value:
				continue
			if _set_grid_cell(next, value):
				changed_count += 1
				queue.append(next)

	return changed_count


func _set_grid_cell(cell:Vector2i, value:int) -> bool:
	if not _is_in_bounds(cell):
		return false

	var current:int = grid[cell.y][cell.x]
	if current == value:
		return false

	grid[cell.y][cell.x] = value
	if current == TerrainDistance.LAND:
		land_count -= 1
	if value == TerrainDistance.LAND:
		land_count += 1

	if value == TerrainDistance.LAND:
		terrain_layer.set_cell(cell, SOURCE_ID, LAND_ATLAS)
	else:
		terrain_layer.set_cell(cell, SOURCE_ID, OCEAN_ATLAS)
	return true


func _invalidate_height_display() -> void:
	height_generated = false
	_clear_generated_data()
	_show_base_grid()


func _on_generate_pressed() -> void:
	if is_generating:
		return

	is_generating = true
	generate_button.disabled = true
	clear_button.disabled = true
	_refresh_info("Generating height...")
	await get_tree().process_frame

	if land_count == 0:
		height_generated = false
		_clear_generated_data()
		_show_base_grid()
		is_generating = false
		generate_button.disabled = false
		clear_button.disabled = false
		_refresh_info("No land. Paint land first.")
		_refresh_hover_label()
		return

	_regenerate_from_distance()
	height_generated = true
	is_generating = false
	generate_button.disabled = false
	clear_button.disabled = false

	_refresh_info("Height ready. Land: %d  Max: %d" % [land_count, max_distance])
	_refresh_hover_label()


func _regenerate_from_distance() -> void:
	distance_grid = TerrainDistance.build_distance_grid(grid)
	max_distance = TerrainDistance.get_max_distance(distance_grid)
	normalized_height_grid = TerrainDistance.normalize_distance_grid(distance_grid)
	_regenerate_from_smoothing()


func _regenerate_from_noise() -> void:
	if smoothed_height_grid.is_empty():
		return
	noise_grid = TerrainDistance.build_noise_grid(grid_size, _get_noise_scales(), _get_noise_frequencies(), noise_seed)
	noisy_height_grid = TerrainDistance.add_noise_to_height_grid(smoothed_height_grid, distance_grid, noise_grid)
	_regenerate_from_thresholds()


func _regenerate_from_smoothing() -> void:
	if normalized_height_grid.is_empty():
		return
	smoothed_height_grid = TerrainDistance.smooth_height_grid(normalized_height_grid, distance_grid, smooth_iterations, smooth_strength, SMOOTH_RADIUS)
	_regenerate_from_noise()


func _regenerate_from_thresholds() -> void:
	if noisy_height_grid.is_empty():
		return
	terrain_type_grid = TerrainDistance.classify_terrain_grid(distance_grid, noisy_height_grid, shallow_threshold, deep_threshold)
	_display_terrain_result()


func _display_terrain_result() -> void:
	if terrain_type_grid.is_empty():
		return

	for y:int in range(grid_size.y):
		for x:int in range(grid_size.x):
			terrain_layer.set_cell(Vector2i(x, y), SOURCE_ID, _get_atlas_for_terrain_type(terrain_type_grid[y][x]))


func _get_atlas_for_terrain_type(terrain_type:int) -> Vector2i:
	if terrain_type == TerrainDistance.TERRAIN_LAND:
		return LAND_ATLAS
	if terrain_type == TerrainDistance.TERRAIN_SHALLOW_SEA:
		return SHALLOW_SEA_ATLAS
	if terrain_type == TerrainDistance.TERRAIN_TRANSITION_SEA:
		return TRANSITION_SEA_ATLAS
	if terrain_type == TerrainDistance.TERRAIN_DEEP_SEA:
		return DEEP_SEA_ATLAS
	return OCEAN_ATLAS


func _on_clear_pressed() -> void:
	if is_generating:
		return

	_create_grid()
	_show_base_grid()
	_refresh_info()
	_refresh_hover_label()


func _on_bucket_button_toggled(button_pressed:bool) -> void:
	is_bucket_mode = button_pressed
	is_painting_land = false
	is_erasing_land = false
	_refresh_info()


func _on_brush_spin_box_value_changed(value:float) -> void:
	brush_radius = int(value)
	_refresh_info()


func _on_shallow_threshold_value_changed(value:float) -> void:
	shallow_threshold = clamp(value, 0.0, 1.0)
	if shallow_threshold > deep_threshold:
		deep_threshold = shallow_threshold
		deep_spin_box.set_value_no_signal(deep_threshold)
	if height_generated:
		_regenerate_from_thresholds()
	_refresh_info()
	_refresh_hover_label()


func _on_deep_threshold_value_changed(value:float) -> void:
	deep_threshold = clamp(value, 0.0, 1.0)
	if deep_threshold < shallow_threshold:
		shallow_threshold = deep_threshold
		shallow_spin_box.set_value_no_signal(shallow_threshold)
	if height_generated:
		_regenerate_from_thresholds()
	_refresh_info()
	_refresh_hover_label()


func _on_noise_parameter_value_changed(value:float) -> void:
	noise_scale_1 = float(noise_scale_spin_boxes[0].value)
	noise_scale_2 = float(noise_scale_spin_boxes[1].value)
	noise_scale_3 = float(noise_scale_spin_boxes[2].value)
	noise_frequency_1 = float(noise_frequency_spin_boxes[0].value)
	noise_frequency_2 = float(noise_frequency_spin_boxes[1].value)
	noise_frequency_3 = float(noise_frequency_spin_boxes[2].value)
	if height_generated:
		_regenerate_from_noise()
	else:
		_refresh_info()


func _get_noise_scales() -> Array:
	return [noise_scale_1, noise_scale_2, noise_scale_3]


func _get_noise_frequencies() -> Array:
	return [noise_frequency_1, noise_frequency_2, noise_frequency_3]


func _update_hovered_cell() -> void:
	var cell:Vector2i = _get_mouse_cell()
	if cell == hovered_cell:
		return

	hovered_cell = cell
	if _is_in_bounds(cell):
		grid_overlay.hovered_cell = cell
	else:
		grid_overlay.hovered_cell = Vector2i(-1, -1)
	grid_overlay.queue_redraw()
	_refresh_hover_label()


func _refresh_info(message:String = "") -> void:
	if message.is_empty():
		var tool_name:String = "Bucket" if is_bucket_mode else "Brush"
		info_label.text = "Grid: %dx%d  Land: %d  Tool: %s  Brush: %d  A: %.2f  B: %.2f  N: %.2f/%.2f/%.2f" % [grid_size.x, grid_size.y, land_count, tool_name, brush_radius, shallow_threshold, deep_threshold, noise_scale_1, noise_scale_2, noise_scale_3]
	else:
		info_label.text = message


func _refresh_hover_label() -> void:
	if not _is_in_bounds(hovered_cell):
		hover_label.text = "Cell: outside"
		return

	var terrain_value:int = grid[hovered_cell.y][hovered_cell.x]
	if terrain_value == TerrainDistance.LAND:
		hover_label.text = "Cell: %d,%d  Land  Height: 0  Norm: 0.00" % [hovered_cell.x, hovered_cell.y]
	elif height_generated and not noisy_height_grid.is_empty():
		var distance:int = distance_grid[hovered_cell.y][hovered_cell.x]
		var normalized_height:float = noisy_height_grid[hovered_cell.y][hovered_cell.x]
		var terrain_name:String = TerrainDistance.terrain_type_to_name(terrain_type_grid[hovered_cell.y][hovered_cell.x])
		hover_label.text = "Cell: %d,%d  Ocean  Height: %d  Norm: %.2f  %s" % [hovered_cell.x, hovered_cell.y, distance, normalized_height, terrain_name]
	else:
		hover_label.text = "Cell: %d,%d  Ocean" % [hovered_cell.x, hovered_cell.y]


func _get_mouse_cell() -> Vector2i:
	var local_position:Vector2 = terrain_layer.to_local(get_global_mouse_position())
	return terrain_layer.local_to_map(local_position)


func _is_in_bounds(cell:Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y


func _is_pointer_on_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null