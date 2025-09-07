# Uncomment the line below to enable debugging
# Set-PSDebug -Trace 1

param (
    [string]$ScratchDisk
)

if (-not $ScratchDisk) {
    $ScratchDisk = $PSScriptRoot
}

Import-Module -Name "$($PSScriptRoot -replace '\\', '/')/lib/tiny11utils.psm1"

# Check if PowerShell execution is restricted
if ((Get-ExecutionPolicy) -eq 'Restricted') {
    Write-Host "Your current PowerShell Execution Policy is set to Restricted, which prevents scripts from running. Do you want to change it to Bypass? (Y/N)"
    $response = Read-Host
    if ($response.ToLower() -eq 'y') {
        Set-ExecutionPolicy Bypass -Scope Process -Confirm:$false
    }
    else {
        Write-Host "Can't run the script without changing the execution policy. Exiting..."

        Write-Host ' '
        Write-Host "Press any key to exit the script..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
}

# Check and run the script as admin if required
$adminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$adminGroup = $adminSID.Translate([System.Security.Principal.NTAccount])
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
if (! $myWindowsPrincipal.IsInRole($adminRole)) {
    Write-Host "Restarting Tiny11 image creator as admin in a new window, you can close this one."
    $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
    $newProcess.Arguments = $myInvocation.MyCommand.Definition;
    $newProcess.Verb = "runas";
    [System.Diagnostics.Process]::Start($newProcess);
    exit 0
}

# Start the transcript and prepare the window
Start-Transcript -Path "$($ScratchDisk)\tiny11.log"

# Get host architecture
$hostArchitecture = $Env:PROCESSOR_ARCHITECTURE

# Download "autounattend.xml" if file doesn't exists
if (-not (Test-Path -Path "$($PSScriptRoot)/autounattend.xml")) {
    Write-Host "Downloading autounattend.xml..."
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ntdevlabs/tiny11builder/refs/heads/main/autounattend.xml" -OutFile "$($PSScriptRoot)\autounattend.xml"
    
    if (Test-Path -Path "$($PSScriptRoot)/autounattend.xml") {
        Write-Host "autounattend.xml downloaded successfully."
    }
    else {
        Write-Error "Failed to download autounattend.xml. Aborting..."

        Write-Host ' '
        Write-Host "Press any key to exit the script..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
}

# Get location of "oscdimg.exe" or download it from the internet
$OSCDIMG = $null
$ADKDepTools = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$($hostarchitecture)\Oscdimg"
$localOSCDIMGPath = "$($PSScriptRoot)\oscdimg.exe"

if ([System.IO.Directory]::Exists($ADKDepTools)) {
    Write-Host "Will be using oscdimg.exe from system ADK."
    $OSCDIMG = "$($ADKDepTools)\oscdimg.exe"
}
else {
    Write-Host "ADK folder not found. Will be using bundled oscdimg.exe."
    
    if (-not (Test-Path -Path $localOSCDIMGPath)) {
        Write-Host "Downloading oscdimg.exe..."
        Invoke-WebRequest -Uri "https://msdl.microsoft.com/download/symbols/oscdimg.exe/3D44737265000/oscdimg.exe" -OutFile $localOSCDIMGPath

        if (Test-Path $localOSCDIMGPath) {
            Write-Host "oscdimg.exe downloaded successfully."
        }
        else {
            Write-Error "Failed to download oscdimg.exe. Aborting..."

            Write-Host ' '
            Write-Host "Press any key to exit the script..."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            exit 1
        }
    }
    else {
        Write-Host "oscdimg.exe already exists locally."
    }

    $OSCDIMG = $localOSCDIMGPath
}

$Host.UI.RawUI.WindowTitle = "Tiny11 image creator for Windows 11 24H2"
Clear-Host
Write-Host "Welcome to the Tiny11 image creator for Windows 11 24H2! Release: 2025-09-07"

New-Item -ItemType Directory -Force -Path "$($ScratchDisk)\tiny11\sources" | Out-Null
do {
    $DriveLetter = Read-Host "Please enter the drive letter for the Windows 11 image"
    if ($DriveLetter -match '^[c-zC-Z]$') {
        $DriveLetter = $DriveLetter + ":"
        Write-Output "Drive letter set to $DriveLetter"
    }
    else {
        Write-Output "Invalid drive letter. Please enter a letter between C and Z."
    }
} while ($DriveLetter -notmatch '^[c-zC-Z]:$')

$askForImageIndex = $true
if ((Test-Path "$($DriveLetter)\sources\boot.wim") -eq $false -or (Test-Path "$($DriveLetter)\sources\install.wim") -eq $false) {
    if ((Test-Path "$($DriveLetter)\sources\install.esd") -eq $true) {
        $askForImageIndex = $false
        Write-Host "Found install.esd!"
        & 'DISM' /English /Get-WimInfo /WimFile:"$($DriveLetter)\sources\install.esd"
        Write-Host '--------------------------------------------------------'
        $index = Read-Host "Please enter the image index"
        Write-Host ' '
        Write-Host 'Converting install.esd to install.wim. This may take a while...'
        & 'DISM' /English /Export-Image /SourceImageFile:"$($DriveLetter)\sources\install.esd" /SourceIndex:$index /DestinationImageFile:"$($ScratchDisk)\tiny11\sources\install.wim" /Compress:max /CheckIntegrity
    }
    else {
        Write-Host "Can't find Windows OS Installation files in the specified Drive Letter..."
        Write-Host "Please enter the correct DVD Drive Letter..."

        Write-Host ' '
        Write-Host "Press any key to exit the script..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
}

Write-Host "Copying Windows image..."
Copy-Item -Path "$($DriveLetter)\*" -Destination "$($ScratchDisk)\tiny11" -Recurse -Force | Out-Null
Set-ItemProperty -Path "$($ScratchDisk)\tiny11\sources\install.esd" -Name IsReadOnly -Value $false > $null 2>&1
Remove-Item "$($ScratchDisk)\tiny11\sources\install.esd" > $null 2>&1
Write-Host "Copy complete!"
Start-Sleep -Seconds 2
Clear-Host

$index = 1
if ($askForImageIndex) {
    Write-Host "Getting image information:"
    & 'DISM' /English /Get-WimInfo /WimFile:"$($ScratchDisk)\tiny11\sources\install.wim"
    Write-Host '--------------------------------------------------------'
    $index = Read-Host "Please enter the image index"
}

Write-Host "Mounting Windows image. This may take a while."
$wimFilePath = "$($ScratchDisk)\tiny11\sources\install.wim"
& 'takeown' '/f' $wimFilePath 
& 'icacls' $wimFilePath "/grant" "$($adminGroup.Value):(F)"

try {
    Set-ItemProperty -Path $wimFilePath -Name IsReadOnly -Value $false -ErrorAction Stop
} catch {
    # This block will catch the error and suppress it.
    Write-Host ' '
}

New-Item -ItemType Directory -Force -Path "$($ScratchDisk)\scratchdir" > $null
& 'DISM' /English /Mount-Image /ImageFile:"$($ScratchDisk)\tiny11\sources\install.wim" /Index:$index /MountDir:"$($ScratchDisk)\scratchdir"

$imageIntl = & 'DISM' /English /Get-Intl /Image:"$($ScratchDisk)\scratchdir"
$languageLine = $imageIntl -split '\n' | Where-Object { $_ -match 'Default system UI language : ([a-zA-Z]{2}-[a-zA-Z]{2})' }

if ($languageLine) {
    $languageCode = $Matches[1]
    Write-Host "Default system UI language code: $languageCode"
}
else {
    Write-Host "Default system UI language code not found."
}

$imageInfo = & 'DISM' /English /Get-WimInfo /WimFile:"$($ScratchDisk)\tiny11\sources\install.wim" /Index:$index
$lines = $imageInfo -split '\r?\n'

foreach ($line in $lines) {
    if ($line -like '*Architecture : *') {
        $architecture = $line -replace 'Architecture : ',''
        # If the architecture is x64, replace it with amd64
        if ($architecture -eq 'x64') {
            $architecture = 'amd64'
        }
        Write-Host "Architecture: $architecture"
        break
    }
}

if (-not $architecture) {
    Write-Host "Architecture information not found."
}

Write-Host '--------------------------------------------------------'
Write-Host "Mounting complete! Performing removal of applications..."

$packages = & 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Get-ProvisionedAppxPackages |
    ForEach-Object {
        if ($_ -match 'PackageName : (.*)') {
            $matches[1]
        }
    }

$packagePrefixes = 'AppUp.IntelManagementandSecurityStatus',
'Clipchamp.Clipchamp', 
'DolbyLaboratories.DolbyAccess',
'DolbyLaboratories.DolbyDigitalPlusDecoderOEM',
'Microsoft.BingNews',
'Microsoft.BingSearch',
'Microsoft.BingWeather',
'Microsoft.Copilot',
'Microsoft.Windows.CrossDevice',
'Microsoft.GamingApp',
'Microsoft.GetHelp',
'Microsoft.Getstarted',
'Microsoft.Microsoft3DViewer',
'Microsoft.MicrosoftOfficeHub',
'Microsoft.MicrosoftSolitaireCollection',
'Microsoft.MicrosoftStickyNotes',
'Microsoft.MixedReality.Portal',
'Microsoft.MSPaint',
'Microsoft.Office.OneNote',
'Microsoft.OfficePushNotificationUtility',
'Microsoft.OutlookForWindows',
'Microsoft.Paint',
'Microsoft.People',
'Microsoft.PowerAutomateDesktop',
'Microsoft.SkypeApp',
'Microsoft.StartExperiencesApp',
'Microsoft.Todos',
'Microsoft.Wallet',
'Microsoft.Windows.DevHome',
'Microsoft.Windows.Copilot',
'Microsoft.Windows.Teams',
'Microsoft.WindowsAlarms',
'Microsoft.WindowsCamera',
'microsoft.windowscommunicationsapps',
'Microsoft.WindowsFeedbackHub',
'Microsoft.WindowsMaps',
'Microsoft.WindowsSoundRecorder',
'Microsoft.WindowsTerminal',
'Microsoft.Xbox.TCUI',
'Microsoft.XboxApp',
'Microsoft.XboxGameOverlay',
'Microsoft.XboxGamingOverlay',
'Microsoft.XboxIdentityProvider',
'Microsoft.XboxSpeechToTextOverlay',
'Microsoft.YourPhone',
'Microsoft.ZuneMusic',
'Microsoft.ZuneVideo',
'MicrosoftCorporationII.MicrosoftFamily',
'MicrosoftCorporationII.QuickAssist',
'MSTeams',
'MicrosoftTeams', 
'Microsoft.WindowsTerminal',
'Microsoft.549981C3F5F10'

$packagesToRemove = $packages | Where-Object {
    $packageName = $_
    $packagePrefixes -contains ($packagePrefixes | Where-Object { $packageName -like "$_*" })
}

foreach ($package in $packagesToRemove) {
    Write-Host "Removing application: $package"
    & 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Remove-ProvisionedAppxPackage /PackageName:"$package"
}

Write-Host '--------------------------------------------------------'
Write-Host "Removing of system apps complete! Now proceeding to removal of system packages..."
Start-Sleep -Seconds 1

$packagePatterns = @(
    "Microsoft-Windows-InternetExplorer-Optional-Package~",
    "Microsoft-Windows-LanguageFeatures-Handwriting-$($languageCode)-Package~",
    "Microsoft-Windows-LanguageFeatures-OCR-$($languageCode)-Package~",
    "Microsoft-Windows-LanguageFeatures-Speech-$($languageCode)-Package~",
    "Microsoft-Windows-LanguageFeatures-TextToSpeech-$($languageCode)-Package~",
    "Microsoft-Windows-MediaPlayer-Package~",
    "Microsoft-Windows-Wallpaper-Content-Extended-FoD-Package~",
    "Microsoft-Windows-WordPad-FoD-Package~",
    "Microsoft-Windows-TabletPCMath-Package~",
    "Microsoft-Windows-StepsRecorder-Package~"
)

# Get all packages
$allPackages = & 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Get-Packages /Format:Table
$allPackages = $allPackages -split "`n" | Select-Object -Skip 1

foreach ($packagePattern in $packagePatterns) {
    # Filter the packages to remove
    $packagesToRemove = $allPackages | Where-Object { $_ -like "$packagePattern*" }

    foreach ($package in $packagesToRemove) {
        # Extract the package identity
        $packageIdentity = ($package -split "\s+")[0]

        Write-Host "Removing package: $packageIdentity"
        & 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Remove-Package /PackageName:$packageIdentity 
    }
}

Write-Host '--------------------------------------------------------'
Write-Output "Removing Edge..."
Remove-Item -Path "$($ScratchDisk)\scratchdir\Program Files (x86)\Microsoft\Edge" -Recurse -Force | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir\Program Files (x86)\Microsoft\EdgeCore" -Recurse -Force | Out-Null
& 'takeown' '/f' "$($ScratchDisk)\scratchdir\Windows\System32\Microsoft-Edge-Webview" '/r' | Out-Null
& 'icacls' "$($ScratchDisk)\scratchdir\Windows\System32\Microsoft-Edge-Webview" '/grant' "$($adminGroup.Value):(F)" '/T' '/C' | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir\Windows\System32\Microsoft-Edge-Webview" -Recurse -Force | Out-Null

Write-Output "Removing OneDrive..."
& 'takeown' '/f' "$($ScratchDisk)\scratchdir\Windows\System32\OneDriveSetup.exe" | Out-Null
& 'icacls' "$($ScratchDisk)\scratchdir\Windows\System32\OneDriveSetup.exe" '/grant' "$($adminGroup.Value):(F)" '/T' '/C' | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir\Windows\System32\OneDriveSetup.exe" -Force | Out-Null

Write-Output "Removal complete!"
Start-Sleep -Seconds 2

Write-Host '--------------------------------------------------------'
Write-Host "Loading registry..."
& 'reg' 'load' 'HKLM\zCOMPONENTS' '$($ScratchDisk)\scratchdir\Windows\System32\config\COMPONENTS' > $null 2>&1
& 'reg' 'load' 'HKLM\zDEFAULT' '$($ScratchDisk)\scratchdir\Windows\System32\config\default' > $null 2>&1
& 'reg' 'load' 'HKLM\zNTUSER' '$($ScratchDisk)\scratchdir\Users\Default\ntuser.dat' > $null 2>&1
& 'reg' 'load' 'HKLM\zSOFTWARE' '$($ScratchDisk)\scratchdir\Windows\System32\config\SOFTWARE' > $null 2>&1
& 'reg' 'load' 'HKLM\zSYSTEM' '$($ScratchDisk)\scratchdir\Windows\System32\config\SYSTEM' > $null 2>&1

Write-Output "Bypassing system requirements (on the system image)..."
Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassCPUCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassRAMCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassSecureBootCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassStorageCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassTPMCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\MoSetup' 'AllowUpgradesWithUnsupportedTPMOrCPU' 'REG_DWORD' '1'

Write-Output "Disabling Sponsored Apps..."
Set-RegistryValue 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'OemPreInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'ContentDeliveryAllowed' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\Start' 'ConfigureStartPins' 'REG_SZ' '{"pinnedList": [{}]}'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'ContentDeliveryAllowed' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'ContentDeliveryAllowed' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'FeatureManagementEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'OemPreInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEverEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContentEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-310093Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338393Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353694Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353696Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContentEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\PushToInstall' 'DisablePushToInstall' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\MRT' 'DontOfferThroughWUAU' 'REG_DWORD' '1'
Remove-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions'
Remove-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SuggestedApps'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 'REG_DWORD' '1'

Write-Output "Enabling Local Accounts on OOBE..."
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' 'BypassNRO' 'REG_DWORD' '1'
Copy-Item -Path "$PSScriptRoot\autounattend.xml" -Destination "$($ScratchDisk)\scratchdir\Windows\System32\Sysprep\autounattend.xml" -Force | Out-Null

Write-Output "Disabling Reserved Storage..."
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager' 'ShippedWithReserves' 'REG_DWORD' '0'

Write-Output "Disabling BitLocker Device Encryption..."
Set-RegistryValue 'HKLM\zSYSTEM\ControlSet001\Control\BitLocker' 'PreventDeviceEncryption' 'REG_DWORD' '1'

Write-Output "Disabling Chat icon..."
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Chat' 'ChatIcon' 'REG_DWORD' '3'
Set-RegistryValue 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn' 'REG_DWORD' '0'

Write-Output "Removing Edge related registries..."
Remove-RegistryValue "HKEY_LOCAL_MACHINE\zSOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge"
Remove-RegistryValue "HKEY_LOCAL_MACHINE\zSOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update"

Write-Output "Disabling OneDrive folder backup..."
Set-RegistryValue "HKLM\zSOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" "REG_DWORD" "1"

Write-Output "Disabling Telemetry..."
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Input\TIPC' 'Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSYSTEM\ControlSet001\Services\dmwappushservice' 'Start' 'REG_DWORD' '4'

Write-Output "Prevents installation or DevHome and Outlook..."
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate' 'workCompleted' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate' 'workCompleted' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate' 'workCompleted' 'REG_DWORD' '1'
Remove-RegistryValue 'HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate'
Remove-RegistryValue 'HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate'

Write-Output "Disabling Copilot..."
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 'REG_DWORD' '1'

Write-Output "Prevents installation of Teams..."
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Teams' 'DisableInstallation' 'REG_DWORD' '1'

Write-Output "Prevent installation of New Outlook..."
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Mail' 'PreventRun' 'REG_DWORD' '1'

Write-Host "Ownership of the Scheduled Tasks registry:"
Enable-Privilege SeTakeOwnershipPrivilege

try {
    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::TakeOwnership)
    $regACL = $regKey.GetAccessControl()
    $regACL.SetOwner($adminGroup)
    $regKey.SetAccessControl($regACL)
    $regKey.Close()
    Write-Host "Owner changed to Administrators."
} catch {
    Write-Host "No need to change owner to Administrators."
}

try {
    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
    $regACL = $regKey.GetAccessControl()
    $regRule = New-Object System.Security.AccessControl.RegistryAccessRule ($adminGroup,"FullControl","ContainerInherit","None","Allow")
    $regACL.SetAccessRule($regRule)
    $regKey.SetAccessControl($regACL)
    $regKey.Close()
    Write-Host "Permissions modified for Administrators group."
} catch {
    Write-Host "No need to modify permissions for Administrators group."
}

Write-Host "Registry key permissions updated!"

Write-Host "Deleting scheduled task definition files..."
$tasksPath = "$($ScratchDisk)\scratchdir\Windows\System32\Tasks"

# Application Compatibility Appraiser
Remove-Item -Path "$tasksPath\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -Force -ErrorAction SilentlyContinue

# Customer Experience Improvement Program (removes the entire folder and all tasks within it)
Remove-Item -Path "$tasksPath\Microsoft\Windows\Customer Experience Improvement Program" -Recurse -Force -ErrorAction SilentlyContinue

# Program Data Updater
Remove-Item -Path "$tasksPath\Microsoft\Windows\Application Experience\ProgramDataUpdater" -Force -ErrorAction SilentlyContinue

# Chkdsk Proxy
Remove-Item -Path "$tasksPath\Microsoft\Windows\Chkdsk\Proxy" -Force -ErrorAction SilentlyContinue

# Windows Error Reporting (QueueReporting)
Remove-Item -Path "$tasksPath\Microsoft\Windows\Windows Error Reporting\QueueReporting" -Force -ErrorAction SilentlyContinue
Write-Host "Task files have been deleted!"

Write-Host "Tweaking complete!"
Write-Host "Unmounting Registry..."
& 'reg' 'unload' 'HKLM\zCOMPONENTS' > $null 2>&1
& 'reg' 'unload' 'HKLM\zDEFAULT' > $null 2>&1
& 'reg' 'unload' 'HKLM\zNTUSER' > $null 2>&1
& 'reg' 'unload' 'HKLM\zSOFTWARE' > $null 2>&1
& 'reg' 'unload' 'HKLM\zSYSTEM' > $null 2>&1

Write-Host '--------------------------------------------------------'
Write-Host "Cleaning up image..."
& 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Cleanup-Image /StartComponentCleanup /ResetBase

Write-Host "Cleanup complete."
Write-Host ' '

Write-Host "Unmounting image..."
& 'DISM' /English /Unmount-Image /MountDir:"$($ScratchDisk)\scratchdir" /Commit

Write-Host "Exporting image..."
& 'DISM' /English /Export-Image /SourceImageFile:"$($ScratchDisk)\tiny11\sources\install.wim" /SourceIndex:"$index" /DestinationImageFile:"$($ScratchDisk)\tiny11\sources\install2.wim" /Compress:max
Remove-Item -Path "$($ScratchDisk)\tiny11\sources\install.wim" -Force | Out-Null
Rename-Item -Path "$($ScratchDisk)\tiny11\sources\install2.wim" -NewName "install.wim" | Out-Null
Write-Host "Windows image completed. Continuing with boot.wim."
Start-Sleep -Seconds 2

Write-Host '--------------------------------------------------------'
Write-Host "Mounting boot image:"
$wimFilePath = "$($ScratchDisk)\tiny11\sources\boot.wim" 
& 'takeown' "/f" $wimFilePath > $null 2>&1
& 'icacls' $wimFilePath "/grant" "$($adminGroup.Value):(F)" > $null 2>&1
Set-ItemProperty -Path $wimFilePath -Name IsReadOnly -Value $false
& 'DISM' /English /Mount-Image /ImageFile:"$($ScratchDisk)\tiny11\sources\boot.wim" /Index:2 /MountDir:"$($ScratchDisk)\scratchdir"

Write-Host "Loading registry..."
& 'reg' 'load' 'HKLM\zDEFAULT' '$($ScratchDisk)\scratchdir\Windows\System32\config\default' > $null 2>&1
& 'reg' 'load' 'HKLM\zNTUSER' '$($ScratchDisk)\scratchdir\Users\Default\ntuser.dat' > $null 2>&1
& 'reg' 'load' 'HKLM\zSYSTEM' '$($ScratchDisk)\scratchdir\Windows\System32\config\SYSTEM' > $null 2>&1

Write-Host "Bypassing system requirements (on the setup image)..."
Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassCPUCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassRAMCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassSecureBootCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassStorageCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassTPMCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\MoSetup' 'AllowUpgradesWithUnsupportedTPMOrCPU' 'REG_DWORD' '1'

Write-Host "Tweaking complete!"
Write-Host "Unmounting Registry..."
& 'reg' 'unload' 'HKLM\zDEFAULT' > $null 2>&1
& 'reg' 'unload' 'HKLM\zNTUSER' > $null 2>&1
& 'reg' 'unload' 'HKLM\zSYSTEM' > $null 2>&1

Write-Host "Unmounting image..."
& 'DISM' /English /Unmount-Image /MountDir:"$($ScratchDisk)\scratchdir" /Commit

Write-Host "Exporting ESD. This may take a while..."
& 'DISM' /English /Export-Image /SourceImageFile:"$($ScratchDisk)\tiny11\sources\install.wim" /SourceIndex:1 /DestinationImageFile:"$($ScratchDisk)\tiny11\sources\install.esd" /Compress:recovery
Remove-Item "$($ScratchDisk)\tiny11\sources\install.wim" > $null 2>&1

Write-Host '--------------------------------------------------------'
Write-Host "The tiny11 image is now completed. Proceeding with the making of the ISO..."
Write-Host "Copying unattended file for bypassing MS account on OOBE..."
Copy-Item -Path "$($PSScriptRoot)\autounattend.xml" -Destination "$($ScratchDisk)\tiny11\autounattend.xml" -Force | Out-Null

Write-Host "Creating ISO image..."
& "$OSCDIMG" '-m' '-o' '-u2' '-udfver102' "-bootdata:2#p0,e,b$($ScratchDisk)\tiny11\boot\etfsboot.com#pEF,e,b$($ScratchDisk)\tiny11\efi\microsoft\boot\efisys.bin" "$($ScratchDisk)\tiny11" "$($PSScriptRoot)\tiny11.iso"

Write-Host "Performing Cleanup..."
Remove-Item -Path "$($ScratchDisk)\tiny11" -Recurse -Force | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir" -Recurse -Force | Out-Null

# Finishing up
Write-Host ' '
Write-Host "Creation completed! Press any key to exit the script..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

# Stop the transcript
Stop-Transcript

exit 0
