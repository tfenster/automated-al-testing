$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Model.Tools.psd1" -wa SilentlyContinue

$serviceFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
Import-Module "$serviceFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue

New-NAVServerUser -WindowsAccount (whoami) NAV
New-NAVServerUserPermissionSet -PermissionSetId SUPER -WindowsAccount (whoami) NAV

Write-Host "Import all extensions from ${env:apppath}"
Get-ChildItem $env:apppath -Filter "*.app" | ForEach-Object {
    $ext = Publish-NAVApp -ServerInstance NAV -Path $_.FullName -PassThru
    Sync-NAVApp -ServerInstance NAV -Name $ext.Name -Tenant default
    Install-NAVApp -ServerInstance NAV -Name $ext.Name -Tenant default
}
Write-Host "Import all extensions from ${env:testapppath}"
Get-ChildItem $env:testapppath -Filter "*.app" | ForEach-Object {
    $ext = Publish-NAVApp -ServerInstance NAV -Path $_.FullName -PassThru
    Sync-NAVApp -ServerInstance NAV -Name $ext.Name -Tenant default
    Install-NAVApp -ServerInstance NAV -Name $ext.Name -Tenant default
}

Write-Host "Import test toolkit"
Get-ChildItem -Path "C:\TestToolKit\*.fob" | ForEach-Object { 
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

Write-Host "Invoke auto test CUs ${env:codeunitids}"
$companyname = (Get-NAVCompany NAV)[0].CompanyName
Invoke-NAVCodeunit -ServerInstance NAV -CompanyName $companyname -CodeunitId 50104 -MethodName RunTestCodeunitsCS -Argument $env:codeunitids

Write-Host "Get Results"
$hostname = (hostname)
$proxy = New-WebServiceProxy -Uri "http://${hostname}:7047/NAV/WS/$companyname/Codeunit/TestHandling" -UseDefaultCredential
$proxy.GetResultsForCodeunitsCS($env:codeunitids) | Out-File "${env:logpath}\result.xml" -Encoding utf8
