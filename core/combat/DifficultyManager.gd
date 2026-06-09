extends Node

# DifficultyManager (구 LevelManager)
# 역할: 시간 경과, 회차 진행, 던전 깊이에 따른 전역 난이도 스케일링을 관리합니다.
# Godot의 Curve 리소스를 사용하여 비선형적인 난이도 조절을 지원합니다.

@export var difficulty_curve: Curve
var current_difficulty_factor: float = 1.0

func update_difficulty(time_elapsed: float, depth: int):
	# 커브가 있다면 커브 기반 계산, 없다면 선형 계산
	if difficulty_curve:
		current_difficulty_factor = difficulty_curve.sample(time_elapsed / 3600.0) # 1시간 기준
	else:
		current_difficulty_factor = 1.0 + (depth * 0.1)
