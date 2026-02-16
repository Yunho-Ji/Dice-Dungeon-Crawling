class_name ProjectileData
extends Resource

@export var name: String = "Default Arrow"
@export var projectile_scene: PackedScene
@export var speed: float = 800.0
@export var damage_multiplier: float = 1.0
@export var impact_vfx: PackedScene
@export var impact_sfx: AudioStream
@export var launch_sfx: AudioStream
