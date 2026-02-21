extends Resource
class_name NPCData

enum FunctionType {
	TALK,       # 일반 대화 (추가 대사 출력)
	SHOP,       # 상점 이용
	REST,       # 여관 휴식
	SAVE,       # 저장만 하기
	ENCHANT,    # 강화 (EnchantScreen)
	REPAIR,     # 수리 (미구현)
	QUEST,      # 퀘스트 확인 (미구현)
	EXIT        # 대화 종료
}

@export var npc_name: String = "Unknown NPC"
@export var portrait_path: String = "" # 초상화 경로 (동적 로드용)
@export_multiline var greetings: Array[String] = ["어서 오게."] # 입장 시 대사
@export_multiline var talk_lines: Array[String] = ["요즘 날씨가 좋군."] # [대화하기] 선택 시 대사

# 선택지 목록 설정 (Inspector에서 편집 가능)
# 구조: { "text": "버튼 텍스트", "type": FunctionType (int), "param": "추가 파라미터(옵션)" }
@export var options: Array[Dictionary] = []

func get_random_greeting() -> String:
	if greetings.is_empty(): return "..."
	return greetings.pick_random()

func get_random_talk() -> String:
	if talk_lines.is_empty(): return "..."
	return talk_lines.pick_random()
