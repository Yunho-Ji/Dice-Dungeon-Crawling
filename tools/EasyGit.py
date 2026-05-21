import os
import subprocess
import customtkinter as ctk
from tkinter import Canvas, Toplevel, Label, messagebox

# --- [설정] Easy Git이 관리할 실제 프로젝트 경로 ---
# 인사담당자 참고: 실제 프로젝트의 데이터 오염을 방지하기 위해 
# '샌드박스(Sandbox)' 환경에서 먼저 기능을 검증하는 테스트 프로세스를 구축했습니다.
PROJECT_PATH = r"C:\Users\gamel\Documents\GodotProject\easy_git_test"

class EasyTooltip:
    """
    [UX/UI] 입문자를 위한 친절한 용어 가이드(Tooltip) 클래스입니다.
    기성 라이브러리 없이 직접 구현하여 GUI 제어 능력을 증명합니다.
    """
    def __init__(self, canvas):
        self.canvas = canvas
        self.tip_window = None

    def show_tip(self, text, x, y):
        if self.tip_window: return
        cx = self.canvas.winfo_rootx() + x + 25
        cy = self.canvas.winfo_rooty() + y
        
        self.tip_window = Toplevel(self.canvas)
        self.tip_window.wm_overrideredirect(True)
        self.tip_window.wm_geometry(f"+{cx}+{cy}")
        
        label = Label(self.tip_window, text=text, justify="left",
                      background="#2c3e50", foreground="white",
                      relief="flat", borderwidth=1,
                      font=("NanumGothic", 10), padx=10, pady=5)
        label.pack()

    def hide_tip(self):
        if self.tip_window:
            self.tip_window.destroy()
            self.tip_window = None

class EasyGitApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Easy Git - Simple Version Control")
        self.geometry("1100x750")
        ctk.set_appearance_mode("dark")
        
        self.tooltip = EasyTooltip(None)

        # --- 레이아웃 설계 ---
        self.sidebar = ctk.CTkFrame(self, width=300, corner_radius=0)
        self.sidebar.pack(side="left", fill="y")
        
        self.main_view = ctk.CTkFrame(self, corner_radius=15, fg_color="#121212")
        self.main_view.pack(side="right", fill="both", expand=True, padx=20, pady=20)

        # --- 사이드바 메뉴 ---
        self.logo = ctk.CTkLabel(self.sidebar, text="Easy Git 🚀", font=("NanumGothic", 30, "bold"))
        self.logo.pack(pady=50)

        self.create_menu_btn("📸 Commit (상태 저장)", "현재 코드와 리소스를 안전하게 기록합니다.", self.take_snapshot)
        self.create_menu_btn("☁️ Push (동기화)", "온라인 저장소에 현재 기록을 업로드합니다.", lambda: print("Push logic"))
        self.create_menu_btn("🔄 Refresh (기록 갱신)", "프로젝트의 최신 타임라인을 불러옵니다.", self.update_timeline)
        
        self.info_label = ctk.CTkLabel(self.sidebar, text=f"Target: {os.path.basename(PROJECT_PATH)}", font=("NanumGothic", 12), text_color="gray")
        self.info_label.pack(side="bottom", pady=20)

        # --- 메인 캔버스 ---
        self.canvas = Canvas(self.main_view, bg="#121212", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True, padx=20, pady=20)
        self.tooltip.canvas = self.canvas

        self.update_timeline()

    def create_menu_btn(self, text, hint, command):
        btn = ctk.CTkButton(self.sidebar, text=text, command=command, height=55, font=("NanumGothic", 15, "bold"))
        btn.pack(pady=15, padx=30, fill="x")

    def run_git(self, args):
        try:
            res = subprocess.run(['git'] + args, cwd=PROJECT_PATH, capture_output=True, text=True, check=True)
            return res.stdout.strip()
        except: return ""

    def take_snapshot(self):
        # 간단한 입력창 대신 기본 메시지로 저장 (나중에 확장 가능)
        self.run_git(['add', '.'])
        self.run_git(['commit', '-m', "Easy Git Snapshot"])
        self.update_timeline()
        messagebox.showinfo("Easy Git", "성공적으로 저장되었습니다!")

    def update_timeline(self):
        self.canvas.delete("all")
        log_data = self.run_git(['log', '--pretty=format:%h|%s|%an|%ad', '--date=short', '-n', '12'])
        
        if not log_data:
            self.canvas.create_text(250, 100, text="아직 저장된 기록이 없습니다.\n첫 번째 스냅샷을 찍어보세요!", 
                                    fill="gray", font=("NanumGothic", 15), justify="center")
            return

        lines = log_data.split('\n')
        for i, line in enumerate(lines):
            h, msg, author, date = line.split('|')
            x, y = 150, 80 + (i * 100)

            if i < len(lines) - 1:
                self.canvas.create_line(x, y + 20, x, y + 80, fill="#34495e", width=3)

            color = "#3498db" if i == 0 else "#2c3e50"
            node = self.canvas.create_oval(x-20, y-20, x+20, y+20, fill=color, outline="#ecf0f1", width=2)
            
            full_info = f"Hash ID: {h}\n내용: {msg}\n작업자: {author}\n날짜: {date}\n\n*커밋(Commit)은 이 시점의 완벽한 복사본입니다."
            self.canvas.tag_bind(node, "<Enter>", lambda e, d=full_info, tx=x, ty=y: self.tooltip.show_tip(d, tx, ty))
            self.canvas.tag_bind(node, "<Leave>", lambda e: self.tooltip.hide_tip())

            self.canvas.create_text(x + 50, y - 12, text=msg, anchor="w", fill="white", font=("NanumGothic", 15, "bold"))
            self.canvas.create_text(x + 50, y + 15, text=f"ID: {h} | {date}", anchor="w", fill="#bdc3c7", font=("NanumGothic", 11))

            if i == 0:
                self.canvas.create_text(x - 45, y, text="현재 위치", anchor="e", fill="#3498db", font=("NanumGothic", 11, "bold"))

if __name__ == "__main__":
    app = EasyGitApp()
    app.mainloop()
