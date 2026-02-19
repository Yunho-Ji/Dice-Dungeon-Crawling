import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from PIL import Image, ImageTk, ImageColor
import os

class ChromaKeyEditor:
    def __init__(self, root):
        self.root = root
        self.root.title("DDC ChromaKey Editor - PNG Saver")
        self.root.geometry("1200x850")
        
        self.original_img = None
        self.processed_img = None
        self.display_img = None
        self.key_color = (255, 0, 255) # 기본 보라색
        self.tolerance = 50
        
        self.setup_ui()

    def setup_ui(self):
        # 상단 제어 바
        control_frame = ttk.Frame(self.root)
        control_frame.pack(side="top", fill="x", padx=10, pady=10)
        
        ttk.Button(control_frame, text="이미지 불러오기", command=self.load_image).pack(side="left", padx=5)
        
        ttk.Label(control_frame, text="허용 오차:").pack(side="left", padx=5)
        self.tol_slider = ttk.Scale(control_frame, from_=0, to=150, orient="horizontal", command=self.on_param_change)
        self.tol_slider.set(self.tolerance)
        self.tol_slider.pack(side="left", padx=5)
        
        self.color_label = ttk.Label(control_frame, text="제거 색상: None", foreground="magenta")
        self.color_label.pack(side="left", padx=10)
        
        ttk.Button(control_frame, text="투명 PNG로 저장", command=self.save_image).pack(side="right", padx=5)

        # 메인 캔버스 영역 (스크롤 지원)
        self.canvas_frame = ttk.Frame(self.root)
        self.canvas_frame.pack(expand=True, fill="both")
        
        self.canvas = tk.Canvas(self.canvas_frame, background="#333", cursor="cross")
        self.v_bar = ttk.Scrollbar(self.canvas_frame, orient="vertical", command=self.canvas.yview)
        self.h_bar = ttk.Scrollbar(self.canvas_frame, orient="horizontal", command=self.canvas.xview)
        
        self.canvas.configure(yscrollcommand=self.v_bar.set, xscrollcommand=self.h_bar.set)
        
        self.v_bar.pack(side="right", fill="y")
        self.h_bar.pack(side="bottom", fill="x")
        self.canvas.pack(side="left", expand=True, fill="both")
        
        self.canvas.bind("<Button-1>", self.pick_color)

    def load_image(self):
        path = filedialog.askopenfilename(filetypes=[("Image files", "*.png *.jpg *.jpeg *.bmp")])
        if not path: return
        
        self.original_img = Image.open(path).convert("RGBA")
        self.process_image()

    def pick_color(self, event):
        if not self.original_img: return
        
        # 캔버스 좌표를 실제 이미지 좌표로 변환
        x = self.canvas.canvasx(event.x)
        y = self.canvas.canvasy(event.y)
        
        if 0 <= x < self.original_img.width and 0 <= y < self.original_img.height:
            self.key_color = self.original_img.getpixel((int(x), int(y)))[:3]
            self.color_label.config(text=f"제거 색상: {self.key_color}", foreground='#%02x%02x%02x' % self.key_color)
            self.process_image()

    def on_param_change(self, val):
        self.tolerance = int(float(val))
        if self.original_img:
            self.process_image()

    def process_image(self):
        if not self.original_img: return
        
        # 픽셀 데이터 가져오기
        data = self.original_img.getdata()
        new_data = []
        
        kr, kg, kb = self.key_color
        tol = self.tolerance
        
        for item in data:
            # 색상 거리 계산 (단순 절대값 합산으로 성능 확보)
            diff = abs(item[0] - kr) + abs(item[1] - kg) + abs(item[2] - kb)
            
            if diff < tol:
                new_data.append((0, 0, 0, 0)) # 투명화
            else:
                new_data.append(item)
        
        self.processed_img = Image.new("RGBA", self.original_img.size)
        self.processed_img.putdata(new_data)
        
        self.update_canvas()

    def update_preview(self):
        # process_image에서 호출됨
        pass

    def update_canvas(self):
        self.display_img = ImageTk.PhotoImage(self.processed_img)
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, anchor="nw", image=self.display_img)
        self.canvas.config(scrollregion=self.canvas.bbox("all"))

    def save_image(self):
        if not self.processed_img: return
        
        save_path = filedialog.asksaveasfilename(defaultextension=".png", filetypes=[("PNG files", "*.png")])
        if save_path:
            self.processed_img.save(save_path, "PNG")
            messagebox.showinfo("성공", "배경이 제거된 PNG 파일이 저장되었습니다!")

if __name__ == "__main__":
    root = tk.Tk()
    app = ChromaKeyEditor(root)
    root.mainloop()
