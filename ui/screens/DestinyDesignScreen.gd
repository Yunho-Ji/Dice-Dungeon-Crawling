# DestinyDesignScreen.gd
# 운명 설계 화면: 주사위 굴리기, 스탯 배분, 개발자 도구 포함

extends Control
signal closed

# --- 프리로드 씬 ---
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
var invested_stat_names: Array = [] # [수정] 이번 세션에서 이미 주사위가 투입된 스탯 목록
var charge_power: float = 0.0
var charge_speed: float = 150.0
var charge_direction: int = 1

# --- 레이아웃 상수 ---
const ZONE_1_H = 60
const ZONE_5_H = 60
const ZONE_3_W = 250
const ZONE_4_W = 200

# [수정] 투자 가능한 8종 핵심 스탯 정의 (DDC 리디자인 버전)
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
	
	_setup_physics_walls() # [신규] 코드로 물리 벽 구축
	_initialize_stat_slots()
	_spawn_initial_dice_in_slots()
	_update_exploration_progress() # [신규] 진척도 라벨 업데이트
	
	# [신규] 주사위 굴림 권한에 따른 버튼 가시성 제어
	roll_button.visible = dice_manager.can_roll()
	
	# [신규] 기존에 굴려둔 결과가 있다면 복구
	if not dice_manager.can_roll() and not dice_manager.last_roll_results.is_empty():
		_restore_previous_rolls()

# [신규] 탐험 진척도 표시 업데이트
func _update_exploration_progress():
	var map_manager = get_node_or_null("/root/MapManager")
	if map_manager and map_manager.dungeon_data.has("nodes"):
		var visited = map_manager.player_run_state.VisitedNodeIDs.size()
		var total = map_manager.dungeon_data.nodes.size()
		# 사용자의 요청에 따라 '탐험 진척도' 명칭 사용
		exp_label.text = "탐험 진척도: %d / %d" % [visited, total]
		
		# [보너스] 게이지 바 업데이트
		if total > 0:
			exp_gauge.value = (float(visited) / float(total)) * 100.0
		else:
			exp_gauge.value = 0
	else:
		exp_label.text = "탐험 진척도: 0 / 0"
		exp_gauge.value = 0

func _input(event):
	# --- 개발자 도구: 숫자키로 주사위 즉시 추가 (개발자 모드에서만 작동) ---
	if not game_manager.is_developer_mode: return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
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

# [신규] 아레나 물리 벽 코드로 생성 (안정성 확보)
func _setup_physics_walls():
	var walls_node = get_node_or_null("DiceArena/Walls")
	if not walls_node: return
	
	# 기존 자식 제거 (중복 생성 방지)
	for child in walls_node.get_children():
		child.queue_free()
	
	# 4방향 벽 설정 데이터
	# 상(60), 하(588), 좌(250), 우(952) 경계에 정확히 맞춤
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
	
	print("DestinyDesignScreen: 물리 아레나 벽이 코드로 생성되었습니다.")

# 모든 스탯 슬롯 초기화 (8종류 전체 자동 로드)
func _initialize_stat_slots():
	for child in stat_slots_container.get_children():
		child.queue_free()
		
	var stats_obj = null
	if game_manager.player_node and game_manager.player_node.current_stats:
		stats_obj = game_manager.player_node.current_stats
	else:
		# [신규] 마을 등 캐릭터 노드가 없는 환경에서의 폴백
		var pm = get_node_or_null("/root/PlayerManager")
		if pm and pm.current_player_stats:
			stats_obj = pm.current_player_stats
			print("DestinyDesignScreen: PlayerManager의 세션 스탯을 참조합니다.")

	if stats_obj:
		# [수정] 모든 스탯이 아닌, INVESTABLE_STATS에 정의된 8종만 노출합니다.
		for s_name in INVESTABLE_STATS:
			var stat_res = stats_obj.get_stat(s_name)
			if stat_res:
				var slot = StatSlotScene.instantiate()
				stat_slots_container.add_child(slot)
				slot.set_stat(s_name, stat_res)

# 주사위 슬롯 초기화
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
		
		# [신규] 슬롯의 주사위 클릭 시 재굴림 기능 연결
		die.gui_input.connect(_on_slot_dice_input.bind(die))
		dice_instances.append(die)

# 슬롯의 주사위를 클릭했을 때 재굴림 처리
func _on_slot_dice_input(event, die_node):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 주사위가 아직 굴려지지 않은 상태(modulate.a == 1.0이고 굴리기 전) 혹은 특정 조건에서만 재굴림 허용
		# 현재는 '이미 굴려진 결과물'과 '굴리기 전 슬롯'이 섞여있어 혼동이 올 수 있음.
		# 단순 클릭만으로는 재굴림되지 않도록 주석 처리하거나 조건을 엄격하게 변경.
		if current_phase == Phase.IDLE and dice_manager.can_roll() and die_node.modulate.a == 1.0:
			# reroll_dice(die_node) # 의도치 않은 재굴림 방지를 위해 일단 비활성화 (드래그 앤 드롭에 집중)
			pass

# 단일 주사위 재굴림 로직 (Zone 4 -> Zone 2)
func reroll_dice(die_node):
	print("재굴림 시작: D", die_node.dice_sides)
	
	# 1. DiceManager에서 해당 주사위의 '사용됨' 상태 해제
	# 결과값이 0인 초기 상태 주사위라면 굴림 결과에서 찾는 대신 굴리기 권한만 확인
	# 여기서는 이미 굴려진 뒤 슬롯에 '결과'로 남은 주사위를 다시 굴린다고 가정 (0.3 투명도)
	
	# 2. 아레나에 물리 주사위 생성 및 발사
	var rect = get_viewport_rect()
	var arena_center = Vector2((ZONE_3_W + (rect.size.x - ZONE_4_W)) / 2, (ZONE_1_H + (rect.size.y - ZONE_5_H)) / 2)
	
	var pd = PhysicsDieScene.instantiate()
	dice_arena.add_child(pd)
	pd.setup(die_node.dice_sides)
	pd.global_position = arena_center + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	
	# 랜덤한 방향으로 발사
	var dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	# [수정] 재굴림 파워 0~100 스케일로 조정 (중간 힘 50.0)
	pd.launch(dir, 50.0) 
	
	pd.stopped.connect(func(val): _on_physics_die_stopped(val, pd))
	physics_dice.append(pd)
	
	# 3. 슬롯 주사위 시각 효과 (완전 투명화 등)
	die_node.modulate.a = 0.1 # 재굴림 중임을 표시

func _can_start_rolling() -> bool:
	# DiceManager의 권한 확인 및 아레나가 비어있는지 확인
	return current_phase == Phase.IDLE and dice_manager.can_roll() and not dice_instances.is_empty() and physics_dice.is_empty() and arena_ui_dice.is_empty()

func _restore_previous_rolls():
	# 기존 슬롯 반투명화
	for die in dice_instances:
		die.modulate.a = 0.3
	
	var rect = get_viewport_rect()
	var arena_center = Vector2((ZONE_3_W + (rect.size.x - ZONE_4_W)) / 2, (ZONE_1_H + (rect.size.y - ZONE_5_H)) / 2)
	
	for res in dice_manager.last_roll_results:
		# [수정] 사용하지 않은 주사위만 복구
		if not res.get("is_used", false):
			var ui_die = DestinyDieScene.instantiate()
			add_child(ui_die)
			# 랜덤 위치에 복구
			ui_die.global_position = arena_center + Vector2(randf_range(-100, 100), randf_range(-100, 100))
			ui_die.setup(res.sides, res.value)
			arena_ui_dice.append(ui_die)
	
	current_phase = Phase.IDLE

func _start_charging():
	current_phase = Phase.CHARGING
	power_gauge.visible = true
	charge_power = 0.0
	charge_direction = 1

# 주사위 발사 및 권한 소모
func _launch_dice():
	current_phase = Phase.ROLLING
	power_gauge.visible = false
	roll_button.visible = false # [신규] 발사 즉시 버튼 숨김
	invested_stat_names.clear() # [수정] 새로운 굴림 세션 시작 시 투자 목록 초기화
	
	# [수정] 스탯은 누적 성장하는 개념이므로, 기존 보너스를 삭제(remove_all_modifiers)하지 않습니다.
	# 대신 주사위 사용 상태만 초기화하여 새로운 주사위를 배치할 준비를 합니다.
	dice_manager.reset_all_dice_usage()
	
	# DiceManager의 권한 소모
	dice_manager.can_roll_new_dice = false
	dice_manager.last_roll_results.clear()
	
	# 기존 객체 청소
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
		
		# [수정] 생성 위치를 중앙에 더 밀집시킴 (Y축 범위 축소)
		pd.global_position = arena_center + Vector2(randf_range(-100, 100), randf_range(-50, 50))
		
		var angle = randf_range(-PI/4, PI/4) - PI/2
		var dir = Vector2.RIGHT.rotated(angle)
		
		# [수정] 복잡한 연산 제거, 게이지 값(0~100) 그대로 전달
		print("DEBUG: Launching dice with charge: ", charge_power)
		pd.launch(dir, charge_power)
		
		pd.stopped.connect(func(val): _on_physics_die_stopped(val, pd))
		physics_dice.append(pd)

# 물리 주사위가 멈추면 UI 주사위로 즉시 교체 (Swap) 및 결과 저장
func _on_physics_die_stopped(value, pd_node):
	roll_results.append(value)
	
	# [수정] DiceManager에 상태값과 함께 결과 저장
	dice_manager.last_roll_results.append({
		"sides": pd_node.dice_sides, 
		"value": value,
		"is_used": false
	})
	
	# 멈춘 위치에 상호작용 가능한 UI 주사위 생성
	var ui_die = DestinyDieScene.instantiate()
	add_child(ui_die)
	ui_die.global_position = pd_node.global_position - Vector2(32, 32)
	ui_die.setup(pd_node.dice_sides, value)
	arena_ui_dice.append(ui_die)
	
	# [수정] 고스트 현상 방지: 삭제 대기(queue_free) 중에도 보이지 않도록 즉시 가시성 OFF
	pd_node.visible = false
	pd_node.queue_free()
	physics_dice.erase(pd_node)
	
	if roll_results.size() == (physics_dice.size() + arena_ui_dice.size()):
		_on_all_dice_stopped()

func _on_all_dice_stopped():
	current_phase = Phase.REVEAL
	print("모든 주사위가 UI 객체로 교체되었습니다. 드래그 배분이 가능합니다.")
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
	# [수정] 주사위가 굴러가는 중(ROLLING)에 닫을 경우, 결과를 강제로 확정하여 증발 방지
	if current_phase == Phase.ROLLING:
		_force_finalize_rolls()
	emit_signal("closed")

# [신규] 굴림 강제 종료 및 결과 저장 (닫기 버튼 대응)
func _force_finalize_rolls():
	print("DestinyDesignScreen: 화면이 닫히기 전 주사위 결과를 강제 확정합니다.")
	# 아직 멈추지 않은 물리 주사위들에 대해 랜덤 결과 생성하여 DiceManager에 보존
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
	# 이미 멈춰서 UI로 바뀐 주사위들은 on_physics_die_stopped에서 이미 DiceManager에 추가됨
	current_phase = Phase.IDLE
