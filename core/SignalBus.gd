extends Node

# SignalBus (Global Event Bus)
# 역할: 매니저 및 객체 간의 결합도를 낮추기 위한 중앙 이벤트 허브입니다.

# [전투 관련]
signal battle_started
signal battle_ended(win: bool)
signal turn_changed(new_turn_owner)
signal entity_died(entity) # entity: Node (Player or Enemy)

# [경제 관련]
signal gold_changed(new_amount: int, delta: int)
signal transaction_failed(reason: String)
signal inventory_updated # 인벤토리 변경 시 (아이템 추가/삭제/이동)

# [스탯/성장 관련]
signal stat_changed(owner_node, stat_key, new_value)
signal level_up(new_level)

# [시스템 관련]
signal save_requested(slot: int)
signal game_loaded
signal scene_changed(scene_name: String)

# [UI 관련]
signal request_popup(popup_type, data) # 팝업 요청 통합
