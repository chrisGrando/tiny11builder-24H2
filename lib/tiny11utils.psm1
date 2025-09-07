#### MODULE MANIFEST FIELD ####

$modulePath = $PSScriptRoot -replace '\\', '/'
$moduleName = "tiny11utils"
$moduleVersion = "2025.09.07"
$moduleAuthor = "chrisGrando"
$moduleCompany = "Tiny11Maker"
$moduleDescription = "Module intended for commom functions of tiny11maker script."

New-ModuleManifest -Path "$modulePath/$moduleName.psd1" `
    -RootModule $moduleName `
    -ModuleVersion $moduleVersion `
    -Author $moduleAuthor `
    -CompanyName $moduleCompany `
    -Description $moduleDescription

#### GLOBAL VARIABLES FIELD ####

New-Variable -Name MODULE_ROOT -Value $modulePath -Option Constant

#### FUNCTIONS FIELD ####

## Add/Change a key value in the registry
function Set-RegistryValue {
    param (
        [string]$path,
        [string]$name,
        [string]$type,
        [string]$value
    )
    try {
        & 'reg' 'add' $path '/v' $name '/t' $type '/d' $value '/f' > $null 2>&1
        Write-Output "Set registry value: $path\$name"
    } catch {
        Write-Output "Error setting registry value: $_"
    }
}

## Remove a key value from the registry
function Remove-RegistryValue {
    param (
        [string]$path
    )
    try {
        & 'reg' 'delete' $path '/f' > $null 2>&1
        Write-Output "Removed registry value: $path"
    } catch {
        Write-Output "Error removing registry value: $_"
    }
}

## This function allows PowerShell to take ownership of the Scheduled Tasks registry key from TrustedInstaller. Based on Jose Espitia's script.
function Enable-Privilege {
    param(
        [
            ValidateSet("SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
            "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
            "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
            "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
            "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
            "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
            "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
            "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
            "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
            "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
            "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")
        ] $Privilege,
        ## The process on which to adjust the privilege. Defaults to the current process.
        $ProcessId = $pid,
        ## Switch to disable the privilege, rather than enable it.
        [Switch] $Disable
    )

    $srcFilePath = "$($MODULE_ROOT)/AdjPriv.cs"
    $srcAdjPriv = Get-Content -Path $srcFilePath -Raw
    $processHandle = (Get-Process -id $ProcessId).Handle
    $type = Add-Type -TypeDefinition $srcAdjPriv -PassThru
    $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}

#### EXPORT FUNCTIONS FIELD ####
Export-ModuleMember -Function Set-RegistryValue
Export-ModuleMember -Function Remove-RegistryValue
Export-ModuleMember -Function Enable-Privilege
