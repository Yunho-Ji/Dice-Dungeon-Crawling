extends Projectile

# 추가적인 아처 화살 고유 로직이 필요하다면 여기에 작성
# 예: 화살이 날아갈 때의 파티클이나 효과음 등

func _on_impact():
	# 부모 클래스의 데미지 처리 호출
	super._on_impact()
	
	# 화살 충돌 시 추가 연출 (예: 화살이 박히는 연출이나 파괴 이펙트)
	# spawn_arrow_hit_fx()
