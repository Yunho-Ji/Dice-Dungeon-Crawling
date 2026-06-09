import os
import glob

# 작업 디렉토리
ROOT_DIR = r"C:\Users\gamel\Documents\GodotProject\ddc_proto"

# 치환 매핑 딕셔너리
REPLACE_MAP = {
    "res://core/GameManager.gd": "res://core/system/GameManager.gd",
    "res://core/SceneManager.gd": "res://core/system/SceneManager.gd",
    "res://core/SaveManager.gd": "res://core/system/SaveManager.gd",
    "res://core/DataManager.gd": "res://core/system/DataManager.gd",
    "res://core/PlatformManager.gd": "res://core/system/PlatformManager.gd",
    "res://core/SignalBus.gd": "res://core/system/SignalBus.gd",
    "res://core/Enums.gd": "res://core/system/Enums.gd",
    "res://core/BattleManager.gd": "res://core/combat/BattleManager.gd",
    "res://core/HexGridManager.gd": "res://core/combat/HexGridManager.gd",
    "res://core/DiceManager.gd": "res://core/combat/DiceManager.gd",
    "res://core/StatManager.gd": "res://core/combat/StatManager.gd",
    "res://core/StatusManager.gd": "res://core/combat/StatusManager.gd",
    "res://core/DifficultyManager.gd": "res://core/combat/DifficultyManager.gd",
    "res://core/PlayerManager.gd": "res://core/player/PlayerManager.gd",
    "res://core/InventoryManager.gd": "res://core/player/InventoryManager.gd",
    "res://core/EconomyManager.gd": "res://core/player/EconomyManager.gd",
    "res://core/LootManager.gd": "res://core/player/LootManager.gd",
    "res://core/EnchantManager.gd": "res://core/player/EnchantManager.gd",
    "res://core/MapManager.gd": "res://core/world/MapManager.gd",
    "res://core/TownManager.gd": "res://core/world/TownManager.gd",
    "res://core/UIManager.gd": "res://core/ui/UIManager.gd",
    "res://core/ItemVisualHelper.gd": "res://core/ui/ItemVisualHelper.gd"
}

def update_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        original_content = content
        for old_path, new_path in REPLACE_MAP.items():
            content = content.replace(old_path, new_path)
            
        if original_content != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated: {filepath}")
    except Exception as e:
        print(f"Error reading {filepath}: {e}")

# .tscn, .gd, .tres 파일들 검색 및 수정
for root, _, files in os.walk(ROOT_DIR):
    for file in files:
        if file.endswith((".tscn", ".gd", ".tres")):
            update_file(os.path.join(root, file))

print("Path update completed.")