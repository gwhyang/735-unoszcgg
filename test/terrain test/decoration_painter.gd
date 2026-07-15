extends Node2D
class_name DecorationPainter

class GridOverlay:
	extends Node2D

	var grid_size:Vector2i = Vector2i.ZERO
	var tile_size:Vector2i = Vector2i(8, 8)
	var hovered_cell:Vector2i = Vector2i(-1, -1)
	var grid_color:Color = Color(1.0, 1.0, 1.0, 0.12)
	var border_color:Color = Color(1.0, 1.0, 1.0, 0.45)
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
const PLACEHOLDER_TILE_COUNT:int = 10

const EMPTY_ATLAS:Vector2i = Vector2i(0, 0)
const SEED_WAVE_ATLAS:Vector2i = Vector2i(1, 0)
const SPREAD_WAVE_ATLAS:Vector2i = Vector2i(2, 0)
const FINAL_WAVE_ATLAS:Vector2i = Vector2i(3, 0)
const SEED_GRASS_ATLAS:Vector2i = Vector2i(4, 0)
const SPREAD_GRASS_ATLAS:Vector2i = Vector2i(5, 0)
const FINAL_GRASS_ATLAS:Vector2i = Vector2i(6, 0)
const SEED_FISH_ATLAS:Vector2i = Vector2i(7, 0)
const SPREAD_FISH_ATLAS:Vector2i = Vector2i(8, 0)
const FINAL_FISH_ATLAS:Vector2i = Vector2i(9, 0)

const DECORATION_WAVE:int = 0
const DECORATION_GRASS:int = 1
const DECORATION_FISH:int = 2

const VIEW_SEED:int = 0
const VIEW_SPREAD:int = 1
const VIEW_FINAL:int = 2

const PANEL_WIDTH:float = 232.0
const PANEL_COMPACT_HEIGHT:float = 126.0
const PANEL_EXPANDED_HEIGHT:float = 388.0

@export var grid_size:Vector2i = Vector2i(300, 200)
@export var tile_size:Vector2i = Vector2i(8, 8)
@export var use_placeholder_tile_set:bool = true
@export var auto_generate_on_ready:bool = true
@export var decoration_type:int = DECORATION_WAVE

@export var wave_seed:int = 240714
@export var wave_seed_noise_frequency:float = 0.1
@export var wave_seed_noise_threshold:float = 0.72
@export var wave_seed_random_chance:float = 0.001
@export var wave_horizontal_spread_chance:float = 0.6
@export var wave_vertical_spread_chance:float = 0.2
@export var wave_spread_iterations:int = 5
@export var seagrass_erode_chance:float = 0.5
@export var fish_spread_chance:float = 0.35
@export var fish_delete_3x3_range:String = "7-9"
@export var fish_spawn_5x5_range:String = "4-25"
@export var fish_delete_5x5_range:String = "15-25"
@export var min_camera_zoom:float = 0.12
@export var max_camera_zoom:float = 6.0
@export var zoom_step:float = 1.15

@onready var panel_container:PanelContainer = %PanelContainer
@onready var parameter_grid:GridContainer = %ParameterGrid
@onready var decoration_layer:TileMapLayer = %DecorationLayer
@onready var camera:Camera2D = %Camera2D
@onready var generate_button:Button = %GenerateButton
@onready var randomize_button:Button = %RandomizeButton
@onready var config_button:Button = %ConfigButton
@onready var wave_type_button:Button = %WaveTypeButton
@onready var grass_type_button:Button = %GrassTypeButton
@onready var fish_type_button:Button = %FishTypeButton
@onready var seed_view_button:Button = %SeedViewButton
@onready var spread_view_button:Button = %SpreadViewButton
@onready var final_view_button:Button = %FinalViewButton
@onready var seed_spin_box:SpinBox = %SeedSpinBox
@onready var noise_frequency_spin_box:SpinBox = %NoiseFrequencySpinBox
@onready var noise_threshold_spin_box:SpinBox = %NoiseThresholdSpinBox
@onready var random_chance_spin_box:SpinBox = %RandomChanceSpinBox
@onready var horizontal_spread_spin_box:SpinBox = %HorizontalSpreadSpinBox
@onready var vertical_spread_spin_box:SpinBox = %VerticalSpreadSpinBox
@onready var spread_iterations_spin_box:SpinBox = %SpreadIterationsSpinBox
@onready var seagrass_erode_chance_spin_box:SpinBox = %SeagrassErodeChanceSpinBox
@onready var fish_spread_chance_spin_box:SpinBox = %FishSpreadChanceSpinBox
@onready var fish_delete_3x3_line_edit:LineEdit = %FishDelete3x3LineEdit
@onready var fish_spawn_5x5_line_edit:LineEdit = %FishSpawn5x5LineEdit
@onready var fish_delete_5x5_line_edit:LineEdit = %FishDelete5x5LineEdit
@onready var info_label:Label = %InfoLabel
@onready var hover_label:Label = %HoverLabel

var stage_steps:Dictionary = {}
var current_view_mode:int = VIEW_FINAL
var is_generating:bool = false
var is_panning:bool = false
var suppress_parameter_signals:bool = false
var parameters_expanded:bool = true
var grid_overlay:GridOverlay
var hovered_cell:Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	camera.make_current()
	if use_placeholder_tile_set or decoration_layer.tile_set == null:
		_build_placeholder_tile_set()
	_setup_grid_overlay()
	_center_camera()
	_setup_controls()
	_display_empty_grid()
	_refresh_info()
	_refresh_hover_label()
	if auto_generate_on_ready:
		call_deferred("_generate_decorations")


func _setup_controls() -> void:
	config_button.toggle_mode = true
	wave_type_button.toggle_mode = true
	grass_type_button.toggle_mode = true
	fish_type_button.toggle_mode = true
	seed_view_button.toggle_mode = true
	spread_view_button.toggle_mode = true
	final_view_button.toggle_mode = true
	_update_parameter_controls()
	_apply_parameter_panel_layout()
	_update_type_buttons()
	_update_view_buttons()

	generate_button.pressed.connect(_on_generate_pressed)
	randomize_button.pressed.connect(_on_randomize_pressed)
	config_button.toggled.connect(_on_config_button_toggled)
	wave_type_button.pressed.connect(_on_wave_type_pressed)
	grass_type_button.pressed.connect(_on_grass_type_pressed)
	fish_type_button.pressed.connect(_on_fish_type_pressed)
	seed_view_button.pressed.connect(_on_seed_view_pressed)
	spread_view_button.pressed.connect(_on_spread_view_pressed)
	final_view_button.pressed.connect(_on_final_view_pressed)
	seed_spin_box.value_changed.connect(_on_parameter_value_changed)
	noise_frequency_spin_box.value_changed.connect(_on_parameter_value_changed)
	noise_threshold_spin_box.value_changed.connect(_on_parameter_value_changed)
	random_chance_spin_box.value_changed.connect(_on_parameter_value_changed)
	horizontal_spread_spin_box.value_changed.connect(_on_parameter_value_changed)
	vertical_spread_spin_box.value_changed.connect(_on_parameter_value_changed)
	spread_iterations_spin_box.value_changed.connect(_on_parameter_value_changed)
	seagrass_erode_chance_spin_box.value_changed.connect(_on_parameter_value_changed)
	fish_spread_chance_spin_box.value_changed.connect(_on_parameter_value_changed)
	fish_delete_3x3_line_edit.text_submitted.connect(_on_parameter_text_submitted)
	fish_delete_3x3_line_edit.focus_exited.connect(_on_parameter_text_focus_exited)
	fish_spawn_5x5_line_edit.text_submitted.connect(_on_parameter_text_submitted)
	fish_spawn_5x5_line_edit.focus_exited.connect(_on_parameter_text_focus_exited)
	fish_delete_5x5_line_edit.text_submitted.connect(_on_parameter_text_submitted)
	fish_delete_5x5_line_edit.focus_exited.connect(_on_parameter_text_focus_exited)


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
	elif event is InputEventMouseMotion:
		var mouse_motion:InputEventMouseMotion = event as InputEventMouseMotion
		if is_panning:
			camera.global_position -= mouse_motion.relative / camera.zoom.x
			get_viewport().set_input_as_handled()


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
	decoration_layer.tile_set = tile_set


func _fill_atlas_tile(image:Image, tile_index:int, color:Color) -> void:
	var start_x:int = tile_index * tile_size.x
	for y:int in range(tile_size.y):
		for x:int in range(tile_size.x):
			image.set_pixel(start_x + x, y, color)


func _get_placeholder_tile_color(tile_index:int) -> Color:
	if tile_index == SEED_WAVE_ATLAS.x:
		return Color(0.74, 0.93, 1.0, 1.0)
	if tile_index == SPREAD_WAVE_ATLAS.x:
		return Color(0.32, 0.78, 0.94, 1.0)
	if tile_index == FINAL_WAVE_ATLAS.x:
		return Color(0.86, 0.98, 1.0, 1.0)
	if tile_index == SEED_GRASS_ATLAS.x:
		return Color(0.54, 0.86, 0.36, 1.0)
	if tile_index == SPREAD_GRASS_ATLAS.x:
		return Color(0.18, 0.66, 0.25, 1.0)
	if tile_index == FINAL_GRASS_ATLAS.x:
		return Color(0.72, 0.94, 0.48, 1.0)
	if tile_index == SEED_FISH_ATLAS.x:
		return Color(1.0, 0.82, 0.45, 1.0)
	if tile_index == SPREAD_FISH_ATLAS.x:
		return Color(0.96, 0.52, 0.2, 1.0)
	if tile_index == FINAL_FISH_ATLAS.x:
		return Color(1.0, 0.65, 0.28, 1.0)
	return Color(0.02, 0.12, 0.24, 1.0)


func _setup_grid_overlay() -> void:
	grid_overlay = GridOverlay.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.grid_size = grid_size
	grid_overlay.tile_size = tile_size
	grid_overlay.z_index = 10
	add_child(grid_overlay)


func _center_camera() -> void:
	camera.global_position = Vector2(float(grid_size.x * tile_size.x), float(grid_size.y * tile_size.y)) * 0.5


func _zoom_camera(factor:float) -> void:
	var next_zoom:float = clamp(camera.zoom.x * factor, min_camera_zoom, max_camera_zoom)
	camera.zoom = Vector2(next_zoom, next_zoom)


func _display_empty_grid() -> void:
	decoration_layer.clear()
	for y:int in range(grid_size.y):
		for x:int in range(grid_size.x):
			decoration_layer.set_cell(Vector2i(x, y), SOURCE_ID, EMPTY_ATLAS)


func _generate_decorations(reset_view:bool = false) -> void:
	if is_generating:
		return

	is_generating = true
	generate_button.disabled = true
	randomize_button.disabled = true
	_refresh_info("Generating %s..." % _get_decoration_name())

	stage_steps = TerrainDecoration.generate_steps(grid_size, _build_active_rule())
	if reset_view:
		current_view_mode = VIEW_FINAL
	_update_view_buttons()
	_display_current_stage()

	is_generating = false
	generate_button.disabled = false
	randomize_button.disabled = false
	_refresh_info()
	_refresh_hover_label()


func _build_active_rule() -> TerrainDecoration.DecorationRule:
	var rule = TerrainDecoration.DecorationRule.new()
	rule.seed = wave_seed
	rule.seed_noise_frequency = wave_seed_noise_frequency
	rule.seed_noise_threshold = wave_seed_noise_threshold
	rule.seed_random_chance = wave_seed_random_chance
	rule.spread_iterations = wave_spread_iterations
	rule.spread_chance = 0.0
	rule.spread_horizontal_chance = wave_horizontal_spread_chance
	rule.spread_vertical_chance = wave_vertical_spread_chance
	rule.spread_diagonal_chance = 0.0
	rule.spread_decay = 1.0
	rule.spread_diagonal = false
	rule.polish_iterations = 1
	rule.polish_keep_min_neighbors = 0
	rule.polish_birth_min_neighbors = 4
	rule.polish_diagonal = false
	rule.seagrass_erode_chance = seagrass_erode_chance
	rule.fish_spread_chance = fish_spread_chance
	rule.fish_delete_3x3_range = fish_delete_3x3_range
	rule.fish_spawn_5x5_range = fish_spawn_5x5_range
	rule.fish_delete_5x5_range = fish_delete_5x5_range
	if decoration_type == DECORATION_GRASS:
		rule.polish_mode = TerrainDecoration.POLISH_SEAGRASS_CROSS_ERODE
	elif decoration_type == DECORATION_FISH:
		rule.spread_mode = TerrainDecoration.SPREAD_FISH
		rule.polish_mode = TerrainDecoration.POLISH_CELLULAR
		rule.polish_iterations = 0
	else:
		rule.polish_mode = TerrainDecoration.POLISH_CELLULAR
	return rule


func _display_current_stage() -> void:
	var grid:Array = _get_current_grid()
	if grid.is_empty():
		_display_empty_grid()
		return

	var decoration_atlas:Vector2i = _get_atlas_for_view_mode()
	decoration_layer.clear()
	for y:int in range(grid_size.y):
		for x:int in range(grid_size.x):
			var atlas:Vector2i = EMPTY_ATLAS
			if grid[y][x] == TerrainDecoration.DECORATION:
				atlas = decoration_atlas
			decoration_layer.set_cell(Vector2i(x, y), SOURCE_ID, atlas)


func _get_current_grid() -> Array:
	if current_view_mode == VIEW_SEED:
		return _get_stage_grid("seed_grid")
	if current_view_mode == VIEW_SPREAD:
		return _get_stage_grid("spread_grid")
	return _get_stage_grid("result_grid")


func _get_stage_grid(stage_name:String) -> Array:
	var value:Variant = stage_steps.get(stage_name, [])
	if value is Array:
		return value
	return []


func _get_atlas_for_view_mode() -> Vector2i:
	if decoration_type == DECORATION_FISH:
		if current_view_mode == VIEW_SEED:
			return SEED_FISH_ATLAS
		if current_view_mode == VIEW_SPREAD:
			return SPREAD_FISH_ATLAS
		return FINAL_FISH_ATLAS

	if decoration_type == DECORATION_GRASS:
		if current_view_mode == VIEW_SEED:
			return SEED_GRASS_ATLAS
		if current_view_mode == VIEW_SPREAD:
			return SPREAD_GRASS_ATLAS
		return FINAL_GRASS_ATLAS

	if current_view_mode == VIEW_SEED:
		return SEED_WAVE_ATLAS
	if current_view_mode == VIEW_SPREAD:
		return SPREAD_WAVE_ATLAS
	return FINAL_WAVE_ATLAS


func _set_view_mode(view_mode:int) -> void:
	current_view_mode = view_mode
	_update_view_buttons()
	_display_current_stage()
	_refresh_info()
	_refresh_hover_label()


func _update_view_buttons() -> void:
	if seed_view_button == null:
		return
	seed_view_button.button_pressed = current_view_mode == VIEW_SEED
	spread_view_button.button_pressed = current_view_mode == VIEW_SPREAD
	final_view_button.button_pressed = current_view_mode == VIEW_FINAL


func _update_type_buttons() -> void:
	if wave_type_button == null:
		return
	wave_type_button.button_pressed = decoration_type == DECORATION_WAVE
	grass_type_button.button_pressed = decoration_type == DECORATION_GRASS
	fish_type_button.button_pressed = decoration_type == DECORATION_FISH


func _on_generate_pressed() -> void:
	_generate_decorations()


func _on_randomize_pressed() -> void:
	var rng:RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	wave_seed = rng.randi_range(1, 2147483647)
	_update_parameter_controls()
	_generate_decorations()


func _on_wave_type_pressed() -> void:
	decoration_type = DECORATION_WAVE
	_update_type_buttons()
	_generate_decorations()


func _on_grass_type_pressed() -> void:
	decoration_type = DECORATION_GRASS
	_update_type_buttons()
	_generate_decorations()


func _on_fish_type_pressed() -> void:
	decoration_type = DECORATION_FISH
	_update_type_buttons()
	_generate_decorations()


func _on_seed_view_pressed() -> void:
	_set_view_mode(VIEW_SEED)


func _on_spread_view_pressed() -> void:
	_set_view_mode(VIEW_SPREAD)


func _on_final_view_pressed() -> void:
	_set_view_mode(VIEW_FINAL)


func _on_config_button_toggled(button_pressed:bool) -> void:
	parameters_expanded = button_pressed
	_apply_parameter_panel_layout()


func _on_parameter_value_changed(value:float) -> void:
	if suppress_parameter_signals:
		return
	_read_parameter_controls()
	_generate_decorations()


func _on_parameter_text_submitted(value:String) -> void:
	_read_parameter_controls()
	_generate_decorations()

func _on_parameter_text_focus_exited() -> void:
	_read_parameter_controls()
	_generate_decorations()

func _read_parameter_controls() -> void:
	wave_seed = int(seed_spin_box.value)
	wave_seed_noise_frequency = float(noise_frequency_spin_box.value)
	wave_seed_noise_threshold = float(noise_threshold_spin_box.value)
	wave_seed_random_chance = float(random_chance_spin_box.value)
	wave_horizontal_spread_chance = float(horizontal_spread_spin_box.value)
	wave_vertical_spread_chance = float(vertical_spread_spin_box.value)
	wave_spread_iterations = int(spread_iterations_spin_box.value)
	seagrass_erode_chance = float(seagrass_erode_chance_spin_box.value)
	fish_spread_chance = float(fish_spread_chance_spin_box.value)
	fish_delete_3x3_range = fish_delete_3x3_line_edit.text
	fish_spawn_5x5_range = fish_spawn_5x5_line_edit.text
	fish_delete_5x5_range = fish_delete_5x5_line_edit.text


func _update_parameter_controls() -> void:
	if seed_spin_box == null:
		return
	suppress_parameter_signals = true
	seed_spin_box.value = wave_seed
	noise_frequency_spin_box.value = wave_seed_noise_frequency
	noise_threshold_spin_box.value = wave_seed_noise_threshold
	random_chance_spin_box.value = wave_seed_random_chance
	horizontal_spread_spin_box.value = wave_horizontal_spread_chance
	vertical_spread_spin_box.value = wave_vertical_spread_chance
	spread_iterations_spin_box.value = wave_spread_iterations
	seagrass_erode_chance_spin_box.value = seagrass_erode_chance
	fish_spread_chance_spin_box.value = fish_spread_chance
	fish_delete_3x3_line_edit.text = fish_delete_3x3_range
	fish_spawn_5x5_line_edit.text = fish_spawn_5x5_range
	fish_delete_5x5_line_edit.text = fish_delete_5x5_range
	suppress_parameter_signals = false


func _apply_parameter_panel_layout() -> void:
	if parameter_grid == null:
		return
	parameter_grid.visible = parameters_expanded
	if hover_label != null:
		hover_label.visible = false
	config_button.button_pressed = parameters_expanded
	var height:float = PANEL_EXPANDED_HEIGHT if parameters_expanded else PANEL_COMPACT_HEIGHT
	panel_container.offset_left = -6.0 - PANEL_WIDTH
	panel_container.offset_right = -6.0
	panel_container.offset_top = 6.0
	panel_container.offset_bottom = 6.0 + height


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
	if not message.is_empty():
		info_label.text = message
		return

	var seed_count:int = TerrainDecoration.count_decorations(_get_stage_grid("seed_grid"))
	var spread_count:int = TerrainDecoration.count_decorations(_get_stage_grid("spread_grid"))
	var final_count:int = TerrainDecoration.count_decorations(_get_stage_grid("result_grid"))
	info_label.text = "%s  S:%d  D:%d  F:%d  %s" % [
		_get_decoration_name(),
		seed_count,
		spread_count,
		final_count,
		_get_view_name(),
	]


func _refresh_hover_label() -> void:
	if not _is_in_bounds(hovered_cell):
		hover_label.text = "Cell: outside"
		return

	var grid:Array = _get_current_grid()
	if grid.is_empty():
		hover_label.text = "Cell: %d,%d  Empty" % [hovered_cell.x, hovered_cell.y]
		return

	var is_decoration:bool = grid[hovered_cell.y][hovered_cell.x] == TerrainDecoration.DECORATION
	var neighbor_count:int = TerrainDecoration.count_decoration_neighbors(grid, hovered_cell, TerrainDecoration.DIRECTIONS_4)
	hover_label.text = "Cell: %d,%d  %s  N4:%d" % [
		hovered_cell.x,
		hovered_cell.y,
		_get_decoration_name() if is_decoration else "Empty",
		neighbor_count,
	]


func _get_decoration_name() -> String:
	if decoration_type == DECORATION_FISH:
		return "Fish"
	if decoration_type == DECORATION_GRASS:
		return "Grass"
	return "Wave"


func _get_view_name() -> String:
	if current_view_mode == VIEW_SEED:
		return "Seed"
	if current_view_mode == VIEW_SPREAD:
		return "Spread"
	return "Final"


func _get_mouse_cell() -> Vector2i:
	var local_position:Vector2 = decoration_layer.to_local(get_global_mouse_position())
	return decoration_layer.local_to_map(local_position)


func _is_in_bounds(cell:Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y
