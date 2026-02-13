# test_MultiEnemyAttack.gd
extends "res://addons/gut/test.gd"

var EnemyScene = load("res://characters/enemy/Enemy.tscn")
var PlayerScene = load("res://characters/player/novice/Novice.tscn")
var CharacterDataClass = load("res://resources/character_data/CharacterData.gd")
var MyCharacterStatsClass = load("res://resources/stats/MyCharacterStats.gd")

func test_multiple_enemies_increase_gauge_and_attack():
	# 1. Setup Player
	var player = PlayerScene.instantiate()
	player.name = "Player"
	var player_data = CharacterDataClass.new()
	player_data.character_name = "Hero"
	player_data.base_stats = MyCharacterStatsClass.new()
	player_data.base_stats.health.base_value = 100
	player_data.base_stats.health.current_value = 100
	player_data.base_stats.attack_speed.base_value = 50
	player.initialize(player_data)
	player.current_stats.get_stat("health").current_value = 100 # Ensure health is set
	add_child(player)
	
	# 2. Setup multiple enemies
	var enemies = []
	for i in range(2):
		var enemy = EnemyScene.instantiate()
		enemy.name = "Enemy_" + str(i)
		var enemy_data = CharacterDataClass.new()
		enemy_data.character_name = "Goblin"
		enemy_data.base_stats = MyCharacterStatsClass.new()
		enemy_data.base_stats.health.base_value = 50
		enemy_data.base_stats.health.current_value = 50
		enemy_data.base_stats.attack_power.base_value = 5
		enemy_data.base_stats.attack_speed.base_value = 100
		enemy.initialize(enemy_data)
		enemy.current_stats.get_stat("health").current_value = 50 # Ensure health is set
		enemy.target = player
		enemy.is_in_battle = true
		add_child(enemy)
		enemies.append(enemy)

	# 3. Simulate time (0.5s)
	for enemy in enemies:
		enemy._process(0.5)
	
	for i in range(enemies.size()):
		assert_eq(enemies[i].action_gauge, 50.0, "Enemy " + str(i) + " gauge should be 50.0")
		assert_false(enemies[i].is_acting, "Enemy " + str(i) + " should not be acting yet")

	# 4. Simulate more time (0.6s) -> Total 1.1s
	for enemy in enemies:
		enemy._process(0.6)
	
	assert_eq(enemies[0].action_gauge, 0.0, "Enemy 0 should have attacked and reset gauge")
	assert_eq(enemies[1].action_gauge, 0.0, "Enemy 1 should have attacked and reset gauge")
	assert_false(enemies[0].is_acting, "Enemy 0 should have finished acting")
	assert_false(enemies[1].is_acting, "Enemy 1 should have finished acting")
	
	# Player health: 100 - (5 * 2) = 90
	assert_eq(player.current_stats.get_stat("health").current_value, 90, "Player health should be 90 after 2 enemy attacks")

	# Clean up
	player.free()
	for enemy in enemies:
		enemy.free()
