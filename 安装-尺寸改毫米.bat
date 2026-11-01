@echo off
setlocal
title SketchUp 动态组件尺寸显示毫米补丁
cd /d "%~dp0"
echo.
echo  这个工具把 SketchUp「动态组件」面板的尺寸单位
echo  一律默认成毫米显示（存成厘米的老组件也是毫米），
echo  尺子按钮变成 厘米 / 毫米 两档切换，不再弹确认框。
echo.
echo  *** 请先完全退出 SketchUp，再继续。 ***
echo.
pause
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dc_mm_patch.ps1"
chcp 936 >nul 2>&1
if errorlevel 2 (
  echo.
  echo  SketchUp 装在需要管理员权限的目录，正在用管理员身份重新运行...
  echo  弹出「用户账户控制」时点“是”。
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
echo.
echo  上面每一行出现绿色的 patched 或 already 就算成功。
echo  现在打开 SketchUp，点一个动态组件，尺寸栏应该直接是 mm。
echo.
pause
