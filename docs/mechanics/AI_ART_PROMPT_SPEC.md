# 🎨 DDC AI 픽셀 아트 프롬프트 표준 규격서 (v1.0)

본 문서는 DDC(Destiny Dungeon Chronicles) 프로젝트의 비주얼 일관성을 유지하기 위해 AI 리소스 생성 시 사용되는 프롬프트의 표준 규격을 정의합니다.

## 1. 디자인 원칙 (Core Aesthetics)
- **Style**: 16-bit 레트로 캐주얼 (Retro Casual)
- **Key Features**: 선명한 외곽선(Bold Outlines), 밝은 색감(Vibrant Colors), 단순한 명암(Flat Shading)
- **Standard**: 보유 중인 'Kneeshaw Developments Animated Dice Set'의 픽셀 아트 스타일과 일치할 것

## 2. 카테고리별 표준 프롬프트 구조

### A. 아이템 아이콘 (Items)
- **해상도**: 32x32 스타일 (그리드 최적화)
- **프롬프트 템플릿**:
  > `[Category] pixel art item icon, [Item Name], 32x32 style, crisp edges, bold outlines, vibrant colors, limited color palette, clean shading, white background, game asset --no anti-aliasing`
- **적용 예시**:
  - `Weapon pixel art item icon, Wooden Bow, 32x32 style, ...`
  - `Consumable pixel art item icon, Red Health Potion, 32x32 style, ...`

### B. 캐릭터 및 몬스터 (Characters)
- **해상도**: 64x64 스타일
- **프롬프트 템플릿**:
  > `Cute casual pixel art character, [Description], top-down RPG perspective, 64x64 style, distinct outlines, bright colors, 16-bit aesthetic, flat lighting, white background --no blur`
- **적용 예시**:
  - `Cute casual pixel art character, Human Archer in green tunic, ...`
  - `Cute casual pixel art character, Blue Slime with big eyes, ...`

## 3. 금지 및 필수 키워드 (Do's and Don'ts)

### ✅ 필수 포함 (Must-Have)
- `crisp edges`, `sharp pixels`: 픽셀이 흐려지는 현상 방지
- `white background`: 배경 제거(누끼) 작업 용이성 확보
- `limited color palette`: 캐주얼한 통일감 유지

### ❌ 제외 대상 (Negative Prompt)
- `realistic`, `dark fantasy`, `3d render`, `blur`, `gradient`: 프로젝트 톤앤매너 위반
- `shadows under object`: 인벤토리 UI에 올릴 때 방해되는 바닥 그림자 제외

## 4. 기술적 후가공 절차
1. **배경 제거**: AI 생성 이미지의 흰색 배경 투명화 처리.
2. **리사이징**: Godot 프로젝트 타일 규격(40x40px 등)에 맞춰 정수배 배율 조정.
3. **인덱스 색상화**: 필요한 경우 쉐이더 호환을 위해 팔레트 제한 및 인덱스 컬러 적용.

---
*이 규격은 프로젝트의 비주얼 피드백에 따라 지속적으로 업데이트됩니다.*
