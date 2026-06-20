@echo off
setlocal

cd /d C:\Projeler\MonsterKoleksiyon

echo.
echo DollDex Collector debug APK build basliyor...
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
echo Debug APK olusturuluyor...
call flutter build apk --debug
if errorlevel 1 (
  echo.
  echo HATA: APK build basarisiz oldu.
  pause
  exit /b 1
)

echo.
echo Build tamamlandi.
echo APK dosyasi:
echo C:\Projeler\MonsterKoleksiyon\build\app\outputs\flutter-apk\app-debug.apk
echo.
pause
