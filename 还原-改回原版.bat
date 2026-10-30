@echo off
setlocal
title 把动态组件尺寸单位还原成原厂状态
cd /d "%~dp0"
echo.
echo  这一步把动态组件扩展改回原厂状态（厘米 / 英寸，带确认框）。
echo  还原用的是补丁自动留下的备份文件夹 _backup_dc_mm。
echo.
echo  *** 请先完全退出 SketchUp，再继续。 ***
echo.
pause
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dc_mm_patch.ps1" -Restore
chcp 936 >nul 2>&1
if errorlevel 2 (
  echo.
  echo  需要管理员权限，正在用管理员身份重新运行...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
echo.
echo  还原完成，重启 SketchUp 生效。
echo.
pause
