# Создаёт ключ подписи для Android и печатает значения для секретов GitHub.
# Запускать один раз. Файл ключа и пароли НЕ попадают в Git (папка secrets/ в .gitignore).
#
# Использование:
#   powershell -ExecutionPolicy Bypass -File tools\make-keystore.ps1

param(
    [string]$Alias = "calorie",
    [string]$DistinguishedName = "CN=Calorie, O=Ronis759, C=BY",
    [int]$ValidityDays = 10000,
    [string]$OutDir = "$PSScriptRoot\..\secrets"
)

$ErrorActionPreference = "Stop"

# Кириллица в консоли Windows
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    & "$env:SystemRoot\System32\chcp.com" 65001 | Out-Null
} catch {}

$keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe"
if (-not (Test-Path $keytool)) {
    $candidates = Get-ChildItem "C:\Program Files\Java","C:\Program Files\Eclipse Adoptium" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    foreach ($c in $candidates) {
        $candidate = Join-Path $c.FullName "bin\keytool.exe"
        if (Test-Path $candidate) { $keytool = $candidate; break }
    }
}
if (-not (Test-Path $keytool)) {
    Write-Host "Не найден keytool.exe. Установите JDK (например, Temurin 21) и повторите." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$store = Join-Path $OutDir "calorie-release.jks"

if (Test-Path $store) {
    Write-Host "Файл $store уже существует. Удалите его вручную, если хотите перевыпустить ключ." -ForegroundColor Yellow
    exit 1
}

# Случайный пароль: буквы и цифры, 24 символа
$chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
$password = -join (1..24 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

& $keytool -genkeypair -v `
    -keystore $store `
    -alias $Alias `
    -keyalg RSA -keysize 4096 -validity $ValidityDays `
    -storepass $password -keypass $password `
    -dname $DistinguishedName

if ($LASTEXITCODE -ne 0) { Write-Host "Не удалось создать ключ." -ForegroundColor Red; exit 1 }

$bytes = [System.IO.File]::ReadAllBytes($store)
$b64 = [System.Convert]::ToBase64String($bytes)
$b64File = Join-Path $OutDir "keystore-base64.txt"
[System.IO.File]::WriteAllText($b64File, $b64, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " Ключ создан. Добавьте 4 секрета в GitHub:" -ForegroundColor Green
Write-Host "  Репозиторий calorie → Settings → Secrets and" -ForegroundColor Green
Write-Host "  variables → Actions → New repository secret" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "1) Имя: ANDROID_KEYSTORE_BASE64"
Write-Host "   Значение: всё содержимое файла:"
Write-Host "   $b64File"
Write-Host "   (длинная строка, скопируйте целиком)"
Write-Host ""
Write-Host "2) Имя: ANDROID_KEYSTORE_PASSWORD"
Write-Host "   Значение: $password"
Write-Host ""
Write-Host "3) Имя: ANDROID_KEY_ALIAS"
Write-Host "   Значение: $Alias"
Write-Host ""
Write-Host "4) Имя: ANDROID_KEY_PASSWORD"
Write-Host "   Значение: $password"
Write-Host ""
Write-Host "Файл ключа: $store" -ForegroundColor Yellow
Write-Host "Сохраните его в надёжном месте и сделайте резервную копию." -ForegroundColor Yellow
Write-Host "Если ключ потерять, обновить приложение поверх старой версии не получится." -ForegroundColor Yellow
