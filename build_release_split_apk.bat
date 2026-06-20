@echo off
setlocal

cd /d C:\Projeler\MonsterKoleksiyon

echo.
echo DollDex Collector kucuk release APK build basliyor...
echo Bu build --release --split-per-abi kullanir.
echo Proje klasoru: %CD%
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo HATA: Flutter bulunamadi. Flutter PATH ayarini kontrol et.
  pause
  exit /b 1
)

call flutter build apk --release --split-per-abi
if errorlevel 1 (
  echo.
  echo HATA: Release split APK build basarisiz oldu.
  pause
  exit /b 1
)

echo.
echo Release split build tamamlandi.
echo APK dosyalari:
echo C:\Projeler\MonsterKoleksiyon\build\app\outputs\flutter-apk\
echo.
echo Telefonun cogu zaman arm64-v8a dosyasini kullanir.
echo.
pause
