@echo off
setlocal

cd /d C:\Projeler\MonsterKoleksiyon

echo.
echo DollDex Collector - Sadece arm64-v8a (Tek Telefon) Release APK Build basliyor...
echo Bu build sadece arm64-v8a mimarisini derler, en hizli release derleme yontemidir.
echo Proje klasoru: %CD%
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo HATA: Flutter bulunamadi. Flutter PATH ayarini kontrol et.
  pause
  exit /b 1
)

call flutter build apk --release --target-platform android-arm64
if errorlevel 1 (
  echo.
  echo HATA: arm64 APK build basarisiz oldu.
  pause
  exit /b 1
)

echo.
echo arm64-v8a (Tek Telefon) Build tamamlandi.
echo APK dosyasi:
echo C:\Projeler\MonsterKoleksiyon\build\app\outputs\flutter-apk\app-release.apk
echo.
echo Bu APK'yi dogrudan telefonuna yukleyip test edebilirsin.
echo.
pause
