@echo off
setlocal

set PROJECT_DIR=C:\Projeler\MonsterKoleksiyon
set GRADLE_HOME=C:\gradle-cache
set GRADLE_PROPS=%PROJECT_DIR%\android\gradle.properties

echo Preparing Gradle cache folder...
if not exist "%GRADLE_HOME%" mkdir "%GRADLE_HOME%"

echo Setting persistent GRADLE_USER_HOME...
setx GRADLE_USER_HOME "%GRADLE_HOME%" >nul
set GRADLE_USER_HOME=%GRADLE_HOME%

echo Writing Android Gradle properties...
(
  echo org.gradle.daemon=false
  echo org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=1024m -Dfile.encoding=UTF-8
  echo android.useAndroidX=true
) > "%GRADLE_PROPS%"

echo Stopping existing Gradle daemons if possible...
cd /d "%PROJECT_DIR%\android"
call gradlew.bat --stop

echo.
echo Done. Now open a NEW VS Code terminal and run:
echo flutter clean
echo flutter pub get
echo flutter build apk --debug
echo.
pause
