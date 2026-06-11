class_name Character
extends CharacterBody2D

signal damage_taken(amount: int, position: Vector2)
signal hit_target(target: Character, damage: int)
signal action_started(stance: Stance)
signal turn_started()

enum Stance { ATTACK, DEFENSE, EVADE }

# Battle variables
var action_gauge: float = 0.0
var target: CharacterBody2D
var ui_manager: Node
var is_in_battle: bool = false
var is_acting: bool = false # 현재 행동 수행 중 여부
var is_selected: bool = false # 현재 선택된 타겟인지 여부
var is_player: bool = false # 플레이어 여부
var is_evading: bool = false # [신규] 회피 상태 여부
var current_stance: Stance = Stance.ATTACK # 현재 스탠스
var active_status_effects: Array[StatusEffect] = [] # 활성 상태 효과
var character_data: CharacterData 
var _stat_signals_connected: bool = false # 스탯 신호 연결 여부
var current_stats: MyCharacterStats # 실제 런타임 스탯 데이터

# [v7.4 육각 그리드 시스템 통합]
var grid_manager: Node # HexGridManager 타입 인식 문제 방지를 위해 Node로 변경
@export var grid_pos: Vector2i:
	set(value):
		# 기존 위치 점유 해제
		if grid_manager and grid_manager.has_method("clear_tile_occupancy"):
			grid_manager.clear_tile_occupancy(grid_pos)
			
		grid_pos = value
		
		if grid_manager:
			# 시각적 위치 동기화
			if grid_manager.has_method("map_to_local"):
				global_position = grid_manager.map_to_local(value)
			# 새로운 위치 점유 설정
			if grid_manager.has_method("set_tile_occupied"):
				grid_manager.set_tile_occupied(value, self)
			
			# [신규] 타일 위 효과 검사
			_check_environmental_hazards()

func _check_environmental_hazards():
	if not grid_manager or not grid_manager.has_method("get_tile_type"): return
	
	# HexGridManager.TileType.TRAP
	var TileType = grid_manager.get("TileType")
	if not TileType: return
	
	var current_tile = grid_manager.get_tile_type(grid_pos)
	if current_tile == TileType.TRAP:
		print(name, " 앗! 함정을 밟았습니다! (", grid_pos, ")")
		# 15 데미지 (가중치를 테스트와 맞춤)
		take_damage(15)
		
		# (추가 기획) 상태 이상 부여 가능
		# var sm = get_node_or_null("/root/StatusManager")
		# if sm: sm.apply_effect(self, "bleed", 3)


@export var move_range: int = 3 # MOV: 이동력 (기본값)
@export var attack_range: int = 1 # RNG: 사거리 (기본값)
var is_pursuit_mode: bool = false # 추격 모드 활성화 여부
signal pursuit_state_changed(is_pursuit: bool) # 게이지 색상 변경 알림용

# 방어구 유형별 장착 정보
var cloth_pieces: int = 0
var light_pieces: int = 0
var heavy_pieces: int = 0

# 상태 이상 관련 변수
var is_vulnerable: bool = false
var vulnerable_timer: float = 0.0

@onready var action_gauge_bar = $ProgressBar
@onready var hp_label = $Label
@onready var hp_bar = get_node_or_null("HPBar")
@onready var mp_label = get_node_or_null("MPLabel")

func initialize(data: CharacterData):
	self.character_data = data
	is_player = (name == "Player")
	
	if data and data.base_stats:
		current_stats = data.base_stats.duplicate(true)
		# 초기화 시점에 파생 스탯(HP/MP) 계산 및 현재치 설정
		current_stats.update_derived_stats()
		print("DEBUG: Character.gd: Stats initialized for ", name)
	else:
		printerr("ERROR: Character.gd: Invalid CharacterData for ", name)

	update_hp_label()

func _ready():
	set_process(true)
	input_pickable = true
	action_gauge = 0.0
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	
	if is_instance_valid(action_gauge_bar):
		action_gauge_bar.position = Vector2(-32, -45)
		# 기본 스타일 생성
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.6, 0.8) # 기본 AP 색상 (파란색 계열)
		action_gauge_bar.add_theme_stylebox_override("fill", style)
	
	if is_instance_valid(hp_label):
		hp_label.position = Vector2(-32, 20)
		
	# 추격 상태 변경 시그널 연결
	if not pursuit_state_changed.is_connected(_on_pursuit_state_changed):
		pursuit_state_changed.connect(_on_pursuit_state_changed)

func _on_pursuit_state_changed(is_pursuit: bool):
	if is_instance_valid(action_gauge_bar):
		var style = action_gauge_bar.get_theme_stylebox("fill")
		if style and style is StyleBoxFlat:
			if is_pursuit:
				style.bg_color = Color(0.8, 0.4, 0.2) # 추격 AP 색상 (주황/빨강 계열)
			else:
				style.bg_color = Color(0.2, 0.6, 0.8) # 기본 AP 색상
			print(name, " AP 게이지 색상 변경: ", "추격(주황)" if is_pursuit else "기본(파랑)")

func _process(delta: float):
	if not current_stats: return
	
	if is_vulnerable:
		vulnerable_timer -= delta
		if vulnerable_timer <= 0:
			is_vulnerable = false
			modulate = Color(1, 1, 1)

	# 마나 재생 (정신 SPI 기반 - StatManager 공식 사용)
	if current_stats:
		var mp_regen_amount = StatManager.get_mp_regen_per_sec(current_stats) * delta 
		var mp_stat = current_stats.get_stat("current_mp")
		if mp_stat and mp_stat.current_value < mp_stat.computed_value:
			var new_mp = float(mp_stat.current_value) + mp_regen_amount
			mp_stat.current_value = int(min(float(mp_stat.computed_value), new_mp))

	var main_hp = current_stats.get_stat("health")
	if main_hp and main_hp.current_value <= 0:
		if is_instance_valid(action_gauge_bar): action_gauge_bar.value = 0
		action_gauge = 0.0
		return
	
	if is_in_battle:
		for effect in active_status_effects:
			if is_instance_valid(effect): effect.update_duration(delta)

		# --- [v7.4 추격 AP 시스템] ---
		var ap_multiplier = 1.0
		var was_pursuit = is_pursuit_mode
		
		if is_instance_valid(target) and target.current_stats.get_stat("health").current_value > 0:
			var dist = get_grid_dist_to(target.grid_pos if "grid_pos" in target else Vector2i.ZERO)
			
			if dist > attack_range:
				# 사거리 밖: 추격 모드 활성화 (1.5배 가속)
				is_pursuit_mode = true
				ap_multiplier = 1.5
			else:
				if is_pursuit_mode:
					# 사거리 진입: 추격 AP 리셋 (v7.4 설계)
					action_gauge = 0.0
					is_pursuit_mode = false
					print(name, ": 사거리 진입으로 인한 AP 초기화")
			
			if was_pursuit != is_pursuit_mode:
				emit_signal("pursuit_state_changed", is_pursuit_mode)

		# 행동 게이지 충전 (공격속도 SPD 기반 - StatManager 공식 사용)
		if target != null and is_instance_valid(target) and target.current_stats.get_stat("health").current_value > 0:
			if current_stance != Stance.DEFENSE and not is_acting:
				var charge_speed = StatManager.get_ap_charge_speed(current_stats)
				
				if GameManager.active_penalties.has("fatigue"):
					charge_speed *= 0.85 
					
				action_gauge += charge_speed * ap_multiplier * delta
			
			if is_instance_valid(action_gauge_bar):
				action_gauge_bar.value = action_gauge

			if current_stance != Stance.DEFENSE and action_gauge >= 100.0:
				if is_pursuit_mode:
					# [피드백 반영] 사거리 밖이면 공격 대신 타일 1칸 이동
					execute_move_step()
				else:
					# 사거리 안이면 기존대로 공격 수행
					perform_stance_action()

func execute_move_step():
	if not target or not grid_manager: return
	
	is_acting = true
	var path = []
	if grid_manager.has_method("get_hex_path"):
		path = grid_manager.get_hex_path(grid_pos, target.get("grid_pos") if target.get("grid_pos") else Vector2i.ZERO)
	
	if path.size() > 1:
		var next_pos = path[1]
		
		# [피드백 반영] 타일 점유(Occupancy) 검사
		var is_occupied = false
		if grid_manager.has_method("is_tile_occupied"):
			is_occupied = grid_manager.is_tile_occupied(next_pos)
			
		if not is_occupied:
			grid_pos = next_pos
			print(name, " 한 칸 이동 -> ", next_pos)
		else:
			print(name, " 이동 대기: 타일이 이미 점유됨 -> ", next_pos)
		
	# 이동 후 AP 게이지 초기화
	action_gauge = 0.0
	is_acting = false

func update_hp_label():
	if not current_stats: return
	
	var hp_stat = current_stats.get_stat("health")
	var mp_stat = current_stats.get_stat("current_mp")
	
	if is_instance_valid(hp_bar) and hp_stat:
		hp_bar.max_value = hp_stat.computed_value
		hp_bar.value = hp_stat.current_value
	
	if is_instance_valid(hp_label) and hp_stat:
		hp_label.text = "HP: %d/%d" % [hp_stat.current_value, hp_stat.computed_value]
		
	if is_instance_valid(mp_label) and mp_stat:
		mp_label.text = "MP: %d/%d" % [mp_stat.current_value, mp_stat.computed_value]

func set_stance(new_stance: Stance):
	current_stance = new_stance
	if new_stance == Stance.DEFENSE and action_gauge >= 15.0:
		perform_stance_action()
	elif action_gauge >= 100.0:
		perform_stance_action()

func perform_stance_action():
	emit_signal("action_started", current_stance)
	match current_stance:
		Stance.ATTACK: perform_attack_action()
		Stance.DEFENSE: perform_defense_action()

func perform_attack_action():
	if target and is_instance_valid(target):
		is_acting = true
		action_gauge = 0.0
		if is_instance_valid(action_gauge_bar): action_gauge_bar.value = 0
		attack(target)
	else:
		action_gauge = 0.0
		finish_action()

var is_guarding: bool = false
var is_perfect_guarding: bool = false

func perform_defense_action():
	var upfront_cost = 15.0
	action_gauge = max(0.0, action_gauge - upfront_cost)
	is_guarding = true
	is_perfect_guarding = false 
	if is_instance_valid(action_gauge_bar): action_gauge_bar.value = action_gauge

func attack(p_target: Character):
	if not current_stats or not is_instance_valid(p_target): return
	
	var base_atk = current_stats.get_stat("atk").computed_value
	var piercing_rate = 0.0
	var true_damage_rate = 0.0
	
	var pier_stat = current_stats.get_stat("piercing")
	if pier_stat: piercing_rate = pier_stat.computed_value
	var true_stat = current_stats.get_stat("true_damage")
	if true_stat: true_damage_rate = true_stat.computed_value
	
	var damage_dealt = p_target.take_damage(base_atk, piercing_rate, true_damage_rate)
	emit_signal("hit_target", p_target, damage_dealt)
	
	if not is_player:
		finish_action()
	else:
		get_tree().create_timer(0.5).timeout.connect(finish_action)

func take_damage(amount: int, piercing_rate: float = 0.0, true_damage_rate: float = 0.0) -> int:
	if not current_stats: return 0

	# 0. 회피/빗겨맞음 (StatManager 공식 사용)
	var evade_chance = StatManager.get_evade_chance(current_stats, light_pieces)
	if randf() * 100.0 < evade_chance:
		# 경갑 보너스에 의한 완전 회피와 AGI에 의한 빗겨맞음(데미지 반감)을 통합 관리하거나 분리 가능
		# 현재는 통합하여 일정 확률로 데미지 무시/반감 처리
		if randf() < 0.5: # 50% 확률로 완전 회피
			emit_signal("damage_taken", 0, global_position)
			return 0
		else: # 50% 확률로 빗겨맞음 (50% 감쇄)
			amount = int(amount * 0.5)

	var true_dmg = int(amount * true_damage_rate)
	var norm_dmg = amount - true_dmg
	var dr_pct = 0.0
	
	# 1. 방어 상태 판정 (StatManager의 PG 임계치 사용)
	if is_guarding:
		var pg_threshold = StatManager.get_pg_ap_threshold(current_stats)
		if action_gauge >= pg_threshold:
			dr_pct = 0.9
			is_perfect_guarding = true
			action_gauge = 50.0 # PG 성공 시 AP 반환
		else:
			dr_pct = 0.5
		is_guarding = false
		current_stance = Stance.ATTACK

	# 2. 방어력 적용 (StatManager 공식 사용)
	var final_dmg = StatManager.calculate_final_damage(norm_dmg, current_stats, piercing_rate)
	final_dmg = int(final_dmg * (1.0 - dr_pct)) + true_dmg
	
	var hp = current_stats.get_stat("health")
	if hp:
		hp.current_value = max(0, hp.current_value - final_dmg)
		emit_signal("damage_taken", final_dmg, global_position)
		update_hp_label()
		if not is_perfect_guarding: _apply_hit_stun(final_dmg)
	
	return final_dmg

func _apply_hit_stun(dmg: int):
	# 피격 경직(AP 차감) 계산: StatManager 공식 사용
	var stun_amount = StatManager.calculate_ap_stun(dmg, current_stats)
	action_gauge = max(0.0, action_gauge - stun_amount)

func finish_action():
	is_acting = false

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		print("DEBUG: Character Input Event - Button Index: ", event.button_index, " on ", name)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_player and is_in_battle:
				print("DEBUG: Target Selected: ", name)
				var gm = get_node_or_null("/root/GameManager")
				if gm and gm.get("battle_manager") and gm.get("battle_manager").has_method("set_player_target"): 
					gm.get("battle_manager").set_player_target(self)
			return # 이벤트 처리 완료 후 종료

		if event.button_index == MOUSE_BUTTON_RIGHT:
			print("DEBUG: Info Popup Requested: ", name)
			var gm = get_node_or_null("/root/GameManager")
			if gm and gm.get("ui_manager") and gm.get("ui_manager").has_method("show_character_info"): 
				gm.get("ui_manager").show_character_info(self)
			return # 이벤트 처리 완료 후 종료

func update_stats_from_player_manager(pm: Node):
	if pm and pm.current_player_stats:
		current_stats.sync_from(pm.current_player_stats)
		if not _stat_signals_connected:
			for s in current_stats.get_all_stats():
				if s: s.value_changed.connect(update_hp_label)
			_stat_signals_connected = true

# [신규] 방어구 유형별 장착 정보 동기화
func sync_armor_profile(armor_counts: Dictionary):
	cloth_pieces = armor_counts.get("cloth", 0)
	light_pieces = armor_counts.get("light", 0)
	heavy_pieces = armor_counts.get("heavy", 0)
	print("DEBUG: Character armor profile synced - C:", cloth_pieces, " L:", light_pieces, " H:", heavy_pieces)

# [신규/복구] 상태 이상 부여 및 저항 로직
func add_status_effect(effect_data: StatusEffectData, duration_override: float = -1.0):
	if not current_stats: return
	
	# 저항 판정 (RES / SPI)
	var resist_chance = 0.0
	if effect_data.is_mental:
		# 정신형 상태이상: 정신(SPI) 1당 저항 확률 1%
		var spi_stat = current_stats.get_stat("spi")
		resist_chance = spi_stat.computed_value if spi_stat else 0.0
	else:
		# 물리형 상태이상: 저항(RES) 1당 저항 확률 1%
		var res_stat = current_stats.get_stat("res")
		resist_chance = res_stat.computed_value if res_stat else 0.0
		
	if randf() * 100.0 < resist_chance:
		print(name, " >>> 상태이상 저항 성공! (", effect_data.effect_name, ") <<<")
		return

	var new_effect = StatusEffect.new()
	new_effect.data = effect_data
	if duration_override > 0:
		new_effect.data.duration = duration_override

	# 중복 효과 갱신 로직
	for i in range(active_status_effects.size()):
		if active_status_effects[i].get_effect_name() == new_effect.get_effect_name():
			active_status_effects[i].remove_effect(self)
			active_status_effects.erase(active_status_effects[i])
			break

	new_effect._time_remaining = new_effect.data.duration
	active_status_effects.append(new_effect)
	new_effect.apply_effect(self)
	print(name, "에게 상태 효과 적용: ", new_effect.get_effect_name())

func remove_status_effect(effect: StatusEffect):
	if active_status_effects.has(effect):
		effect.remove_effect(self)
		active_status_effects.erase(effect)
		print(name, "에게서 상태 효과 제거: ", effect.get_effect_name())

# --- [v7.4 육각 그리드 유틸리티] ---

## 육각 그리드 거리 계산 (Axial distance)
func get_grid_dist_to(target_pos: Vector2i) -> int:
	var d_col = target_pos.x - grid_pos.x
	var d_row = target_pos.y - grid_pos.y
	# 지그재그 그리드에서의 정교한 거리 계산 (v7.4)
	return (abs(d_col) + abs(d_col + d_row) + abs(d_row)) / 2

## 유닛 배치 (배치 페이즈 전용)
func place_at(new_pos: Vector2i) -> bool:
	if not grid_manager: return false
	
	if grid_manager.has_method("is_valid_spawn_zone") and grid_manager.is_valid_spawn_zone(new_pos):
		grid_pos = new_pos
		return true
	return false
