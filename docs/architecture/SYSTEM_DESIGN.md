# 🏗️ DDC 시스템 아키텍처 (Architecture)

## 1. 도메인 주도 설계 (Domain-Driven Design)
DDC는 기능을 5대 핵심 도메인으로 분리하여 관리합니다.

### 📂 주요 도메인 및 역할
*   **System (`core/system/`)**: 엔진 코어 및 전역 상태 관리
    - `GameManager`: 게임 페이즈 및 흐름 제어
    - `DataManager`: `item_db.json` 등 정적 데이터 로드
    - `SignalBus`: 글로벌 이벤트 중계 (Pub-Sub)
*   **Combat (`core/combat/`)**: 전투 로직 및 수치 연산
    - `StatManager`: 스탯 보정 및 계산
    - `DiceManager`: 주사위 물리 및 결과 처리
*   **Player (`core/player/`)**: 플레이어 데이터 및 가방 관리
    - `PlayerManager`: 장비 장착 및 스탯 합산
    - `InventoryManager`: 아이템 획득/삭제 트랜잭션 및 골드 검증
*   **World (`core/world/`)**: 월드 맵 및 시설 관리
*   **UI (`ui/`)**: 사용자 인터페이스 및 상호작용

## 2. 핵심 규칙
1. **도메인 고립**: 매니저 간 직접 참조 대신 `SignalBus` 통신 지향.
2. **데이터 무결성**: 모든 재화 및 수치 연산은 정수형(Integer) 기본.
3. **SSOT (Single Source of Truth)**: 아이템 상태는 `InventoryData` 모델을 통해서만 변경.
