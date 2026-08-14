# 1. PATH okruzenje za ADB
$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"

Write-Host "--- [1/3] Pokrecem Flutter ARM64 Release Build ---" -ForegroundColor Cyan

# Komanda napravljena bez skraćenica da osigura spakovanje samo ARM64 arhitekture
flutter build apk --release --target-platform=android-arm64 --split-per-abi --dart-define-from-file=dart_defines.json

if ($LASTEXITCODE -ne 0) {
    Write-Host "X Build nije uspeo!" -ForegroundColor Red
    exit 1
}

# Primarna putanja do ARM64 APK-a
$APK = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
if (-not (Test-Path $APK)) {
    $APK = "build\app\outputs\flutter-apk\app-release.apk"
}

Write-Host "--- [2/3] Instaliram APK na prvi dostupan telefon... ---" -ForegroundColor Yellow

# adb install -d instalira direktno na jedini povezani USB/WiFi uredjaj bez potrebe za ID-jem
adb install -r $APK

if ($LASTEXITCODE -eq 0) {
    Write-Host "=== [3/3] USPESNO INSTALIRANO I POKRENUTO! ===" -ForegroundColor Green
    adb shell monkey -p com.example.chess_app -c android.intent.category.LAUNCHER 1
} else {
    Write-Host "X Instalacija nije uspela. Ako imate vise povezanih uredjaja u adb devices, isključite jedan." -ForegroundColor Red
}