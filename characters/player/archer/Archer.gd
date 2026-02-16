extends Player

@onready var animated_sprite_2d = $AnimatedSprite2D

var Atk01_Fx_Scene = preload("res://characters/player/archer/Fx/archer_atk_01_fx.tscn")
var Arrow_Data = preload("res://resources/combat/ArcherArrowData.tres")

const IMPACT_FRAME = 6

func _ready():
	if animated_sprite_2d:
		animated_sprite_2d.visible = true
		animated_sprite_2d.play("Idle") # Play placeholder Idle animation
		animated_sprite_2d.animation_finished.connect(_on_animation_finished)
		animated_sprite_2d.frame_changed.connect(_on_frame_changed)
	else:
		printerr("Archer: ERROR - animated_sprite_2d is not valid!")
	super._ready()

func attack(target_node: CharacterBody2D):
	super.attack(target_node) # Reset the _attack_committed flag in the parent
	print(name, "가 ", target_node.name, "에게 공격합니다! 공격력: ", current_stats.get_stat("attack_power").computed_value)

	if animated_sprite_2d:
		animated_sprite_2d.play("Attack01")
	else:
		printerr("Archer: ERROR - animated_sprite_2d is not valid when attacking!")

func _on_frame_changed():
	# "Attack01" 애니메이션의 특정 프레임에서 한 번만 데미지와 FX를 적용
	if animated_sprite_2d.animation == "Attack01" and animated_sprite_2d.frame == IMPACT_FRAME and not _attack_committed:
		_attack_committed = true

		if not is_in_battle: return

		var fx_spawn_point = $Atk01FxSpawnPoint
		var spawn_pos = fx_spawn_point.global_position if fx_spawn_point else global_position
		var target_pos = target.global_position + Vector2(0, -30) if is_instance_valid(target) else global_position

		# 1. 투사체(화살) 발사
		if is_instance_valid(target):
			if has_node("/root/ProjectileManager"):
				get_node("/root/ProjectileManager").launch_projectile(
					Arrow_Data, 
					spawn_pos, 
					target, 
					current_stats.get_stat("attack_power").computed_value, 
					self
				)
				print("Archer: 화살 발사! (위치: ", spawn_pos, ")")
			else:
				printerr("Archer: ProjectileManager를 찾을 수 없습니다!")
		else:
			print("Archer: 공격 대상이 유효하지 않아 화살을 발사할 수 없습니다.")

		# 2. FX 인스턴스화 및 추가 (활 쏘는 이펙트)
		var fx_instance = Atk01_Fx_Scene.instantiate()
		get_parent().add_child(fx_instance)
		fx_instance.global_position = spawn_pos
		
		# FX를 타겟 방향으로 회전 (화살의 궤적과 일치시킴)
		if is_instance_valid(target):
			fx_instance.rotation = (target_pos - spawn_pos).angle()

func _on_animation_finished():
	if animated_sprite_2d.animation == "Attack01":
		animated_sprite_2d.play("Idle")
		
		# [수정] 전투 종료 직후라도 플래그는 반드시 해제해야 다음 전투가 정상 작동함
		finish_action()
		
		if not is_in_battle: return
		print("아처 공격 애니메이션 완료, Idle로 전환 및 게이지 획득 재개")
	super._on_animation_finished()

func _on_visibility_changed():
	# Archer 고유의 가시성 변경 로직이 있다면 여기에 추가
	super._on_visibility_changed()