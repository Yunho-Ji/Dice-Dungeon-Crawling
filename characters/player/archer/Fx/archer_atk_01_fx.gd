extends AnimatedSprite2D

func _ready():
	# 애니메이션이 끝나면 스스로를 파괴하는 신호를 연결합니다.
	animation_finished.connect(queue_free)
	# 애니메이션을 재생합니다.
	play()
