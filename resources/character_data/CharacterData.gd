extends Resource
class_name CharacterData

@export var uid: String = "" # 비동기 멀티플레이 및 세이브 식별을 위한 고유 ID
@export var character_name: String = ""
@export var character_scene: PackedScene # [신규] 캐릭터 실제 씬 리소스
@export var base_stats: MyCharacterStats
