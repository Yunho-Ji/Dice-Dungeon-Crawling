@echo off
title DDC Item Editor Server
echo ==========================================
echo   DDC Item Database Editor를 실행합니다.
echo ==========================================

:: Flask 설치 확인 및 설치
python -m pip show flask >nul 2>&1
if %errorlevel% neq 0 (
    echo Flask가 설치되어 있지 않습니다. 설치를 시작합니다...
    python -m pip install flask
)

:: 브라우저 자동 실행 (약 2초 뒤 서버가 켜질 때쯤 열리도록 설정)
start "" "http://127.0.0.1:5000"

:: 서버 실행
python tools/item_editor.py

pause
