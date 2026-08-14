# Build and deploy Jolt DevTools Extension
# This script builds the extension and copies it to the jolt package

Write-Host "Building Jolt DevTools Extension..." -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Prepare the extension web app
Write-Host "Preparing web app..." -ForegroundColor Yellow
flutter create . --platforms web

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Web app setup failed!" -ForegroundColor Red
    exit 1
}

# Build the extension and copy it to the jolt package
Write-Host "Building and copying extension files to the jolt package..." -ForegroundColor Yellow
dart run devtools_extensions build_and_copy --source=. --dest=../jolt/extension/devtools

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build and copy failed!" -ForegroundColor Red
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
