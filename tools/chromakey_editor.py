import numpy as np
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from PIL import Image, ImageTk, ImageColor
import os

class ChromaKeyEditor:
    """
    이미지에서 특정 색상을 선택하여 투명하게 만들고 PNG로 저장하는 크로마키 에디터 도구입니다.
    Numpy를 활용한 벡터 연산으로 고속 처리를 지원합니다.
    """
    def __init__(self, root):
        self.root = root
        self.root.title("DDC ChromaKey Editor - PNG Saver (Numpy Optimized)")
        self.root.geometry("1200x850")
        
        self.original_img = None      # 원본 PIL 이미지 (RGBA)
        self.img_array_orig = None    # 원본 Numpy 배열 (RGBA)
        self.processed_img = None     # 처리된 PIL 이미지
        self.display_img = None       # 캔버스 표시용 PhotoImage
        self.key_color = (255, 0, 255) # 기본 제거 색상 (Magenta)
        self.tolerance = 50           # 색상 허용 오차
        
        self.setup_ui()

    def setup_ui(self):
        """사용자 인터페이스(UI)를 설정합니다."""
        control_frame = ttk.Frame(self.root)
        control_frame.pack(side="top", fill="x", padx=10, pady=10)
        
        ttk.Button(control_frame, text="이미지 불러오기", command=self.load_image).pack(side="left", padx=5)
        
        ttk.Label(control_frame, text="허용 오차:").pack(side="left", padx=5)
        self.tol_slider = ttk.Scale(control_frame, from_=0, to=255, orient="horizontal", command=self.on_param_change)
        self.tol_slider.set(self.tolerance)
        self.tol_slider.pack(side="left", padx=5)
        
        self.color_label = ttk.Label(control_frame, text="제거 색상: None", foreground="magenta")
        self.color_label.pack(side="left", padx=10)
        
        ttk.Button(control_frame, text="투명 PNG로 저장", command=self.save_image).pack(side="right", padx=5)

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
        """이미지를 불러와 Numpy 배열로 미리 변환해 둡니다."""
        path = filedialog.askopenfilename(filetypes=[("Image files", "*.png *.jpg *.jpeg *.bmp")])
        if not path: return
        
        # 이미지를 RGBA로 변환 후 로드
        self.original_img = Image.open(path).convert("RGBA")
        # 고속 처리를 위해 미리 Numpy 배열로 변환 (H, W, 4)
        self.img_array_orig = np.array(self.original_img)
        self.process_image()

    def pick_color(self, event):
        """클릭된 위치의 픽셀 색상을 키 색상으로 지정합니다."""
        if self.img_array_orig is None: return
        
        x = int(self.canvas.canvasx(event.x))
        y = int(self.canvas.canvasy(event.y))
        
        if 0 <= x < self.original_img.width and 0 <= y < self.original_img.height:
            # Numpy 배열에서 색상 직접 추출 (R, G, B)
            self.key_color = tuple(self.img_array_orig[y, x, :3])
            self.color_label.config(text=f"제거 색상: {self.key_color}", foreground='#%02x%02x%02x' % self.key_color)
            self.process_image()

    def on_param_change(self, val):
        self.tolerance = int(float(val))
        if self.img_array_orig is not None:
            self.process_image()

    def process_image(self):
        """Numpy 벡터 연산을 사용하여 픽셀을 고속으로 투명화 처리합니다."""
        if self.img_array_orig is None: return
        
        # 원본 배열 복사 (Alpha 채널 수정을 위해)
        img_array = self.img_array_orig.copy()
        
        # RGB 채널만 추출 (H, W, 3)
        rgb = img_array[:, :, :3]
        
        # 1. 색상 차이 계산 (L1 Distance: 절대값 합산)
        # diff = |R1-R2| + |G1-G2| + |B1-B2|
        # astype(np.int32)를 사용해 오버플로우 방지
        diff = np.sum(np.abs(rgb.astype(np.int32) - np.array(self.key_color, dtype=np.int32)), axis=2)
        
        # 2. 허용 오차(Tolerance) 미만인 픽셀 마스크 생성
        mask = diff < self.tolerance
        
        # 3. 마스크에 해당하는 픽셀의 Alpha(3번 인덱스)를 0(투명)으로 설정
        img_array[mask, 3] = 0
        
        # 4. Numpy 배열을 다시 PIL 이미지로 변환
        self.processed_img = Image.fromarray(img_array)
        self.update_canvas()

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
