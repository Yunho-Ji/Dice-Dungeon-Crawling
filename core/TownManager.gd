extends Node
class_name TownManager

signal time_updated(current_time_string: String)
signal penalties_applied(penalty_type: String)
signal multiple_enemies_penalty_applied()
signal stronger_enemies_penalty_applied()
signal town_closing_time_reached()

# 마을 시간 관리 (분 단위로 관리)
# AM 9:00 = 0분
# 1회 AM 11:00 = 120분
# 2회 PM 14:00 = 300분
# 3회 PM 17:00 = 480분
# 4회 PM 20:00 = 660분
# 5회 PM 23:00 = 840분

const TIME_MILESTONES_MINUTES = [
	540,  # AM 9:00 (Initial)
	660,  # AM 11:00 (1st visit)
	840,  # PM 14:00 (2nd visit)
	1020, # PM 17:00 (3rd visit)
	1200, # PM 20:00 (4th visit)
	1380  # PM 23:00 (5th visit)
]

const PENALTY_TIME_1_MINUTES = 1080 # PM 18:00 (18 * 60)
const PENALTY_TIME_2_MINUTES = 1200 # PM 20:00 (20 * 60)
const RETURN_TIME_MINUTES = 1380 # PM 23:00 (23 * 60)
const RESET_TIME_MINUTES = 660 # AM 11:00 (11 * 60)

var current_time_index: int = 0 # Index into TIME_MILESTONES_MINUTES
var current_time_minutes: int # Will be updated based on current_time_index

func _ready():
	_update_current_time_from_index()
	update_time_display()

func _update_current_time_from_index():
	current_time_minutes = TIME_MILESTONES_MINUTES[current_time_index]

func advance_time_to_next_milestone():
	if current_time_index < TIME_MILESTONES_MINUTES.size() - 1:
		current_time_index += 1
		_update_current_time_from_index()
		update_time_display()
		check_dungeon_penalties()
	else:
		print("마을 시간: 더 이상 진행할 수 있는 시간이 없습니다. (최대치 도달)")

func set_time_by_minutes(minutes: int):
	current_time_minutes = minutes
	# Find the closest milestone index for consistency, or reset index
	var closest_index = 0
	for i in range(TIME_MILESTONES_MINUTES.size()):
		if minutes >= TIME_MILESTONES_MINUTES[i]:
			closest_index = i
		else:
			break
	current_time_index = closest_index
	update_time_display()
	check_dungeon_penalties()

func get_current_time_string() -> String:
	var hours = current_time_minutes / 60
	var minutes = current_time_minutes % 60
	var am_pm = "AM"
	if hours >= 12:
		am_pm = "PM"
		if hours > 12:
			hours -= 12
	if hours == 0: # 00:xx should be 12:xx AM
		hours = 12
	
	return "%s %02d:%02d" % [am_pm, hours, minutes]

func update_time_display():
	emit_signal("time_updated", get_current_time_string())

func check_dungeon_penalties():
	if current_time_minutes >= PENALTY_TIME_1_MINUTES: # PM 18:00
		emit_signal("penalties_applied", "fatigue")
		print("패널티 적용: 피로 (행동게이지속도 -15%)")
	if current_time_minutes >= PENALTY_TIME_2_MINUTES: # PM 20:00
		emit_signal("multiple_enemies_penalty_applied")
		emit_signal("stronger_enemies_penalty_applied")
		print("패널티 적용: 복수/강력한 적 출현 확률 증가")
	if current_time_minutes >= RETURN_TIME_MINUTES: # PM 23:00
		emit_signal("town_closing_time_reached")
		print("마을 마감 시간: 여관을 제외한 모든 장소 폐쇄")

func get_current_time_minutes() -> int:
	return current_time_minutes
