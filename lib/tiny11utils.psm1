#### MODULE MANIFEST FIELD ####

$modulePath = $PSScriptRoot -replace '\\', '/'
$moduleName = "tiny11utils"
$moduleVersion = "2025.11.17"
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

New-Variable -Name MODULE_ROOT -Value $modulePath -Scope Script -Option AllScope,Constant

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

## Lists all avaliable file system drives in the machine
function Find-AvaliableDrives {
    $AllDrives = Get-PSDrive -PSProvider FileSystem
    return $AllDrives.Root
}

## Creates a list with the index of avaliable Windows 11 editions
function Find-AllAvaliableEditions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$isoDrive
    )

    $InstallDataPath = "$($isoDrive)sources\install.esd"

    # If install.esd doesn't exists, try install.wim
    if (-not (Test-Path $InstallDataPath)) {
        $InstallDataPath = "$($isoDrive)sources\install.win"
    }

    # If install.win doesn't exists either, then give up
    if (-not (Test-Path $InstallDataPath)) {
        Write-Error "Unable to find file `"install.esd`" or `"install.win`""
        return @("No image index found")
    }

    $EditionsRaw = (& 'DISM' /English /Get-WimInfo /WimFile:$InstallDataPath) -join "`n"
    $EditionsArray = $EditionsRaw.Split("`n")
    $EditionsClean = @()
    $IndexID = 0

    foreach ($item in $EditionsArray) {
        if ($item.Contains("Name : ")) {
            $IndexID += 1
            $EditionsClean += $("$IndexID - " + $item -replace "Name : ", "")
        }
    }

    return $EditionsClean
}

## Mounts a ISO file image and return it's drive path
function Mount-WindowsIso {
    param(
        [Parameter(Mandatory=$true)]
        [string]$filePath
    )

    try {
        $isoDisk = Mount-DiskImage -ImagePath $filePath -StorageType ISO -PassThru
        $isoVolume = Get-Volume -DiskImage $isoDisk
        return $($isoVolume.DriveLetter + ":\")
    } catch {
        Write-Error "Unable to mount file..."
        return $(Find-AvaliableDrives)[-1]
    }
}

#### EXPORT FUNCTIONS FIELD ####
Export-ModuleMember -Function Set-RegistryValue
Export-ModuleMember -Function Remove-RegistryValue
Export-ModuleMember -Function Enable-Privilege
Export-ModuleMember -Function Find-AvaliableDrives
Export-ModuleMember -Function Find-AllAvaliableEditions
Export-ModuleMember -Function Mount-WindowsIso
