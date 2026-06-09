import os
import glob

# 작업 디렉토리
ROOT_DIR = r"C:\Users\gamel\Documents\GodotProject\ddc_proto"

# 치환 매핑 딕셔너리 (바이트 형식으로 처리하여 인코딩 무시)
REPLACE_MAP = {
    b"res://core/GameManager.gd": b"res://core/system/GameManager.gd",
    b"res://core/SceneManager.gd": b"res://core/system/SceneManager.gd",
    b"res://core/SaveManager.gd": b"res://core/system/SaveManager.gd",
    b"res://core/DataManager.gd": b"res://core/system/DataManager.gd",
    b"res://core/PlatformManager.gd": b"res://core/system/PlatformManager.gd",
    b"res://core/SignalBus.gd": b"res://core/system/SignalBus.gd",
    b"res://core/Enums.gd": b"res://core/system/Enums.gd",
    b"res://core/BattleManager.gd": b"res://core/combat/BattleManager.gd",
    b"res://core/HexGridManager.gd": b"res://core/combat/HexGridManager.gd",
    b"res://core/DiceManager.gd": b"res://core/combat/DiceManager.gd",
    b"res://core/StatManager.gd": b"res://core/combat/StatManager.gd",
    b"res://core/StatusManager.gd": b"res://core/combat/StatusManager.gd",
    b"res://core/DifficultyManager.gd": b"res://core/combat/DifficultyManager.gd",
    b"res://core/PlayerManager.gd": b"res://core/player/PlayerManager.gd",
    b"res://core/InventoryManager.gd": b"res://core/player/InventoryManager.gd",
    b"res://core/EconomyManager.gd": b"res://core/player/EconomyManager.gd",
    b"res://core/LootManager.gd": b"res://core/player/LootManager.gd",
    b"res://core/EnchantManager.gd": b"res://core/player/EnchantManager.gd",
    b"res://core/MapManager.gd": b"res://core/world/MapManager.gd",
    b"res://core/TownManager.gd": b"res://core/world/TownManager.gd",
    b"res://core/UIManager.gd": b"res://core/ui/UIManager.gd",
    b"res://core/ItemVisualHelper.gd": b"res://core/ui/ItemVisualHelper.gd"
}

def update_file(filepath):
    try:
        with open(filepath, 'rb') as f:
            content = f.read()
            
        original_content = content
        for old_path, new_path in REPLACE_MAP.items():
            content = content.replace(old_path, new_path)
            
        if original_content != content:
            with open(filepath, 'wb') as f:
                f.write(content)
            print(f"Updated: {filepath}")
    except Exception as e:
        print(f"Error reading {filepath}: {e}")

# 파일들 검색 및 수정
for root, _, files in os.walk(ROOT_DIR):
    for file in files:
        if file.endswith((".tscn", ".gd", ".tres", ".cfg")):
            update_file(os.path.join(root, file))

print("Binary path update completed.")