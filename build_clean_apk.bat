@echo off
setlocal

cd /d C:\Projeler\MonsterKoleksiyon

echo.
echo DollDex Collector temiz debug APK build basliyor...
echo Bu build flutter clean, pub get ve debug APK build calistirir.
echo Proje klasoru: %CD%
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo HATA: Flutter bulunamadi. Flutter PATH ayarini kontrol et.
  pause
  exit /b 1
)

echo Temizleniyor...
call flutter clean
if errorlevel 1 (
  echo.
  echo HATA: flutter clean basarisiz oldu.
  pause
  exit /b 1
)

echo.
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
  echo HATA: Temiz APK build basarisiz oldu.
  pause
  exit /b 1
)

echo.
echo Temiz build tamamlandi.
echo APK dosyasi:
echo C:\Projeler\MonsterKoleksiyon\build\app\outputs\flutter-apk\app-debug.apk
echo.
pause
