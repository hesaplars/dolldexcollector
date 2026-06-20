@echo off
setlocal

cd /d C:\Projeler\MonsterKoleksiyon

echo.
echo DollDex Collector web release build basliyor...
echo Proje klasoru: %CD%
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo HATA: Flutter bulunamadi. Flutter PATH ayarini kontrol et.
  pause
  exit /b 1
)

echo Bagimliliklar yenileniyor...
call flutter pub get
if errorlevel 1 (
  echo.
  echo HATA: flutter pub get basarisiz oldu.
  pause
  exit /b 1
)

echo.
echo Web release cikti olusturuluyor...
call flutter build web --release
if errorlevel 1 (
  echo.
  echo HATA: Web build basarisiz oldu.
  pause
  exit /b 1
)

echo.
echo Web build tamamlandi.
echo Cikti klasoru:
echo C:\Projeler\MonsterKoleksiyon\build\web
echo.
pause
