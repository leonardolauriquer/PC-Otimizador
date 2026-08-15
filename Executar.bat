@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title PC Otimizador Pro
cd /d "%~dp0"
color 0B

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo  Solicitando Administrador...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo   Verificando atualizacoes...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update.ps1" -Root "%~dp0" -Relaunch "%~f0"
set "UP=%ERRORLEVEL%"
if "%UP%"=="10" (
  echo   Atualizando e reiniciando...
  exit /b 0
)
if "%UP%"=="2" (
  echo.
  echo   FALHA na atualizacao obrigatoria. Verifique a internet e tente de novo.
  echo   Release: https://github.com/leonardolauriquer/PC-Otimizador/releases
  pause
  exit /b 2
)

:MAIN
cls
echo.
echo   ============================================================
echo        PC OTIMIZADOR PRO  v5.5
echo   ============================================================
echo.
echo   Dica: 1 = mais seguro. 8 = so simula. G = tela com ajuda.
echo   Nunca apaga Documentos/Fotos/Downloads. Logs em Documentos.
echo.
echo     1. Limpeza Segura ^(recomendado - temp/lixeira/caches^)
echo     2. Turbo / Gamer ^(ATENCAO: pode mudar DNS/energia^)
echo     3. Reparar Internet ^(ATENCAO: DNS/IP^)
echo     4. Preset Completo ^(limpeza ampla, mais demorado^)
echo     5. Notebook ^(bateria - plano equilibrado^)
echo     6. Personalizar ^(escolhe item a item^)
echo     7. Varrer + Health Score ^(so mede, nao apaga^)
echo     8. Dry-run Limpeza Segura ^(simula sem apagar^)
echo     9. Agendar limpeza semanal ^(domingo 10h, so SAFE^)
echo     R. Remover agendamento
echo     H. Health Score ^(0-100^)
echo     W. Whitelist ^(pastas protegidas^)
echo     B. Bloatware ^(lista + voce confirma^)
echo     G. Interface grafica ^(tooltips / Ajuda^)
echo     ?. Ajuda rapida
echo     0. Sair
echo.
set /p "OP=  Opcao > "

if "%OP%"=="1" goto P_SAFE
if "%OP%"=="2" goto P_GAMER
if "%OP%"=="3" goto P_NET
if "%OP%"=="4" goto P_FULL
if "%OP%"=="5" goto P_NOTE
if "%OP%"=="6" goto CUSTOM
if "%OP%"=="7" goto SCAN
if "%OP%"=="8" goto DRY
if "%OP%"=="9" goto SCHED
if /i "%OP%"=="R" goto UNSCHED
if /i "%OP%"=="H" goto HEALTH
if /i "%OP%"=="W" goto WHITE
if /i "%OP%"=="B" goto BLOAT
if /i "%OP%"=="G" goto GUI
if "%OP%"=="?" goto HELP
if /i "%OP%"=="ajuda" goto HELP
if "%OP%"=="0" goto FIM
goto MAIN

:P_SAFE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset safe
goto MAIN
:P_GAMER
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset gamer
goto MAIN
:P_NET
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset net
goto MAIN
:P_FULL
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset full
goto MAIN
:P_NOTE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset notebook
goto MAIN
:CUSTOM
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode custom
goto MAIN
:SCAN
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode scan
goto MAIN
:DRY
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset safe -DryRun -AutoYes
pause
goto MAIN
:SCHED
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode schedule -AutoYes
pause
goto MAIN
:UNSCHED
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode unschedule -AutoYes
pause
goto MAIN
:HEALTH
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode health
goto MAIN
:WHITE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode whitelist
goto MAIN
:BLOAT
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode bloat
goto MAIN
:GUI
if exist "%~dp0PC-Otimizador.exe" (
  start "" "%~dp0PC-Otimizador.exe"
) else (
  echo Compile a GUI: powershell -File Compilar-EXE.ps1
  echo PC-Otimizador.ps1 e legado e nao e mais a entrada padrao.
  pause
)
goto MAIN
:HELP
cls
echo.
echo   ============================================================
echo        AJUDA RAPIDA
echo   ============================================================
echo.
echo   1  Limpeza Segura  = temp, lixeira, caches. Mais seguro.
echo   8  Dry-run         = simula a limpeza 1 SEM apagar.
echo   2/3 Gamer/Internet = podem mudar DNS ou energia. Cuidado.
echo   7/H Health/Estimar = so medem o PC, nao apagam.
echo   W  Whitelist       = pastas que NUNCA serao apagadas.
echo   G  GUI             = tela com baloes de ajuda (tooltips).
echo.
echo   NUNCA apagamos: Documentos, Fotos, Downloads, Desktop,
echo   Musica, OneDrive.
echo.
echo   Logs: Documentos\PC-Otimizador-Logs
echo.
echo   Fluxo sugerido: 8 -^> 1  ^(simular, depois limpar^)
echo.
pause
goto MAIN
:FIM
echo   Ate mais!
timeout /t 1 >nul
exit /b 0
