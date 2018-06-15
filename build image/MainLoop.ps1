Write-Host "set up build environment"

Add-Type @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class ServerCertificateValidationCallback
{
    public static void Ignore()
    {
        ServicePointManager.ServerCertificateValidationCallback += 
            delegate
            (
                Object obj, 
                X509Certificate certificate, 
                X509Chain chain, 
                SslPolicyErrors errors
            )
            {
                return true;
            };
    }
}
"@

[ServerCertificateValidationCallback]::Ignore();

$pair = "autobuild:autopassword"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"
$headers = @{ Authorization = $basicAuthValue }

$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Model.Tools.psd1" -wa SilentlyContinue

Write-Host "Create folders"
mkdir -Path "c:\ForBuildStage" | Out-Null
mkdir -Path "c:\ForBuildStage\symbols" | Out-Null
mkdir -Path "c:\ForBuildStage\vsix" | Out-Null

Write-Host "Import Test Toolkit"
Get-ChildItem -Path "C:\TestToolKit\*.fob" | foreach { 
    $objectsFile = $_.FullName
    Import-NAVApplicationObject -Path $objectsFile `
                                -DatabaseName $databaseName `
                                -DatabaseServer $databaseServer `
                                -ImportAction Overwrite `
                                -SynchronizeSchemaChanges Force `
                                -NavServerName localhost `
                                -NavServerInstance NAV `
                                -NavServerManagementPort 7045 `
                                -Confirm:$false
}

$hostname = hostname
$release = $env:bc_release
Write-Host "Download symbols for $release" 
$usURL = 'https://'+$hostname+':7049/NAV/dev/packages?publisher=Microsoft&appName=Application&versionText='+$release
$sysURL = 'https://'+$hostname+':7049/NAV/dev/packages?publisher=Microsoft&appName=System&versionText='+$release
$testURL = 'https://'+$hostname+':7049/NAV/dev/packages?publisher=Microsoft&appName=Test&versionText='+$release
Invoke-RestMethod -Method Get -Uri ($usURL) -Headers $headers -OutFile 'c:\ForBuildStage\symbols\Application.app'
Invoke-RestMethod -Method Get -Uri ($sysURL) -Headers $headers -OutFile 'c:\ForBuildStage\symbols\System.app'
Invoke-RestMethod -Method Get -Uri ($testURL) -Headers $headers -OutFile 'c:\ForBuildStage\symbols\Test.app'

Write-Host "Copy vsix as zip"
$vsixFile = (Get-ChildItem -Path C:\inetpub\wwwroot\http -Filter "al*.vsix")[0]
Rename-Item $vsixFile.FullName -NewName ($vsixFile.Name+'.zip')
Copy-Item -Path ($vsixFile.FullName+'.zip') 'C:\ForBuildStage\vsix'

Copy-Item -Path 'c:\run\my\build.ps1' c:\ForBuildStage
Copy-Item -Path 'c:\run\my\Convert-ALCOutputToTFS.psm1' c:\ForBuildStage
