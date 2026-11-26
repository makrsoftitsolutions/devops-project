param(
  [ValidatePattern('^[a-z0-9]{2,8}$')]
  [string]$Environment = "dev"
)

$terraformRoot = Join-Path $PSScriptRoot "..\root"
$environmentConfig = Join-Path $PSScriptRoot "..\environments\$Environment"
$backendConfig = Join-Path $environmentConfig "backend.hcl"
$variableFile = Join-Path $environmentConfig "terraform.tfvars"

if (-not (Test-Path -LiteralPath $backendConfig -PathType Leaf)) {
  throw "Missing backend configuration: $backendConfig"
}

if (-not (Test-Path -LiteralPath $variableFile -PathType Leaf)) {
  throw "Missing environment variables: $variableFile"
}

Push-Location $terraformRoot
try {
  terraform init -reconfigure "-backend-config=$backendConfig" "-backend-config=key=$Environment.terraform.tfstate"
  if ($LASTEXITCODE -ne 0) {
    throw "terraform init failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}
