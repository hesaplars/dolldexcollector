@echo off
setlocal

cd /d C:\Projeler\MonsterKoleksiyon

echo.
echo DollDex Collector hizli debug APK build basliyor...
echo Bu build flutter clean ve pub get calistirmaz.
echo Proje klasoru: %CD%
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo HATA: Flutter bulunamadi. Flutter PATH ayarini kontrol et.
  pause
  exit /b 1
)

call flutter build apk --debug
if errorlevel 1 (
  echo.
  echo HATA: Hizli APK build basarisiz oldu.
  echo Paket veya Android ayari degistiyse build_clean_apk.bat dosyasini calistir.
  pause
  exit /b 1
)

echo.
echo Hizli build tamamlandi.
echo APK dosyasi:
echo C:\Projeler\MonsterKoleksiyon\build\app\outputs\flutter-apk\app-debug.apk
echo.
pause
