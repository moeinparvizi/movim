@echo off
call "%~dp0neovim\start-webstorm.cmd" %*
exit /b %errorlevel%
