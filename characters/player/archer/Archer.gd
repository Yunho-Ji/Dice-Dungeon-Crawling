extends Player

@onready var animated_sprite_2d = $AnimatedSprite2D

var Atk01_Fx_Scene = preload("res://characters/player/archer/Fx/archer_atk_01_fx.tscn")

const IMPACT_FRAME = 4

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
	print(name, "가 ", target_node.name, "에게 공격합니다! 공격력: ", attack_power)

	if animated_sprite_2d:
		animated_sprite_2d.play("Attack01")
	else:
		printerr("Archer: ERROR - animated_sprite_2d is not valid when attacking!")

func _on_frame_changed():
	# "Attack01" 애니메이션의 특정 프레임에서 한 번만 데미지와 FX를 적용
	if animated_sprite_2d.animation == "Attack01" and animated_sprite_2d.frame == IMPACT_FRAME and not _attack_committed:
		_attack_committed = true

		if not is_in_battle: return

		# FX 인스턴스화 및 추가
		var fx_instance = Atk01_Fx_Scene.instantiate()
		get_parent().add_child(fx_instance)
		fx_instance.global_position = global_position

		# 데미지 적용
		if is_instance_valid(target):
			target.take_damage(attack_power)
		else:
			print("Archer: 공격 대상이 유효하지 않습니다.")

func _on_animation_finished():
	if animated_sprite_2d.animation == "Attack01":
		animated_sprite_2d.play("Idle")
		
		if not is_in_battle: return

		print("아처 공격 애니메이션 완료, Idle로 전환 및 게이지 초기화")
	super._on_animation_finished()

func _on_visibility_changed():
	# Archer 고유의 가시성 변경 로직이 있다면 여기에 추가
	super._on_visibility_changed()
