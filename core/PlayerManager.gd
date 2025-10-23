extends Node

@export var player_data: CharacterData # 플레이어의 캐릭터 데이터 리소스

func _ready():
    if player_data == null:
        player_data = load("res://resources/characters/player/Novice.tres")

