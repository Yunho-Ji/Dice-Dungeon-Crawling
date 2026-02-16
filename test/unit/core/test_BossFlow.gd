# test_BossFlow.gd
# 보스 클리어 후 흐름(루팅 보장, 추가 탐험 위치 초기화)을 검증하는 테스트
extends "res://addons/gut/test.gd"

var GameManagerClass = load("res://core/GameManager.gd")
var MapManagerClass = load("res://core/MapManager.gd")
var DungeonNodeClass = load("res://core/dungeon/DungeonNode.gd")

var game_manager
var map_manager

func before_each():
	game_manager = GameManagerClass.new()
	map_manager = MapManagerClass.new()
	
	# 상호 참조 연결
	map_manager.game_manager = game_manager
	game_manager.ui_manager = Node.new() # 최소한의 더미 UI 매니저
	
	# 필요한 자식 노드 모킹 (에러 방지)
	var dice_mgr = Node.new()
	dice_mgr.name = "DiceManager"
	get_tree().root.add_child(dice_mgr)
	
	add_child(game_manager)
	add_child(map_manager)

func after_each():
	game_manager.free()
	map_manager.free()
	if get_tree().root.has_node("DiceManager"):
		get_tree().root.get_node("DiceManager").free()

# --------------------------------------------------------------------------
# 1. 보스전 승리 후 루팅 기회 보장 테스트
# --------------------------------------------------------------------------
func test_boss_victory_loot_opportunity():
	# 준비: 보스 노드 설정
	var boss_node = DungeonNodeClass.new("boss_01", "boss", 5)
	game_manager.current_battle_node_type = "boss"
	game_manager.current_dungeon_node = boss_node
	game_manager.selected_dungeon_id = 1
	
	# 던전 데이터 모킹
	map_manager.dungeon_data = {
		"nodes": { "boss_01": boss_node },
		"num_layers": 6
	}
	
	# 실행: 전투 승리 처리 (상자 스폰 안 함 옵션으로 테스트)
	game_manager.handle_battle_end(true, false)
	
	# 검증: CurrentNodeID가 보스 노드로 갱신되었는지 확인 (clear_node 호출 확인)
	assert_eq(map_manager.player_run_state.CurrentNodeID, "boss_01", "승리 후 현재 위치가 보스 노드로 기록되어야 함")
	
	# 검증: [핵심] 종료 화면(End of Dungeon)이 즉시 뜨지 않았는지 간접 확인
	# 현재는 루팅을 위해 대기 상태를 유지해야 함
	assert_eq(game_manager.current_game_phase, game_manager.GamePhase.BATTLE_END, "상태는 BATTLE_END여야 함")

# --------------------------------------------------------------------------
# 2. 추가 탐험 시 시작 위치 초기화 테스트
# --------------------------------------------------------------------------
func test_additional_exploration_position_reset():
	# 준비: 보스 클리어 후 상태 모킹
	var start_node = DungeonNodeClass.new("start_01", "start", 0)
	var boss_node = DungeonNodeClass.new("boss_01", "boss", 5)
	
	map_manager.dungeon_data = {
		"nodes": {
			"start_01": start_node,
			"boss_01": boss_node
		},
		"num_layers": 6
	}
	
	# 플레이어가 보스 방에 있는 상태에서 추가 탐험 결정
	map_manager.player_run_state.CurrentNodeID = "boss_01"
	game_manager.handle_additional_exploration()
	
	assert_true(game_manager.is_additional_exploration_mode, "추가 탐험 모드 플래그가 설정되어야 함")
	
	# 실행: MapManager의 던전 재구성 로직 호출
	map_manager.generate_dungeon_if_needed()
	
	# 검증: [핵심] 플레이어 위치가 다시 입구(start)로 돌아왔는지 확인
	assert_eq(map_manager.player_run_state.CurrentNodeID, "start_01", "추가 탐험 시작 시 위치는 반드시 시작 노드여야 함")
	assert_eq(map_manager.player_run_state.CurrentDepth, 0, "현재 깊이도 0으로 초기화되어야 함")
	assert_true(map_manager.player_run_state.VisitedNodeIDs.has("start_01"), "시작 노드는 방문 목록에 포함되어야 함")
