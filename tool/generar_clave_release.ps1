param(
    [string]$Keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
)

$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $projectDir 'android'
$keystorePath = Join-Path $androidDir 'lifesync-release.jks'
$propertiesPath = Join-Path $androidDir 'key.properties'

if ((Test-Path -LiteralPath $keystorePath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw 'Ya existe una clave o configuración de firma. Reutilízala; no la sobrescribas.'
}
if (-not (Test-Path -LiteralPath $Keytool)) {
    throw 'No se encontró keytool. Indica la ruta con -Keytool.'
}

$random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$secretBytes = New-Object byte[] 32
$random.GetBytes($secretBytes)
$random.Dispose()
$password = [Convert]::ToBase64String($secretBytes)
$env:LIFESYNC_RELEASE_PASSWORD = $password
try {
    & $Keytool -genkeypair -noprompt -keystore $keystorePath -storetype JKS `
        -alias lifesync -keyalg RSA -keysize 3072 -sigalg SHA256withRSA `
        -validity 10000 -dname 'CN=LifeSync' `
        -storepass:env LIFESYNC_RELEASE_PASSWORD -keypass:env LIFESYNC_RELEASE_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'No fue posible generar la clave de firma.' }
    $properties = "storeFile=lifesync-release.jks`nstorePassword=$password`nkeyAlias=lifesync`nkeyPassword=$password`n"
    [IO.File]::WriteAllText($propertiesPath, $properties, [Text.UTF8Encoding]::new($false))
    Write-Output 'Clave de producción y key.properties creados. Guarda ambos en un respaldo privado.'
} finally {
    Remove-Item Env:LIFESYNC_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    $password = $null
    $properties = $null
    [Array]::Clear($secretBytes, 0, $secretBytes.Length)
}
