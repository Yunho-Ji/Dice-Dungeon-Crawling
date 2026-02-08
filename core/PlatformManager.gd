extends Node

# PlatformManager
# 역할: 실행 환경(Steam, itch.io, Debug)을 감지하고 플랫폼별 기능(도전과제, 클라우드)을 추상화합니다.

enum Platform { EDITOR, STEAM, ITCH_WEB, ITCH_DESKTOP }
var current_platform = Platform.EDITOR

func _ready():
	_detect_platform()

func _detect_platform():
	if OS.has_feature("steam"):
		current_platform = Platform.STEAM
		_init_steam()
	elif OS.has_feature("web"):
		current_platform = Platform.ITCH_WEB
	else:
		current_platform = Platform.EDITOR

func _init_steam():
	# GodotSteam 초기화 로직
	pass

func unlock_achievement(api_name: String):
	if current_platform == Platform.STEAM:
		# Steam.setAchievement(api_name)
		pass
	else:
		print("PlatformManager: Achievement unlocked (Mock) - ", api_name)
