extends Node

enum PlatformType { EDITOR, STEAM, ITCH_WEB, ITCH_DESKTOP }
var current_platform = PlatformType.EDITOR

# Steam 관련 데이터
var is_steam_running: bool = false
var steam_id: int = 0
var steam_username: String = "Guest"
var steam_api = null

func _ready():
	randomize() # 난수 시드 초기화 (UUID 무작위성 보장)
	_detect_platform()

func _process(_delta):
	if is_steam_running and steam_api:
		steam_api.run_callbacks()

func _detect_platform():
	if Engine.has_singleton("Steam"):
		steam_api = Engine.get_singleton("Steam")
		var init_result = steam_api.steamInit()
		if typeof(init_result) == TYPE_DICTIONARY and init_result.get("status") == 1:
			print("PlatformManager: Steam initialized successfully.")
			current_platform = PlatformType.STEAM
			_init_steam_data()
		else:
			print("PlatformManager: Steam failed to initialize.")
			current_platform = PlatformType.EDITOR
	else:
		if OS.has_feature("web"):
			current_platform = PlatformType.ITCH_WEB
		else:
			current_platform = PlatformType.EDITOR
	
	print("PlatformManager: Current platform set to ", get_platform_name())

func _init_steam_data():
	if not steam_api: return
	is_steam_running = true
	steam_id = steam_api.getSteamID()
	steam_username = steam_api.getPersonaName()
	print("PlatformManager: Steam User: ", steam_username, " (", steam_id, ")")

func get_steam_id() -> int:
	return steam_id

func get_username() -> String:
	return steam_username

func get_platform_name() -> String:
	match current_platform:
		PlatformType.EDITOR: return "EDITOR"
		PlatformType.STEAM: return "STEAM"
		PlatformType.ITCH_WEB: return "ITCH_WEB"
		PlatformType.ITCH_DESKTOP: return "ITCH_DESKTOP"
	return "UNKNOWN"

# --- Steam Cloud (Remote Storage) ---

## 클라우드 저장 기능 활성화 여부 확인
func is_cloud_enabled() -> bool:
	if current_platform == PlatformType.STEAM and steam_api:
		return steam_api.isCloudEnabledForAccount() and steam_api.isCloudEnabledForApp()
	return false

## 파일을 Steam Cloud에 저장
func cloud_save_file(file_name: String, content: String) -> bool:
	if not is_cloud_enabled(): return false
	
	var buffer = content.to_utf8_buffer()
	var success = steam_api.fileWrite(file_name, buffer, buffer.size())
	if success:
		print("PlatformManager: File synced to Steam Cloud: ", file_name)
	return success

## Steam Cloud에서 파일 로드
func cloud_load_file(file_name: String) -> String:
	if not is_cloud_enabled(): return ""
	
	if steam_api.fileExists(file_name):
		var size = steam_api.getFileSize(file_name)
		var result = steam_api.fileRead(file_name, size)
		if result.has("buf"):
			return result["buf"].get_string_from_utf8()
	return ""

# --- 비동기 멀티플레이 대응을 위한 유틸리티 ---

## 고유 식별자(UUID) 생성
func generate_uuid() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var uuid = ""
	for i in range(16):
		uuid += chars[randi() % chars.length()]
	
	if steam_id != 0:
		return str(steam_id) + "_" + uuid
	return uuid

func unlock_achievement(api_name: String):
	if current_platform == PlatformType.STEAM and steam_api:
		steam_api.setAchievement(api_name)
		steam_api.storeStats()
		print("PlatformManager: Steam Achievement unlocked - ", api_name)
	else:
		print("PlatformManager: Achievement unlocked (Mock) - ", api_name)
