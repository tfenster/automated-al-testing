param 
([string]$signingPwd)

Import-Module c:\build\Convert-ALCOutputToTFS.psm1

$AdditionalSymbolsFolder = 'C:\AdditionalSymbols'
$ALProjectFolder = 'C:\sources'
$AlPackageOutParent = Join-Path $ALProjectFolder 'out'
$ALPackageCachePath = 'C:\build\symbols'
$ALCompilerPath = 'C:\build\vsix\extension\bin'
$ExtensionAppJsonFile = Join-Path $ALProjectFolder 'app.json'
$ExtensionAppJsonObject = Get-Content -Raw -Path $ExtensionAppJsonFile | ConvertFrom-Json
$Publisher = $ExtensionAppJsonObject.Publisher
$Name = $ExtensionAppJsonObject.Name
$ExtensionName = $Publisher + '_' + $Name + '_' + $ExtensionAppJsonObject.Version + '.app'
$ExtensionAppJsonObject | ConvertTo-Json | set-content $ExtensionAppJsonFile
Write-Host "Using Symbols Folder: " $ALPackageCachePath
Write-Host "Checking for additional symbols"
if (Test-Path (Join-Path $AdditionalSymbolsFolder "*.app")) {
    Copy-Item (Join-Path $AdditionalSymbolsFolder "*.app") -Destination $ALPackageCachePath
}
Write-Host "Using Compiler: " $ALCompilerPath
$AlPackageOutPath = Join-Path $AlPackageOutParent $ExtensionName
if (-not (Test-Path $AlPackageOutParent)) {
    mkdir $AlPackageOutParent
}
Write-Host "Using Output Folder: " $AlPackageOutPath
Set-Location -Path $ALCompilerPath
& .\alc.exe /project:$ALProjectFolder /packagecachepath:$ALPackageCachePath /out:$AlPackageOutPath | Convert-ALCOutputToTFS

if (-not (Test-Path $AlPackageOutPath)) {
    Write-Error "no app file was generated"
    exit 1
}

RegSvr32 /u /s "C:\Windows\System32\NavSip.dll"
RegSvr32 /u /s "C:\Windows\SysWow64\NavSip.dll"
Copy-Item C:\build\32\NavSip.dll C:\Windows\system32
Copy-Item C:\build\64\NavSip.dll C:\Windows\SysWOW64\
RegSvr32 /s "C:\Windows\System32\NavSip.dll"
RegSvr32 /s "C:\Windows\SysWow64\NavSip.dll"

c:\build\signtool.exe sign /f 'C:\build\signcert.p12' /p $signingPwd /t http://timestamp.verisign.com/scripts/timestamp.dll $AlPackageOutPath
