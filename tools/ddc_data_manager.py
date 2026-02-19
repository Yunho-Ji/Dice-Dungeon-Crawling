import tkinter as tk
from tkinter import ttk, messagebox
import json
import os
from PIL import Image, ImageTk

# --- 설정 및 경로 ---
PROJECT_ROOT = "C:/Users/gamel/Documents/GodotProject/ddc_proto"
DATA_DIR = os.path.join(PROJECT_ROOT, "data")
ITEM_DB_PATH = os.path.join(DATA_DIR, "item_db.json")
STAT_CONFIG_PATH = os.path.join(DATA_DIR, "secondary_stats_config.json")

ICON_PATHS = [
    os.path.join(PROJECT_ROOT, "addons/apeloot/image/examples"),
    "C:/Users/gamel/Documents/GodotProject/Free - Raven Fantasy Icons/Free - Raven Fantasy Icons/Separated Files/32x32",
    "C:/Users/gamel/Documents/GodotProject/RPG Icons Starter Pack/Sprites/Weapons",
    "C:/Users/gamel/Documents/GodotProject/RPG Icons Starter Pack/Sprites/Armor"
]

GRADE_WEIGHTS = {"common": 1.0, "rare": 1.5, "epic": 2.2, "relic": 3.5}
ALLOWED_STATS = ["atk", "vit", "agi", "int", "spd", "res", "spi", "rec"]

class DDCDataManager:
    def __init__(self, root):
        self.root = root
        self.root.title("DDC Ultimate Data Manager v1.6")
        self.root.geometry("1400x900")
        
        self.item_db = {}
        self.secondary_stats = {}
        self.current_preview_image = None
        
        self.setup_ui()
        self.load_all_data()

    def setup_ui(self):
        self.tab_control = ttk.Notebook(self.root)
        
        # 탭 생성
        self.item_tab = ttk.Frame(self.tab_control)
        self.stat_tab = ttk.Frame(self.tab_control)
        
        self.setup_item_tab()
        self.setup_stat_tab()
        
        self.tab_control.add(self.item_tab, text="⚔️ 아이템 & 등급 관리")
        self.tab_control.add(self.stat_tab, text="🌟 2차 스탯(조합형) 관리")
        self.tab_control.pack(expand=1, fill="both")

    # --- [탭 1] 아이템 관리 UI ---
    def setup_item_tab(self):
        # 좌측 리스트
        list_frame = ttk.Frame(self.item_tab)
        list_frame.pack(side="left", fill="y", padx=10, pady=10)
        
        ttk.Label(list_frame, text="아이템 리스트").pack()
        self.item_listbox = tk.Listbox(list_frame, width=40, font=("Consolas", 10))
        self.item_listbox.pack(expand=True, fill="y")
        self.item_listbox.bind("<<ListboxSelect>>", self.on_item_select)
        
        btn_list_row = ttk.Frame(list_frame)
        btn_list_row.pack(fill="x", pady=5)
        ttk.Button(btn_list_row, text="선택 삭제", command=self.delete_item).pack(side="left", expand=True, fill="x")
        ttk.Button(btn_list_row, text="새 항목", command=self.clear_item_fields).pack(side="left", expand=True, fill="x")

        # 우측 편집 영역
        edit_scroll_canvas = tk.Canvas(self.item_tab)
        edit_scrollbar = ttk.Scrollbar(self.item_tab, orient="vertical", command=edit_scroll_canvas.yview)
        self.item_edit_frame = ttk.Frame(edit_scroll_canvas)
        
        self.item_edit_frame.bind("<Configure>", lambda e: edit_scroll_canvas.configure(scrollregion=edit_scroll_canvas.bbox("all")))
        edit_scroll_canvas.create_window((0, 0), window=self.item_edit_frame, anchor="nw")
        edit_scroll_canvas.configure(yscrollcommand=edit_scrollbar.set)
        
        edit_scroll_canvas.pack(side="left", expand=True, fill="both", padx=10)
        edit_scrollbar.pack(side="right", fill="y")

        # [섹션] 프리뷰
        self.img_label = ttk.Label(self.item_edit_frame, text="아이콘 프리뷰")
        self.img_label.pack(pady=10)

        # [섹션] 기본 정보
        base_info = ttk.LabelFrame(self.item_edit_frame, text="기본 정보")
        base_info.pack(fill="x", pady=5, padx=5)
        
        self.item_entries = {}
        fields = [("ID:", "id"), ("이름:", "name"), ("아이콘:", "icon"), ("등급:", "grade"), ("부위:", "equip")]
        for i, (label, key) in enumerate(fields):
            ttk.Label(base_info, text=label).grid(row=i//2, column=(i%2)*2, sticky="w", padx=5, pady=2)
            if key == "grade":
                ent = ttk.Combobox(base_info, values=["common", "rare", "epic", "relic"])
            elif key == "equip":
                ent = ttk.Combobox(base_info, values=["weapon", "shield", "head", "top", "bottom", "shoes", "accessory", "none"])
                ent.bind("<<ComboboxSelected>>", self.refresh_detail_ui)
            else:
                ent = ttk.Entry(base_info, width=30)
                if key == "icon": ent.bind("<KeyRelease>", lambda e: self.update_preview())
            
            ent.grid(row=i//2, column=(i%2)*2+1, sticky="ew", padx=5, pady=2)
            self.item_entries[key] = ent

        # [섹션] 상세 수치 (동적)
        self.detail_frame = ttk.LabelFrame(self.item_edit_frame, text="수치 설정 (자동 생성 시 '하급' 기준 입력)")
        self.detail_frame.pack(fill="x", pady=5, padx=5)
        self.detail_container = ttk.Frame(self.detail_frame)
        self.detail_container.pack(fill="both", expand=True, padx=10, pady=10)

        # [섹션] 플레이버 텍스트
        ttk.Label(self.item_edit_frame, text="플레이버 텍스트:").pack(anchor="w", padx=5)
        self.item_desc = tk.Text(self.item_edit_frame, height=4, width=60)
        self.item_desc.pack(fill="x", padx=5, pady=5)

        # 버튼들
        btn_frame = ttk.Frame(self.item_edit_frame)
        btn_frame.pack(fill="x", pady=10)
        ttk.Button(btn_frame, text="[자동생성] 등급별 4종 생성", command=self.generate_items).pack(side="left", padx=10)
        ttk.Button(btn_frame, text="단일 저장", command=self.save_single_item).pack(side="left", padx=10)
        ttk.Button(btn_frame, text="전체 파일 저장 (JSON)", command=self.save_item_db_to_disk).pack(side="right", padx=10)

    # --- [탭 2] 2차 스탯 관리 UI ---
    def setup_stat_tab(self):
        # 좌측 리스트
        list_frame = ttk.Frame(self.stat_tab)
        list_frame.pack(side="left", fill="y", padx=10, pady=10)
        self.stat_listbox = tk.Listbox(list_frame, width=35, font=("Consolas", 10))
        self.stat_listbox.pack(expand=True, fill="y")
        self.stat_listbox.bind("<<ListboxSelect>>", self.on_stat_select)
        
        # 우측 편집
        self.stat_edit_frame = ttk.Frame(self.stat_tab)
        self.stat_edit_frame.pack(side="right", expand=True, fill="both", padx=10, pady=10)
        
        # 조합 요구 조건
        req_frame = ttk.LabelFrame(self.stat_edit_frame, text="조합 요구 조건 (예: vit:40, res:20)")
        req_frame.pack(fill="x", pady=5)
        self.stat_req_entry = ttk.Entry(req_frame, font=("Consolas", 11))
        self.stat_req_entry.pack(fill="x", padx=10, pady=10)
        
        # 티어별 설정
        self.tier_frames = []
        for i in range(1, 4):
            tf = ttk.LabelFrame(self.stat_edit_frame, text=f"Tier {i} 설정")
            tf.pack(fill="x", pady=5)
            
            ttk.Label(tf, text="명칭:").grid(row=0, column=0, padx=5)
            t_name = ttk.Entry(tf, width=30); t_name.grid(row=0, column=1, sticky="w", pady=2)
            
            ttk.Label(tf, text="수치:").grid(row=0, column=2, padx=5)
            t_val = ttk.Entry(tf, width=10); t_val.grid(row=0, column=3, sticky="w", pady=2)
            
            ttk.Label(tf, text="설명:").grid(row=1, column=0, padx=5)
            t_desc = ttk.Entry(tf, width=80); t_desc.grid(row=1, column=1, columnspan=3, sticky="ew", pady=2)
            
            self.tier_frames.append({"name": t_name, "val": t_val, "desc": t_desc})
            
        ttk.Button(self.stat_edit_frame, text="스탯 정보 업데이트 (메모리)", command=self.update_stat_memory).pack(pady=10)
        ttk.Button(self.stat_edit_frame, text="스탯 파일 저장 (JSON)", command=self.save_stat_config_to_disk).pack(pady=5)

    # --- 공통 로직 ---
    def load_all_data(self):
        try:
            if os.path.exists(ITEM_DB_PATH):
                with open(ITEM_DB_PATH, "r", encoding="utf-8") as f: self.item_db = json.load(f)
                self.refresh_item_list()
            if os.path.exists(STAT_CONFIG_PATH):
                with open(STAT_CONFIG_PATH, "r", encoding="utf-8") as f: self.secondary_stats = json.load(f)
                self.refresh_stat_list()
        except Exception as e: messagebox.showerror("로드 실패", str(e))

    def refresh_item_list(self):
        self.item_listbox.delete(0, tk.END)
        for i in sorted(self.item_db.keys()): self.item_listbox.insert(tk.END, i)

    def refresh_stat_list(self):
        self.stat_listbox.delete(0, tk.END)
        for i in sorted(self.secondary_stats.keys()): self.stat_listbox.insert(tk.END, i)

    def update_preview(self):
        icon = self.item_entries["icon"].get().strip()
        if not icon: return
        if not icon.endswith(".png"): icon += ".png"
        for p in ICON_PATHS:
            target = os.path.join(p, icon)
            if os.path.exists(target):
                img = Image.open(target).resize((128, 128), Image.Resampling.NEAREST)
                photo = ImageTk.PhotoImage(img)
                self.img_label.config(image=photo, text="")
                self.current_preview_image = photo
                return
        self.img_label.config(image='', text="아이콘 파일을 찾을 수 없음")

    # --- 아이템 상세 UI 제어 ---
    def refresh_detail_ui(self, event=None):
        for w in self.detail_container.winfo_children(): w.destroy()
        etype = self.item_entries["equip"].get()
        
        if etype == "weapon":
            ttk.Label(self.detail_container, text="기본 공격력:").grid(row=0, column=0)
            self.ent_base_atk = ttk.Entry(self.detail_container); self.ent_base_atk.grid(row=0, column=1, padx=5)
            ttk.Label(self.detail_container, text="밸런스:").grid(row=1, column=0)
            self.ent_base_bal = ttk.Entry(self.detail_container); self.ent_base_bal.grid(row=1, column=1, padx=5)
        elif etype in ["head", "top", "bottom", "shoes"]:
            ttk.Label(self.detail_container, text="유형:").grid(row=0, column=0)
            self.cb_armor_type = ttk.Combobox(self.detail_container, values=["heavy", "light", "cloth"])
            self.cb_armor_type.grid(row=0, column=1, padx=5)
            ttk.Label(self.detail_container, text="핵심 수치:").grid(row=1, column=0)
            self.ent_armor_val = ttk.Entry(self.detail_container); self.ent_armor_val.grid(row=1, column=1, padx=5)

    def on_item_select(self, event):
        selection = self.item_listbox.curselection()
        if not selection: return
        iid = self.item_listbox.get(selection[0])
        item = self.item_db[iid]
        
        self.clear_item_fields()
        self.item_entries["id"].insert(0, iid)
        self.item_entries["name"].insert(0, item.get("name", ""))
        self.item_entries["icon"].insert(0, item.get("icon", ""))
        self.item_entries["grade"].set(item.get("grade", "common"))
        self.item_entries["equip"].set(item.get("equip_type", "none"))
        self.refresh_detail_ui()
        
        # 수치 복원 (단일 값 또는 범위의 평균)
        stats = item.get("stats", {})
        etype = item.get("equip_type")
        if etype == "weapon":
            val = stats.get("max_atk", [0,0])[0] if isinstance(stats.get("max_atk"), list) else stats.get("max_atk", 0)
            self.ent_base_atk.insert(0, str(val))
            bal = stats.get("balance", [0,0])[0] if isinstance(stats.get("balance"), list) else stats.get("balance", 0)
            self.ent_base_bal.insert(0, str(bal))
        elif etype in ["head", "top", "bottom", "shoes"]:
            self.cb_armor_type.set(item.get("armor_type", "heavy"))
            key = list(stats.keys())[0] if stats else ""
            val = stats[key][0] if key and isinstance(stats[key], list) else stats.get(key, 0)
            self.ent_armor_val.insert(0, str(val))
            
        self.item_desc.insert("1.0", item.get("desc", ""))
        self.update_preview()

    def clear_item_fields(self):
        for e in self.item_entries.values(): 
            if isinstance(e, ttk.Entry): e.delete(0, tk.END)
        self.item_desc.delete("1.0", tk.END)

    def generate_items(self):
        base_id = self.item_entries["id"].get().strip()
        if not base_id: return
        name = self.item_entries["name"].get()
        icon = self.item_entries["icon"].get()
        etype = self.item_entries["equip"].get()
        desc = self.item_desc.get("1.0", tk.END).strip()
        
        for grade, weight in GRADE_WEIGHTS.items():
            new_id = f"{base_id}_{grade}"
            stats = {}
            if etype == "weapon":
                atk = float(self.ent_base_atk.get() or 0) * weight
                bal = float(self.ent_base_bal.get() or 0)
                stats = {
                    "min_atk": [round(atk*0.8, 1), round(atk*0.9, 1)],
                    "max_atk": [round(atk*1.1, 1), round(atk*1.3, 1)],
                    "balance": [round(bal, 1), round(min(100, bal+10*weight), 1)]
                }
            elif etype in ["head", "top", "bottom", "shoes"]:
                val = float(self.ent_armor_val.get() or 0) * weight
                atype = self.cb_armor_type.get()
                key = "res_bonus" if atype == "heavy" else "evade_rate" if atype == "light" else "ms_bonus_rate"
                stats = { key: [round(val*0.9, 2), round(val*1.1, 2)] }
            
            self.item_db[new_id] = {
                "name": f"{name} ({grade})", "icon": icon, "desc": desc, "equip_type": etype,
                "grade": grade, "armor_type": self.cb_armor_type.get() if etype != "weapon" else "none",
                "can_reforge": False if grade == "relic" else True, "stats": stats
            }
        self.refresh_item_list()
        messagebox.showinfo("성공", "4종 등급 아이템 생성 완료")

    def save_single_item(self):
        iid = self.item_entries["id"].get().strip()
        if not iid: return
        # (단일 저장 로직 생략 - 자동생성 권장)
        messagebox.showinfo("안내", "자동생성 기능을 사용해 주세요.")

    def delete_item(self):
        sel = self.item_listbox.curselection()
        if not sel: return
        iid = self.item_listbox.get(sel[0])
        if messagebox.askyesno("삭제", f"'{iid}' 정말 삭제?"):
            del self.item_db[iid]; self.refresh_item_list()

    def save_item_db_to_disk(self):
        with open(ITEM_DB_PATH, "w", encoding="utf-8") as f:
            json.dump(self.item_db, f, ensure_ascii=False, indent="\t")
        messagebox.showinfo("성공", "아이템 DB 파일 저장 완료")

    # --- 2차 스탯 로직 ---
    def on_stat_select(self, event):
        sel = self.stat_listbox.curselection()
        if not sel: return
        sid = self.stat_listbox.get(sel[0])
        data = self.secondary_stats[sid]
        
        reqs = data.get("require", {})
        req_str = ", ".join([f"{k}:{v}" for k, v in reqs.items()])
        self.stat_req_entry.delete(0, tk.END); self.stat_req_entry.insert(0, req_str)
        
        tiers = data.get("tiers", [])
        for i in range(3):
            t_data = tiers[i] if i < len(tiers) else {}
            self.tier_frames[i]["name"].delete(0, tk.END); self.tier_frames[i]["name"].insert(0, t_data.get("name", ""))
            self.tier_frames[i]["val"].delete(0, tk.END); self.tier_frames[i]["val"].insert(0, str(t_data.get("val", "")))
            self.tier_frames[i]["desc"].delete(0, tk.END); self.tier_frames[i]["desc"].insert(0, t_data.get("desc", ""))

    def update_stat_memory(self):
        sel = self.stat_listbox.curselection()
        if not sel: return
        sid = self.stat_listbox.get(sel[0])
        
        # 요구 조건 파싱
        req_raw = self.stat_req_entry.get().replace(" ", "").split(",")
        new_reqs = {}
        for r in req_raw:
            if ":" in r:
                k, v = r.split(":")
                if k in ALLOWED_STATS: new_reqs[k] = int(v)
        
        # 티어 파싱
        new_tiers = []
        for i in range(3):
            new_tiers.append({
                "level": i+1,
                "name": self.tier_frames[i]["name"].get(),
                "val": float(self.tier_frames[i]["val"].get() or 0),
                "desc": self.tier_frames[i]["desc"].get()
            })
            
        self.secondary_stats[sid]["require"] = new_reqs
        self.secondary_stats[sid]["tiers"] = new_tiers
        messagebox.showinfo("성공", f"{sid} 메모리 업데이트 완료")

    def save_stat_config_to_disk(self):
        with open(STAT_CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(self.secondary_stats, f, ensure_ascii=False, indent="\t")
        messagebox.showinfo("성공", "2차 스탯 설정 파일 저장 완료")

if __name__ == "__main__":
    root = tk.Tk()
    app = DDCDataManager(root)
    root.mainloop()
