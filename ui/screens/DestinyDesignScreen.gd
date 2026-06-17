# GrowthScreen.gd (구 DestinyDesignScreen.gd)
# 화면 설명: 주사위를 굴려 스탯을 분배하는 '성장' 시스템 화면입니다.
extends Control

signal closed

# --- 프리로드 설정 ---
const DestinyDieScene = preload("res://ui/elements/DestinyDie.tscn")  
const StatSlotScene = preload("res://ui/elements/StatSlot.tscn")      
const PhysicsDieScene = preload("res://ui/elements/PhysicsDie.tscn")

# --- 노드 참조 ---
@onready var dice_manager = get_node("/root/DiceManager")
@onready var game_manager = get_node("/root/GameManager")

@onready var dice_arena = $DiceArena
@onready var ui_lines = $UI_Layer/Lines
@onready var exp_label = $UI_Layer/Zone1_Header/Zone1_Exp
@onready var exp_gauge = $UI_Layer/Zone1_Header/ExpGauge
@onready var stat_slots_container = $UI_Layer/Zone3_Stats/StatSlotsContainer
@onready var dice_slots_container = $UI_Layer/Zone4_Slots/DiceSlotsContainer
@onready var power_gauge = $UI_Layer/Zone5_Gauge
@onready var roll_button = $UI_Layer/RollButton
@onready var close_button = $UI_Layer/CloseButton

# --- 상태 관리 ---
enum Phase { IDLE, CHARGING, ROLLING, REVEAL }
var current_phase = Phase.IDLE

var dice_instances: Array = []   # 오른쪽 슬롯의 UI 주사위들
var physics_dice: Array = []     # 아레나의 물리 주사위들
var arena_ui_dice: Array = []    # 아레나에 멈춘 후 교체된 UI 주사위들
var roll_results: Array = []
var invested_stat_names: Array = [] 
var charge_power: float = 0.0
var charge_speed: float = 150.0
var charge_direction: int = 1

# --- 레이아웃 상수 ---
const ZONE_1_H = 60
const ZONE_5_H = 60
const ZONE_3_W = 250
const ZONE_4_W = 200

const INVESTABLE_STATS = [
	"agi", "vit", "int_stat", "atk",
	"spd", "res", "spi", "rec"
]

func _ready():
	close_button.pressed.connect(_on_close_button_pressed)
	roll_button.button_down.connect(_on_roll_button_down)
	roll_button.button_up.connect(_on_roll_button_up)

	power_gauge.value = 0
	power_gauge.visible = false

	ui_lines.draw.connect(_on_draw_lines)
	ui_lines.queue_redraw()

	_setup_physics_walls()
	_initialize_stat_slots()
	_spawn_initial_dice_in_slots()
	_update_exploration_progress()

	roll_button.visible = dice_manager.can_roll()

	if not dice_manager.can_roll() and not dice_manager.last_roll_results.is_empty():
		_restore_previous_rolls()

func _update_exploration_progress():
	var map_manager = get_node_or_null("/root/MapManager")
	if map_manager and map_manager.dungeon_data.has("nodes"):
		var visited = map_manager.player_run_state.VisitedNodeIDs.size()
		var total = map_manager.dungeon_data.nodes.size()
		exp_label.text = "탐험 진척도: %d / %d" % [visited, total]

		if total > 0:
			exp_gauge.value = (float(visited) / float(total)) * 100.0
		else:
			exp_gauge.value = 0
	else:
		exp_label.text = "탐험 진척도: 0 / 0"
		exp_gauge.value = 0

func _input(event):
	if not game_manager.is_developer_mode: return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R: _launch_dice() # R 키로 재투척
			KEY_1: _dev_add_dice(4)
			KEY_2: _dev_add_dice(6)
			KEY_3: _dev_add_dice(8)
			KEY_4: _dev_add_dice(10)
			KEY_5: _dev_add_dice(12)
			KEY_6: _dev_add_dice(20)

func _dev_add_dice(sides: int):
	dice_manager.add_dice_to_pool(sides)
	_spawn_initial_dice_in_slots()
	print("개발자: D", sides, " 주사위를 추가했습니다.")

func _process(delta):
	if current_phase == Phase.CHARGING:
		charge_power += charge_speed * delta * charge_direction
		if charge_power >= 100.0:
			charge_power = 100.0
			charge_direction = -1
		elif charge_power <= 0.0:
			charge_power = 0.0
			charge_direction = 1
		power_gauge.value = charge_power

func _on_roll_button_down():
	if current_phase == Phase.IDLE and _can_start_rolling():
		_start_charging()

func _on_roll_button_up():
	if current_phase == Phase.CHARGING:
		_launch_dice()

func _setup_physics_walls():
	var walls_node = get_node_or_null("DiceArena/Walls")
	if not walls_node: return

	for child in walls_node.get_children():
		child.queue_free()

	var wall_configs = [
		{"name": "Top", "pos": Vector2(601, 10), "size": Vector2(1000, 100)},
		{"name": "Bottom", "pos": Vector2(601, 638), "size": Vector2(1000, 100)},
		{"name": "Left", "pos": Vector2(200, 324), "size": Vector2(100, 800)},
		{"name": "Right", "pos": Vector2(1002, 324), "size": Vector2(100, 800)}
	]

	for config in wall_configs:
		var col = CollisionShape2D.new()
		col.name = "Wall_" + config["name"]
		var shape = RectangleShape2D.new()
		shape.size = config["size"]
		col.shape = shape
		col.position = config["pos"]
		walls_node.add_child(col)

func _initialize_stat_slots():
	for child in stat_slots_container.get_children():
		child.queue_free()

	var stats_obj = null
	if game_manager.player_node and game_manager.player_node.current_stats:
		stats_obj = game_manager.player_node.current_stats
	else:
		var pm = get_node_or_null("/root/PlayerManager")
		if pm and pm.current_player_stats:
			stats_obj = pm.current_player_stats

	if stats_obj:
		for s_name in INVESTABLE_STATS:
			var stat_res = stats_obj.get_stat(s_name)
			if stat_res:
				var slot = StatSlotScene.instantiate()
				stat_slots_container.add_child(slot)
				slot.set_stat(s_name, stat_res)

func _spawn_initial_dice_in_slots():
	for d in dice_instances:
		if is_instance_valid(d): d.queue_free()
	dice_instances.clear()

	var player_dice = dice_manager.get_player_dice_pool()
	for i in range(player_dice.size()):
		var sides = player_dice[i]
		var die = DestinyDieScene.instantiate()
		dice_slots_container.add_child(die)
		die.setup(sides, 0)
		die.gui_input.connect(_on_slot_dice_input.bind(die))
		dice_instances.append(die)

func _on_slot_dice_input(event, die_node):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:        
		if current_phase == Phase.IDLE and dice_manager.can_roll() and die_node.modulate.a == 1.0:      
			pass

func reroll_dice(die_node):
	var rect = get_viewport_rect()
	var arena_center = Vector2((ZONE_3_W + (rect.size.x - ZONE_4_W)) / 2, (ZONE_1_H + (rect.size.y - ZONE_5_H)) / 2)

	var pd = PhysicsDieScene.instantiate()
	dice_arena.add_child(pd)
	pd.setup(die_node.dice_sides)
	pd.global_position = arena_center + Vector2(randf_range(-50, 50), randf_range(-50, 50))

	var dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	pd.launch(dir, 50.0)
	pd.stopped.connect(func(val): _on_physics_die_stopped(val, pd))
	physics_dice.append(pd)
	die_node.modulate.a = 0.1 

func _can_start_rolling() -> bool:
	return current_phase == Phase.IDLE and dice_manager.can_roll() and not dice_instances.is_empty() and physics_dice.is_empty() and arena_ui_dice.is_empty()

func _restore_previous_rolls():
	for die in dice_instances:
		die.modulate.a = 0.3

	for res in dice_manager.last_roll_results:
		if not res.get("is_used", false):
			var ui_die = DestinyDieScene.instantiate()
			dice_arena.add_child(ui_die)
			
			# [신규] 저장된 물리 위치가 있으면 그곳에, 없으면 중앙 부근 랜덤 배치
			if res.has("position") and res.position != Vector2.ZERO:
				ui_die.global_position = res.position
			else:
				var rect = get_viewport_rect()
				var arena_center = Vector2((ZONE_3_W + (rect.size.x - ZONE_4_W)) / 2, (ZONE_1_H + (rect.size.y - ZONE_5_H)) / 2)
				ui_die.global_position = arena_center + Vector2(randf_range(-100, 100), randf_range(-100, 100))
			
			ui_die.setup(res.sides, res.value)
			arena_ui_dice.append(ui_die)

	current_phase = Phase.IDLE

func _start_charging():
	current_phase = Phase.CHARGING
	power_gauge.visible = true
	charge_power = 0.0
	charge_direction = 1

func _launch_dice():
	current_phase = Phase.ROLLING
	power_gauge.visible = false
	roll_button.visible = false 
	invested_stat_names.clear() 
	dice_manager.reset_all_dice_usage()

	dice_manager.can_roll_new_dice = false
	dice_manager.last_roll_results.clear()

	for pd in physics_dice: if is_instance_valid(pd): pd.queue_free()
	for ud in arena_ui_dice: if is_instance_valid(ud): ud.queue_free()
	physics_dice.clear()
	arena_ui_dice.clear()
	roll_results.clear()

	for die in dice_instances:
		die.modulate.a = 0.3

	var rect = get_viewport_rect()
	var arena_center = Vector2((ZONE_3_W + (rect.size.x - ZONE_4_W)) / 2, (ZONE_1_H + (rect.size.y - ZONE_5_H)) / 2)

	for i in range(dice_instances.size()):
		var die_ui = dice_instances[i]
		var pd = PhysicsDieScene.instantiate()
		dice_arena.add_child(pd)
		pd.setup(die_ui.dice_sides)
		pd.global_position = arena_center + Vector2(randf_range(-100, 100), randf_range(-50, 50))       
		var angle = randf_range(-PI/4, PI/4) - PI/2
		var dir = Vector2.RIGHT.rotated(angle)
		pd.launch(dir, charge_power)
		pd.stopped.connect(func(val): _on_physics_die_stopped(val, pd))
		physics_dice.append(pd)

func _on_physics_die_stopped(value, pd_node):
	roll_results.append(value)
	
	# [신규] 멈춘 물리 위치를 저장하여 나중에 화면을 다시 열 때 복구 가능하게 함
	dice_manager.last_roll_results.append({
		"sides": pd_node.dice_sides,
		"value": value,
		"is_used": false,
		"position": pd_node.global_position # 물리 위치 저장
	})

	var ui_die = DestinyDieScene.instantiate()
	dice_arena.add_child(ui_die) # Arena 내부에 추가하여 레이아웃 일관성 유지
	ui_die.global_position = pd_node.global_position
	ui_die.setup(pd_node.dice_sides, value)
	arena_ui_dice.append(ui_die)
	
	pd_node.visible = false
	pd_node.queue_free()
	physics_dice.erase(pd_node)

	if physics_dice.is_empty():
		_on_all_dice_stopped()

func _on_all_dice_stopped():
	current_phase = Phase.IDLE

func _on_draw_lines():
	var rect = get_viewport_rect()
	var w = rect.size.x
	var h = rect.size.y
	var color = Color("5d6d7e")
	var width = 2.0
	ui_lines.draw_line(Vector2(0, ZONE_1_H), Vector2(w, ZONE_1_H), color, width)
	ui_lines.draw_line(Vector2(0, h - ZONE_5_H), Vector2(w, h - ZONE_5_H), color, width)
	ui_lines.draw_line(Vector2(ZONE_3_W, ZONE_1_H), Vector2(ZONE_3_W, h - ZONE_5_H), color, width)
	ui_lines.draw_line(Vector2(w - ZONE_4_W, ZONE_1_H), Vector2(w - ZONE_4_W, h - ZONE_5_H), color, width)  

func _on_close_button_pressed():
	if current_phase == Phase.ROLLING:
		_force_finalize_rolls()
	emit_signal("closed")

func _force_finalize_rolls():
	for pd in physics_dice:
		if is_instance_valid(pd):
			var sides = pd.dice_sides if "dice_sides" in pd else 6
			var final_val = randi_range(1, sides)
			dice_manager.last_roll_results.append({
				"sides": sides,
				"value": final_val,
				"is_used": false
			})
			pd.queue_free()
	physics_dice.clear()
	current_phase = Phase.IDLE
