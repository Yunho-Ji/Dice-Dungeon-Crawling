extends "res://addons/gut/test.gd"

# Combat AI Behavior Test & Simulation
# 목표: 플레이어 및 적 개체의 AI 패턴 알고리즘 설계 및 검증

var CharacterClass = load("res://characters/Character.gd")
var player: Character = null
var enemy: Character = null

func before_each():
	# 플레이어 설정
	player = CharacterClass.new()
	player.name = "Player"
	_setup_dummy_nodes(player)
	_setup_default_stats(player)
	player.is_player = true
	
	# 적 설정
	enemy = CharacterClass.new()
	enemy.name = "Enemy"
	_setup_dummy_nodes(enemy)
	_setup_default_stats(enemy)
	enemy.is_player = false
	
	player.target = enemy
	enemy.target = player
	
	player.is_in_battle = true
	enemy.is_in_battle = true

func _setup_dummy_nodes(c):
	var pb = ProgressBar.new()
	pb.name = "ProgressBar"
	c.add_child(pb)
	var lb = Label.new()
	lb.name = "Label"
	c.add_child(lb)

func _setup_default_stats(c):
	var stats = MyCharacterStats.new()
	stats.health.base_value = 100
	stats.health.current_value = 100
	stats.attack_power.base_value = 10
	stats.speed.base_value = 100 # AP 충전 속도 관련
	c.current_stats = stats

func after_each():
	player.free()
	enemy.free()

# --- AI 패턴 알고리즘 설계 (테스트 케이스 내 가상 구현) ---

# 1. 적 AI: 체력 상황에 따른 스탠스 전환 테스트
func test_enemy_defensive_behavior_on_low_hp():
	# 적 HP를 낮게 설정
	enemy.current_stats.get_stat("health").current_value = 20 
	
	# 가상의 AI 로직 수행 (패턴 설계)
	# 알고리즘: HP < 30% 이면 공격보다 방어/회피 선호
	var decided_stance = _simulate_ai_decision(enemy)
	
	assert_eq(decided_stance, Character.Stance.DEFENSE, "체력이 낮을 때 적은 방어 스탠스를 취해야 함")

# 2. 플레이어 AI: 타겟 취약 상태 시 집중 공격 테스트
func test_player_aggression_on_vulnerable_target():
	enemy.is_vulnerable = true
	
	# 가상의 AI 로직 수행
	# 알고리즘: 타겟이 Vulnerable 상태이면 공격 스탠스 유지 및 강력한 공격 준비
	var decided_stance = _simulate_ai_decision(player)
	
	assert_eq(decided_stance, Character.Stance.ATTACK, "타겟이 취약할 때 플레이어 AI는 공격을 우선시해야 함")

# 3. AP 충전 및 행동 시점 시뮬레이션
func test_combat_loop_simulation():
	# 5초간 전투 시뮬레이션 (delta = 0.1s)
	var time_elapsed = 0.0
	var player_actions = 0
	var enemy_actions = 0
	
	for i in range(50):
		var delta = 0.1
		time_elapsed += delta
		
		# AI 의사 결정 업데이트 (매 프레임 혹은 특정 주기)
		_update_ai(player, delta)
		_update_ai(enemy, delta)
		
		# Character.gd의 _process와 유사한 게이지 충전 로직 수행
		_simulate_process(player, delta)
		_simulate_process(enemy, delta)
		
		if player.action_gauge >= 100.0:
			player_actions += 1
			player.action_gauge = 0.0 # 행동 완료 후 초기화
			
		if enemy.action_gauge >= 100.0:
			enemy_actions += 1
			enemy.action_gauge = 0.0
			
	print("Combat Sim (5s): Player Actions: ", player_actions, " / Enemy Actions: ", enemy_actions)
	assert_gt(player_actions, 0, "플레이어는 최소 1번 이상 행동해야 함")
	assert_gt(enemy_actions, 0, "적은 최소 1번 이상 행동해야 함")

# --- 내부 헬퍼 함수 (AI 설계용) ---

func _simulate_ai_decision(c: Character) -> int:
	var hp_pct = float(c.current_stats.get_stat("health").current_value) / c.current_stats.get_stat("health").computed_value
	
	# 1. 생존 우선 순위
	if hp_pct < 0.3:
		return Character.Stance.DEFENSE
	
	# 2. 타겟 상태 확인
	if c.target and c.target.is_vulnerable:
		return Character.Stance.ATTACK
		
	# 기본값
	return Character.Stance.ATTACK

func _update_ai(c: Character, _delta: float):
	# 현재 상황에 맞는 최적의 스탠스 설정
	var next_stance = _simulate_ai_decision(c)
	if c.current_stance != next_stance:
		c.set_stance(next_stance)

func _simulate_process(c: Character, delta: float):
	# Character.gd의 실제 로직을 모방 (게이지 충전)
	var spd = c.current_stats.get_stat("speed").computed_value
	var charge_speed = spd * 0.1 # 가상의 공식
	c.action_gauge += charge_speed * delta
