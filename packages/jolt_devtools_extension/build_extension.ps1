# Build and deploy Jolt DevTools Extension
# This script builds the extension and copies it to the jolt package

Write-Host "Building Jolt DevTools Extension..." -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Build the extension
Write-Host "Building web app..." -ForegroundColor Yellow
flutter create . --platforms web
flutter build web --pwa-strategy=none --no-tree-shake-icons

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

# Copy to jolt package
Write-Host "Copying build files to jolt package..." -ForegroundColor Yellow
dart run devtools_extensions build_and_copy --source=. --dest=../jolt/extension/devtools

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Copy failed!" -ForegroundColor Red
    exit 1
}

# Validate
Write-Host "Validating extension..." -ForegroundColor Yellow
dart run devtools_extensions validate --package=../jolt

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Validation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Extension built and deployed successfully!" -ForegroundColor Green

