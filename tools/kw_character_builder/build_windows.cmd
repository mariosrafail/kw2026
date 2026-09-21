@echo off
setlocal
cd /d "%~dp0\..\.."
for %%I in ("tools\kw_character_builder\kw_builder.ico") do set "ICON=%%~fI"
for %%I in ("art_source\blockbench\outrage\Outrage_FullBody_v11_slimmer_body_foot.bbmodel") do set "OUTRAGE_TEMPLATE=%%~fI"
python -m PyInstaller --noconfirm --clean --windowed --onefile ^
  --name "KW Character Builder" ^
  --icon "%ICON%" ^
  --add-data "%OUTRAGE_TEMPLATE%;kw_templates" ^
  --distpath tools\kw_character_builder\dist ^
  --workpath tmp\kwcb_build ^
  --specpath tmp\kwcb_build ^
  tools\kw_character_builder\app.py
if errorlevel 1 exit /b %errorlevel%
echo.
echo Built: tools\kw_character_builder\dist\KW Character Builder.exe
