import os
import json
from flask import Flask, render_template_string, request, jsonify, send_from_directory

app = Flask(__name__)

# 경로 설정
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "data", "item_db.json")
IMAGE_DIR = os.path.join(BASE_DIR, "addons", "apeloot", "image", "examples")

def load_db():
    if not os.path.exists(DB_PATH): return {}
    with open(DB_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def save_db(data):
    with open(DB_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

@app.route("/")
def index():
    return render_template_string(HTML_TEMPLATE)

@app.route("/api/items", methods=["GET"])
def get_items():
    return jsonify(load_db())

@app.route("/api/items", methods=["POST"])
def update_items():
    save_db(request.json)
    return jsonify({"status": "success"})

@app.route("/api/icons", methods=["GET"])
def list_icons():
    if not os.path.exists(IMAGE_DIR): return jsonify([])
    icons = [f for f in os.listdir(IMAGE_DIR) if f.endswith(".png")]
    return jsonify(sorted(icons))

@app.route("/icons/<path:filename>")
def get_icon_file(filename):
    return send_from_directory(IMAGE_DIR, filename)

# --- HTML Template ---
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>DDC Item Editor v2.0</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { background-color: #f0f2f5; padding: 20px; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
        .sidebar-container { background: white; border-radius: 12px; padding: 20px; height: calc(100vh - 40px); overflow-y: auto; box-shadow: 0 4px 12px rgba(0,0,0,0.08); position: sticky; top: 20px; }
        .editor-container { background: white; border-radius: 12px; padding: 30px; min-height: calc(100vh - 40px); box-shadow: 0 4px 12px rgba(0,0,0,0.08); margin-bottom: 20px; }
        .item-card { cursor: pointer; border-left: 4px solid #dee2e6; margin-bottom: 8px; border-radius: 6px !important; transition: all 0.2s; padding: 12px; border: 1px solid #eee; }
        .item-card:hover { background: #f8f9fa; transform: translateX(4px); }
        .item-card.active { background: #e7f1ff; border-left-color: #0d6efd; border-color: #b0d4ff; }
        .icon-preview-large { width: 140px; height: 140px; border: 2px dashed #cbd5e0; display: flex; align-items: center; justify-content: center; background: #f7fafc; margin-bottom: 15px; border-radius: 12px; overflow: hidden; }
        .icon-preview-large img { max-width: 90%; max-height: 90%; image-rendering: pixelated; }
        .icon-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(70px, 1fr)); gap: 12px; max-height: 350px; overflow-y: auto; border: 1px solid #edf2f7; padding: 15px; border-radius: 8px; background: #fff; }
        .icon-item { cursor: pointer; border: 2px solid transparent; padding: 5px; border-radius: 8px; text-align: center; transition: all 0.1s; }
        .icon-item:hover { background: #edf2f7; }
        .icon-item.selected { border-color: #0d6efd; background: #ebf8ff; }
        .icon-item img { width: 48px; height: 48px; image-rendering: pixelated; margin-bottom: 4px; }
        .icon-item div { font-size: 11px; color: #4a5568; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .sticky-toolbar { position: sticky; top: -10px; background: white; z-index: 100; padding-bottom: 15px; border-bottom: 1px solid #edf2f7; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; }
        .form-label { font-weight: 600; color: #4a5568; font-size: 0.9rem; }
        .form-control, .form-select { border-radius: 8px; border: 1px solid #e2e8f0; }
        .form-control:focus { box-shadow: 0 0 0 3px rgba(66, 153, 225, 0.15); }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row g-4">
            <!-- Sidebar: Item List -->
            <div class="col-lg-3 col-md-4">
                <div class="sidebar-container">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h4 class="m-0 fw-bold text-dark">Database</h4>
                        <button class="btn btn-primary btn-sm rounded-pill px-3" onclick="createNewItem()">+ New</button>
                    </div>
                    <div id="itemList"></div>
                </div>
            </div>

            <!-- Main Editor Area -->
            <div class="col-lg-9 col-md-8">
                <div id="noSelect" class="editor-container d-flex align-items-center justify-content-center">
                    <div class="text-center text-muted">
                        <h2 class="display-6">📦</h2>
                        <p>아이템을 선택하여 편집을 시작하거나<br>새로운 아이템을 등록해 주세요.</p>
                    </div>
                </div>
                
                <div id="editor" class="editor-container" style="display: none;">
                    <!-- Sticky Header with Actions -->
                    <div class="sticky-toolbar">
                        <div>
                            <small class="text-muted text-uppercase fw-bold">ID:</small>
                            <span id="displayId" class="ms-2 badge bg-light text-dark border font-monospace fs-6">item_id</span>
                        </div>
                        <div>
                            <button class="btn btn-outline-danger me-2" onclick="deleteCurrentItem()">Delete</button>
                            <button class="btn btn-primary px-4 fw-bold" onclick="saveCurrentItem()">Save Changes</button>
                        </div>
                    </div>

                    <div class="row g-4">
                        <!-- Left Column: Item Properties -->
                        <div class="col-xl-7">
                            <div class="row g-3">
                                <div class="col-md-12">
                                    <label class="form-label">Display Name (이름)</label>
                                    <input type="text" id="itemName" class="form-control form-control-lg">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">Price (가격)</label>
                                    <div class="input-group">
                                        <input type="number" id="itemPrice" class="form-control">
                                        <span class="input-group-text">Gold</span>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">Rarity (희귀도)</label>
                                    <select id="itemRarity" class="form-select">
                                        <option value="0">Common</option>
                                        <option value="1">Uncommon</option>
                                        <option value="2">Rare</option>
                                        <option value="3">Epic</option>
                                        <option value="4">Legendary</option>
                                    </select>
                                </div>
                                <div class="col-12">
                                    <label class="form-label">Description (설명)</label>
                                    <textarea id="itemDesc" class="form-control" rows="3"></textarea>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">Grid Pattern</label>
                                    <select id="itemPattern" class="form-select"></select>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">Equip Slot</label>
                                    <select id="itemEquip" class="form-select">
                                        <option value="none">None</option>
                                        <option value="weapon">Weapon</option>
                                        <option value="shield">Shield</option>
                                        <option value="head">Head</option>
                                        <option value="top">Top</option>
                                        <option value="bottom">Bottom</option>
                                        <option value="shoes">Shoes</option>
                                        <option value="accessory">Accessory</option>
                                    </select>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">Armor Type</label>
                                    <select id="itemArmor" class="form-select">
                                        <option value="">N/A</option>
                                        <option value="cloth">Cloth</option>
                                        <option value="light">Light</option>
                                        <option value="heavy">Heavy</option>
                                    </select>
                                </div>
                                <div class="col-12 mt-4">
                                    <label class="form-label d-flex justify-content-between">
                                        Custom Stats (Bonus)
                                        <small class="text-primary">Valid JSON format</small>
                                    </label>
                                    <textarea id="itemStats" class="form-control font-monospace" rows="5" style="background: #fafafa;"></textarea>
                                    <div class="form-text">Example: {"atk": 5, "hp": 10, "luck": 1}</div>
                                </div>
                            </div>
                        </div>

                        <!-- Right Column: Icon Selection -->
                        <div class="col-xl-5 border-start ps-xl-4">
                            <h5 class="fw-bold mb-3">Icon Management</h5>
                            <div class="d-flex align-items-center mb-4">
                                <div class="icon-preview-large me-3" id="iconPreview">
                                    <span class="text-muted">No Image</span>
                                </div>
                                <div>
                                    <small class="text-muted d-block mb-1">현재 선택된 파일:</small>
                                    <span id="currentIconName" class="badge bg-primary fs-6">none</span>
                                </div>
                            </div>
                            
                            <label class="form-label">이미지 라이브러리</label>
                            <input type="text" id="iconSearch" class="form-control mb-3" placeholder="파일명으로 검색 (예: sword, cloth...)">
                            <div class="icon-grid" id="iconGrid"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let items = {};
        let icons = [];
        let currentId = null;
        let selectedIcon = "";

        const patterns = ["1x1", "1x2", "2x1", "2x2", "3x1", "3x2", "3x3", "4x4", "T", "diagonal"];

        async function init() {
            const pSelect = document.getElementById('itemPattern');
            patterns.forEach(p => pSelect.add(new Option(p, p)));
            
            await Promise.all([fetchItems(), fetchIcons()]);
            document.getElementById('iconSearch').oninput = (e) => renderIcons(e.target.value);
        }

        async function fetchItems() {
            const res = await fetch('/api/items');
            items = await res.json();
            renderList();
        }

        async function fetchIcons() {
            const res = await fetch('/api/icons');
            icons = await res.json();
            renderIcons();
        }

        function renderList() {
            const list = document.getElementById('itemList');
            list.innerHTML = '';
            Object.keys(items).sort().forEach(id => {
                const item = items[id];
                const div = document.createElement('div');
                div.className = `list-group-item item-card ${id === currentId ? 'active' : ''}`;
                div.onclick = () => selectItem(id);
                div.innerHTML = `<div class="fw-bold">${item.name || id}</div><small class="text-muted font-monospace">${id}</small>`;
                list.appendChild(div);
            });
        }

        function renderIcons(filter = "") {
            const grid = document.getElementById('iconGrid');
            grid.innerHTML = '';
            icons.filter(i => i.toLowerCase().includes(filter.toLowerCase())).forEach(icon => {
                const item = document.createElement('div');
                item.className = `icon-item ${icon === selectedIcon ? 'selected' : ''}`;
                item.onclick = () => setIcon(icon);
                item.innerHTML = `<img src="/icons/${icon}"><div>${icon}</div>`;
                grid.appendChild(item);
            });
        }

        function selectItem(id) {
            currentId = id;
            const item = items[id];
            document.getElementById('noSelect').style.display = 'none';
            document.getElementById('editor').style.display = 'block';
            
            document.getElementById('displayId').innerText = id;
            document.getElementById('itemName').value = item.name || '';
            document.getElementById('itemDesc').value = item.desc || '';
            document.getElementById('itemPrice').value = item.price || 0;
            document.getElementById('itemRarity').value = item.rarity || 0;
            document.getElementById('itemPattern').value = item.pattern || '1x1';
            document.getElementById('itemEquip').value = item.equip_type || 'none';
            document.getElementById('itemArmor').value = item.armor_type || '';
            document.getElementById('itemStats').value = JSON.stringify(item.stats || {}, null, 4);
            
            setIcon(item.icon || "");
            renderList();
            
            // 편집기 영역으로 스크롤 자동 이동 (모바일/작은 화면 대응)
            if (window.innerWidth < 992) {
                document.getElementById('editor').scrollIntoView({ behavior: 'smooth' });
            }
        }

        function setIcon(iconName) {
            selectedIcon = iconName;
            const preview = document.getElementById('iconPreview');
            const nameLabel = document.getElementById('currentIconName');
            
            if (iconName) {
                preview.innerHTML = `<img src="/icons/${iconName}">`;
                nameLabel.innerText = iconName;
            } else {
                preview.innerHTML = `<span class="text-muted">No Image</span>`;
                nameLabel.innerText = "none";
            }
            renderIcons(document.getElementById('iconSearch').value);
        }

        async function saveCurrentItem() {
            try {
                // Validation
                const statsRaw = document.getElementById('itemStats').value.trim();
                let statsObj = {};
                if (statsRaw !== "") {
                    statsObj = JSON.parse(statsRaw);
                }

                items[currentId] = {
                    name: document.getElementById('itemName').value,
                    desc: document.getElementById('itemDesc').value,
                    price: parseInt(document.getElementById('itemPrice').value),
                    rarity: parseInt(document.getElementById('itemRarity').value),
                    pattern: document.getElementById('itemPattern').value,
                    equip_type: document.getElementById('itemEquip').value,
                    armor_type: document.getElementById('itemArmor').value,
                    icon: selectedIcon,
                    stats: statsObj
                };
                
                const res = await fetch('/api/items', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(items)
                });
                
                if (res.ok) {
                    alert("✅ 저장 완료!");
                    renderList();
                }
            } catch (e) { alert("❌ JSON 형식 오류: 스탯 입력란을 확인해 주세요. (" + e.message + ")"); }
        }

        function createNewItem() {
            const id = prompt("새 아이템의 고유 ID를 입력하세요 (예: steel_sword):");
            if (id) {
                const cleanId = id.trim().toLowerCase().replace(/ /g, "_");
                if (items[cleanId]) {
                    alert("이미 존재하는 ID입니다.");
                    return;
                }
                items[cleanId] = { name: "New Item", rarity: 0, price: 100, pattern: "1x1" };
                selectItem(cleanId);
            }
        }

        async function deleteCurrentItem() {
            if (!currentId || !confirm(`정말 '${currentId}' 아이템을 데이터베이스에서 삭제할까요?`)) return;
            
            delete items[currentId];
            await fetch('/api/items', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(items)
            });
            
            currentId = null;
            document.getElementById('editor').style.display = 'none';
            document.getElementById('noSelect').style.display = 'flex';
            renderList();
        }

        init();
    </script>
</body>
</html>
"""

if __name__ == "__main__":
    print("DDC Item Editor v2.0 running at http://127.0.0.1:5000")
    app.run(debug=True, port=5000)
