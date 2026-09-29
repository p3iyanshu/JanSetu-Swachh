@echo off
title JanSetu-Swachh Server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0backend\serve_lan.ps1"
pause
