param(
    [string]$PackageName = "lsfg-vk-2.0.0-dev24-linux-aarch64",
    [string]$DockerPlatform = "linux/amd64",
    [string]$ImageName = "lsfgvk-portable-builder:ubuntu22-amd64-cross-aarch64"
)

$ErrorActionPreference = "Stop"

$rootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$dockerfile = Join-Path $rootDir "tools/docker/Dockerfile.portable-ubuntu22"

function Assert-LastExitCode([string]$StepName) {
    if ($LASTEXITCODE -ne 0) {
        throw "$StepName failed with exit code $LASTEXITCODE"
    }
}

Write-Host "[1/3] Build Docker image ($DockerPlatform)"
docker build --platform $DockerPlatform -f $dockerfile -t $ImageName $rootDir
Assert-LastExitCode "Docker image build"

Write-Host "[2/3] Run portable build in container"
docker run --rm `
    --platform $DockerPlatform `
    -e ROOT_DIR=/work `
    -e PACKAGE_NAME=$PackageName `
    -v "${rootDir}:/work" `
    $ImageName `
    bash /work/tools/docker/build-in-container.sh
Assert-LastExitCode "Container build run"

Write-Host "[3/3] Done"
Write-Host "Artifacts are in: $rootDir/dist"
