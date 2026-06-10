# DDC (Destiny Dungeon Chronicles) Project Milestone & Guidelines

## 1. 프로젝트 아키텍처 개요 (v7.4)
DDC는 Godot 4.4.1 기반의 턴제 헥사 그리드 전투 RPG입니다. 코어 로직은 `core/` 디렉토리 내의 5대 도메인으로 분리되어 있으며, 싱글톤(Autoload)을 통해 중앙 관리됩니다.

### 📂 주요 디렉토리 구조
*   `core/system/`: 엔진 코어 (GameManager, SignalBus, DataManager, SceneManager)
*   `core/combat/`: 전투 로직 (StatManager, DiceManager, HexGridManager)
*   `core/player/`: 플레이어 상태 (PlayerManager, InventoryManager, EconomyManager)
*   `core/world/`: 월드 및 던전 (MapManager, TownManager)
*   `core/inventory/`: 인벤토리 데이터 모델 (InventoryData, InventoryItem)
*   `ui/screens/`: 전체 화면 UI (TownShopScreen, DestinyDesignScreen)
*   `data/`: 정적 데이터 (item_db.json)

---

## 2. 핵심 관리자 (Core Managers) 및 의존성
*   **GameManager**: 게임 상태(Phase) 전환, 전투 흐름 제어, 이벤트 트리거.
*   **PlayerManager**: 플레이어의 스탯, 장착 아이템, 인벤토리 데이터 모델 관리.
*   **InventoryManager**: 아이템 획득/삭제 트랜잭션 처리, 골드 검증 로직 주입.
*   **DataManager**: `item_db.json` 로드 및 아이템 패턴(1x1, 2x2 등) 관리.
*   **SignalBus**: 글로벌 이벤트(골드 변경, 전투 종료 등)를 Pub-Sub 방식으로 중계.

---

## 3. 기술적 규칙 및 컨벤션 (Mandatory)
1.  **도메인 고립**: 매니저 간 직접 참조(`get_node`)보다는 `SignalBus`를 통한 통신을 권장합니다.
2.  **데이터 무결성**: 모든 스탯 및 재화 연산은 정수형(Integer)을 기본으로 합니다.
3.  **인벤토리 시스템**: `InventoryData`(Resource)는 순수 모델이며, `InventoryManager`를 통해 수정해야 합니다.
4.  **UI 연동**: 화면 UI는 싱글톤을 직접 참조하여 상태를 반영하고, 사용자 입력을 다시 싱글톤으로 전달합니다.
5.  **들여쓰기**: GDScript는 **1개의 탭(Tab)**을 사용합니다.
6.  **주석**: 모든 주요 함수와 복잡한 로직에는 **한국어 주석**을 포함해야 합니다.

---

## 4. 테스트 단계 핵심 요구사항 (11종)
현재 구현 상태를 기준으로 우선순위를 정해 완결합니다. (윤호/wolf0님 가이드라인)

| 번호 | 기능 항목 | 구현 상태 | 비고 |
| :--- | :--- | :---: | :--- |
| 1 | 장비 착용 (Equip) | ✅ 부분 완료 | PlayerManager 내 구현됨 |
| 2 | 장비 해제 (Unequip) | ✅ 부분 완료 | PlayerManager 내 구현됨 |
| 3 | 인벤토리 내 아이템 회전 | ✅ 완료 | 마우스 오버 + R 키 방식 |
| 4 | 장착 시 캐릭터 효과 적용 | ⚠️ 점검 필요 | StatModifierEffect 연동 확인 |
| 5 | 인벤토리 소지 중 패시브 효과 | ❌ 미구현 | 가방에만 있어도 발동하는 효과 |
| 6 | 아이템 구매 (Buy) | ✅ 완료 | 상점 UI 연동 완료 |
| 7 | 아이템 판매 (Sell) | ❌ 미구현 | 상점 UI에 판매 기능 추가 필요 |
| 8 | 아이템 가치 설정 (Price) | ✅ 완료 | 등급별 자동 책정 로직 포함 |
| 9 | 아이템 그리드(패턴) 설정 | ✅ 완료 | DataManager 패턴 및 DB 연동 |
| 10 | 드래그 앤 드롭 이동 | ✅ 완료 | CustomInventoryGrid 구현 |
| 11 | 골드 패널티/더미 로직 | ❌ 재구현 필요 | 인벤토리 개편 후 재확인 대상 |

---

## 5. 현재 이정표 및 미해결 과제 (Current Tasks)
1.  **[7] 아이템 판매 기능**: 상점 UI에 플레이어 가방 아이템을 팔 수 있는 탭/버튼 추가.
2.  **[11] 골드 더미 시스템**: `InventoryManager`의 TODO 항목 해결. 소지 골드량에 따른 공간 점유 로직.
3.  **[4, 5] 효과 시스템 정밀화**: 장착 시뿐만 아니라 소지 중일 때도 효과가 적용되도록 `PlayerManager` 로직 확장.

---
*이 문서는 Gemini CLI의 작업 지침서로 활용됩니다. 모든 작업은 본 문서의 아키텍처와 규칙을 준수해야 합니다.*
