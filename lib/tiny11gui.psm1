#### MODULE MANIFEST FIELD ####

$modulePath = $PSScriptRoot -replace '\\', '/'
$moduleName = "tiny11gui"
$moduleVersion = "2025.11.17"
$moduleAuthor = "chrisGrando"
$moduleCompany = "Tiny11Maker"
$moduleDescription = "Module intended for the UI of tiny11maker script."

New-ModuleManifest -Path "$modulePath/$moduleName.psd1" `
    -RootModule $moduleName `
    -ModuleVersion $moduleVersion `
    -Author $moduleAuthor `
    -CompanyName $moduleCompany `
    -Description $moduleDescription

#### GLOBAL VARIABLES FIELD ####

New-Variable -Name WINDOW_CLOSED -Value $false -Scope Script -Option AllScope
New-Variable -Name MODE_SELECT -Value 0 -Scope Script -Option AllScope
New-Variable -Name INDEX_SELECT -Value 0 -Scope Script -Option AllScope
New-Variable -Name SCREEN_STAGE -Value 0 -Scope Script -Option AllScope
New-Variable -Name TEXTBOX_ISO -Value $null -Scope Script -Option AllScope
New-Variable -Name COMBOBOX_DRIVE -Value $null -Scope Script -Option AllScope
New-Variable -Name BUTTON_BROWSE -Value $null -Scope Script -Option AllScope
New-Variable -Name BUTTON_SEARCH -Value $null -Scope Script -Option AllScope
New-Variable -Name COMBOBOX_INDEX -Value $null -Scope Script -Option AllScope
New-Variable -Name LIST_DRIVES -Value $null -Scope Script -Option AllScope
New-Variable -Name LIST_EDITIONS -Value $null -Scope Script -Option AllScope

#### FUNCTIONS FIELD ####

## Pop-up notification window
function Invoke-PopupInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$title,
        [Parameter(Mandatory=$true)]
        [string]$message
    )

    $ButtonType = [System.Windows.Forms.MessageBoxButtons]::OK
    $MessageIcon = [System.Windows.Forms.MessageBoxIcon]::Information
    $null = [System.Windows.Forms.MessageBox]::Show($message, $title, $ButtonType, $MessageIcon)
}

## Pop-up error window
function Invoke-PopupError {
    param (
        [Parameter(Mandatory=$true)]
        [string]$title,
        [Parameter(Mandatory=$true)]
        [string]$message
    )

    $ButtonType = [System.Windows.Forms.MessageBoxButtons]::OK
    $MessageIcon = [System.Windows.Forms.MessageBoxIcon]::Error
    $null = [System.Windows.Forms.MessageBox]::Show($message, $title, $ButtonType, $MessageIcon)
}

## Pop-up yes or no choice window
function Invoke-PopupYesOrNo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$title,
        [Parameter(Mandatory=$true)]
        [string]$message
    )

    $ButtonType = [System.Windows.Forms.MessageBoxButtons]::YesNo
    $MessageIcon = [System.Windows.Forms.MessageBoxIcon]::Question
    $Result = [System.Windows.Forms.MessageBox]::Show($message, $title, $ButtonType, $MessageIcon)

    if ($Result -eq [System.Windows.Forms.DialogResult]::Yes) {
        return $true
    }

    return $false
}

## Dialog window to select a ISO file and get it's full path
function Open-IsoFile {
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Title = "Select Windows 11 ISO file"
        InitialDirectory = [Environment]::GetFolderPath('Desktop') 
        Filter = 'ISO image (*.iso)|*.iso'
    }

    $null = $FileBrowser.ShowDialog()
    return $FileBrowser.FileName
}

## Sets a list of avaliable system file drives
function Set-DrivesList {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$list
    )

    $LIST_DRIVES = $list
}

## Sets a list of avaliable Windows 11 editions
function Set-EditionsList {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$list
    )

    $LIST_EDITIONS = $list
}

## Auto-Detects which drive has a Windows setup image
function Invoke-AutoDetect {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$drivesList
    )

    foreach ($drive in $drivesList) {
        if ((Test-Path "$($drive)sources\install.esd") -or (Test-Path "$($drive)sources\install.wim")) {
            Invoke-PopupInfo -title "Drive found" -message "Windows setup image found at $drive"
            return $drive
        }
    }

    Invoke-PopupError -title "Not found" -message "Unable to find a mounted Windows setup image!"
    return $drivesList[0]
}

## Update the events of the window and keep it from closing
function Update-EventLoop {
    param(
        [Parameter(Mandatory=$true)]
        [int]$stage
    )

    while (-not $WINDOW_CLOSED -and $SCREEN_STAGE -eq $stage) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 33 # ~30 FPS
    }
}

## Gets the current screen stage
function Get-ScreenStage {
    return $SCREEN_STAGE
}

## Gets the selected mode (mount ISO file / use already mounted drive)
function Get-ModeSelect {
    return $MODE_SELECT
}

## Gets the full path to the ISO file
function Get-IsoPath {
    return $TEXTBOX_ISO.Text
}

## Gets the selected mounted drive
function Get-SelectedDrive {
    return $COMBOBOX_DRIVE.SelectedItem.ToString()
}

## Gets the selected Windows setup image index
function Get-SelectedImageIndex {
    return $INDEX_SELECT
}

## Checks whenever or not the user can proceed to the next step
function Validate-NextStep {
    # No mode selected
    if ($MODE_SELECT -eq 0) {
        Invoke-PopupError -title "No mode selected" -message "Please, select a mounting mode first!"
        return $null
    }
    
    # Path to ISO file not found
    if ($MODE_SELECT -eq 1) {
        $isoExists = Test-Path $(Get-IsoPath)
        
        if (-not $isoExists) {
            Invoke-PopupError -title "Not found" -message "ISO file not found!"
            return $null
        }
    }
    
    # Mounted drive doesn't contain a Windows setup image
    if ($MODE_SELECT -eq 2) {
        $hasESD = Test-Path "$(Get-SelectedDrive)sources\install.esd"
        $hasWIN = Test-Path "$(Get-SelectedDrive)sources\install.win"
        
        if ((-not $hasESD) -and (-not $hasWIN)) {
            Invoke-PopupError -title "Setup not found" -message "$(Get-SelectedDrive) doesn't contain setup files!"
            return $null
        }
    }

    # Passed checks, next stage!
    $SCREEN_STAGE = 1
}

## Checks whenever or not the user can create the Tiny11 ISO
function Validate-CreateTiny11 {
    # No valid image index found
    if (($LIST_EDITIONS -eq $null) -or ($LIST_EDITIONS.count -eq 0) -or ($LIST_EDITIONS[0] -eq "No image index found")) {
        Invoke-PopupError -title "No index found" -message "Unable to find a valid image index!"
        $WINDOW_CLOSED = $true
        return $null
    }

    # Passed checks, create Tiny11 ISO!
    $INDEX_SELECT = $($COMBOBOX_INDEX.SelectedIndex + 1)
    $SCREEN_STAGE = 2
}

## Script's main window
function Invoke-MainForm {
    param(
        [Parameter(Mandatory=$true)]
        [string]$title,
        [Parameter(Mandatory=$true)]
        [string]$version,
        [Parameter(Mandatory=$true)]
        [string]$icoPath,
        [Parameter(Mandatory=$true)]
        [string]$splashPath
    )

    # Window resources
    $AppIconObj = New-Object System.Drawing.Icon($icoPath)
    $AppSplashObj = [System.Drawing.Image]::Fromfile($splashPath)

    # Create the window
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $FormWindow = New-Object System.Windows.Forms.Form
    $FormWindow.Text = "$title - $version"
    $FormWindow.Icon = $AppIconObj
    $FormWindow.Width = 800
    $FormWindow.Height = 600
    $FormWindow.BackColor = "White"
    $FormWindow.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $FormWindow.MaximizeBox = $false
    $FormWindow.MinimizeBox = $false
    $FormWindow.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

    # Splash image
    $SplashPictureBox = New-Object System.Windows.Forms.PictureBox
    $SplashPictureBox.Image = $AppSplashObj
    $SplashPictureBox.Width = 800
    $SplashPictureBox.Height = 300
    $SplashPictureBox.Left = 0
    $SplashPictureBox.Top = -15
    $SplashPictureBox.BackColor = [System.Drawing.Color]::Transparent
    $SplashPictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $FormWindow.Controls.Add($SplashPictureBox)

    # Register a closed event
    $FormWindow.Add_FormClosed({ $WINDOW_CLOSED = $true })

    return $FormWindow
}

## UI for mount mode
function Invoke-MountMode {
    $MyFontFamily = New-Object System.Drawing.FontFamily -ArgumentList "Cambria"

    $MountPanel = New-Object System.Windows.Forms.Panel
    $MountPanel.Location = New-Object System.Drawing.Point -ArgumentList 0, 0
    $MountPanel.Size = New-Object System.Drawing.Size -ArgumentList 800, 600
    $MountPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::None

    $LabelMountMode = New-Object System.Windows.Forms.Label
    $LabelMountMode.Text = "Please, select the mounting mode below:"
    $LabelMountMode.Font = New-Object System.Drawing.Font($MyFontFamily, 16.0, [System.Drawing.FontStyle]::Bold)
    $LabelMountMode.Location = New-Object System.Drawing.Point -ArgumentList 0, 270
    $LabelMountMode.Size = New-Object System.Drawing.Size -ArgumentList 800, 50
    $LabelMountMode.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    $RadioButtonIso = New-Object System.Windows.Forms.RadioButton
    $RadioButtonDrive = New-Object System.Windows.Forms.RadioButton

    $ModeGroupBox = New-Object System.Windows.Forms.GroupBox
    $ModeGroupBox.Controls.Add($RadioButtonIso)
    $ModeGroupBox.Controls.Add($RadioButtonDrive)
    $ModeGroupBox.Location = New-Object System.Drawing.Point -ArgumentList 0, 285
    $ModeGroupBox.Size = New-Object System.Drawing.Size -ArgumentList 800, 300

    $RadioButtonIso.Location = New-Object System.Drawing.Point -ArgumentList 250, 10
    $RadioButtonIso.Size = New-Object System.Drawing.Size -ArgumentList 280, 100
    $RadioButtonIso.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $RadioButtonIso.Font = New-Object System.Drawing.Font($MyFontFamily, 14.0, [System.Drawing.FontStyle]::Regular)
    $RadioButtonIso.Text = "Mount a ISO file:"
    $RadioButtonIso.Add_Click({ $MODE_SELECT = 1; $TEXTBOX_ISO.Enabled = $true; $COMBOBOX_DRIVE.Enabled = $false; $BUTTON_BROWSE.Enabled = $true; $BUTTON_SEARCH.Enabled = $false })
    $RadioButtonIso.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $RadioButtonIso.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Arrow })

    $TEXTBOX_ISO = $(New-Object System.Windows.Forms.TextBox)
    $TEXTBOX_ISO.Multiline = $false
    $TEXTBOX_ISO.AcceptsTab = $false
    $TEXTBOX_ISO.AcceptsReturn = $false
    $TEXTBOX_ISO.Location = New-Object System.Drawing.Point -ArgumentList 0, 70
    $TEXTBOX_ISO.Size = New-Object System.Drawing.Size -ArgumentList 280, 45
    $TEXTBOX_ISO.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
    $TEXTBOX_ISO.BorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $TEXTBOX_ISO.ForeColor = [System.Drawing.Color]::Black
    $TEXTBOX_ISO.BackColor = [System.Drawing.Color]::WhiteSmoke
    $TEXTBOX_ISO.Font = New-Object System.Drawing.Font($MyFontFamily, 13.0, [System.Drawing.FontStyle]::Regular)
    $TEXTBOX_ISO.Enabled = $false
    $RadioButtonIso.Controls.Add($TEXTBOX_ISO)

    $LabelPathToIso = New-Object System.Windows.Forms.Label
    $LabelPathToIso.Text = "Full path:"
    $LabelPathToIso.Font = New-Object System.Drawing.Font($MyFontFamily, 13.0, [System.Drawing.FontStyle]::Regular)
    $LabelPathToIso.Location = New-Object System.Drawing.Point -ArgumentList 165, 368
    $LabelPathToIso.Size = New-Object System.Drawing.Size -ArgumentList 80, 20
    $LabelPathToIso.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight

    $BUTTON_BROWSE = $(New-Object System.Windows.Forms.Button)
    $BUTTON_BROWSE.Location = New-Object System.Drawing.Point -ArgumentList 538, 364
    $BUTTON_BROWSE.Size = New-Object System.Drawing.Size -ArgumentList 80, 31
    $BUTTON_BROWSE.ForeColor = [System.Drawing.Color]::Black
    $BUTTON_BROWSE.BackColor = [System.Drawing.Color]::WhiteSmoke
    $BUTTON_BROWSE.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $BUTTON_BROWSE.Font = New-Object System.Drawing.Font($MyFontFamily, 13.0, [System.Drawing.FontStyle]::Regular)
    $BUTTON_BROWSE.Text = "Browse"
    $BUTTON_BROWSE.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $BUTTON_BROWSE.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Arrow })
    $BUTTON_BROWSE.Enabled = $false
    $BUTTON_BROWSE.Add_Click({ $TEXTBOX_ISO.Text = Open-IsoFile })

    $RadioButtonDrive.Location = New-Object System.Drawing.Point -ArgumentList 250, 90
    $RadioButtonDrive.Size = New-Object System.Drawing.Size -ArgumentList 280, 100
    $RadioButtonDrive.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $RadioButtonDrive.Font = New-Object System.Drawing.Font($MyFontFamily, 14.0, [System.Drawing.FontStyle]::Regular)
    $RadioButtonDrive.Text = "Use a already mounted drive:"
    $RadioButtonDrive.Add_Click({ $MODE_SELECT = 2; $TEXTBOX_ISO.Enabled = $false; $COMBOBOX_DRIVE.Enabled = $true; $BUTTON_BROWSE.Enabled = $false; $BUTTON_SEARCH.Enabled = $true })
    $RadioButtonDrive.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $RadioButtonDrive.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Arrow })

    $COMBOBOX_DRIVE = $(New-Object System.Windows.Forms.ComboBox)
    $COMBOBOX_DRIVE.Location = New-Object System.Drawing.Point -ArgumentList 100, 70
    $COMBOBOX_DRIVE.Size = New-Object System.Drawing.Size -ArgumentList 70, 45
    $COMBOBOX_DRIVE.ForeColor = [System.Drawing.Color]::Black
    $COMBOBOX_DRIVE.BackColor = [System.Drawing.Color]::WhiteSmoke
    $COMBOBOX_DRIVE.Font = New-Object System.Drawing.Font($MyFontFamily, 13.0, [System.Drawing.FontStyle]::Regular)
    $COMBOBOX_DRIVE.Items.AddRange($LIST_DRIVES)
    $COMBOBOX_DRIVE.SelectedIndex = 0
    $COMBOBOX_DRIVE.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $COMBOBOX_DRIVE.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $COMBOBOX_DRIVE.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Arrow })
    $COMBOBOX_DRIVE.Enabled = $false
    $RadioButtonDrive.Controls.Add($COMBOBOX_DRIVE)

    $LabelDrive = New-Object System.Windows.Forms.Label
    $LabelDrive.Text = "Drive:"
    $LabelDrive.Font = New-Object System.Drawing.Font($MyFontFamily, 13.0, [System.Drawing.FontStyle]::Regular)
    $LabelDrive.Location = New-Object System.Drawing.Point -ArgumentList 265, 448
    $LabelDrive.Size = New-Object System.Drawing.Size -ArgumentList 60, 20
    $LabelDrive.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight

    $BUTTON_SEARCH = $(New-Object System.Windows.Forms.Button)
    $BUTTON_SEARCH.Location = New-Object System.Drawing.Point -ArgumentList 435, 444
    $BUTTON_SEARCH.Size = New-Object System.Drawing.Size -ArgumentList 80, 31
    $BUTTON_SEARCH.ForeColor = [System.Drawing.Color]::Black
    $BUTTON_SEARCH.BackColor = [System.Drawing.Color]::WhiteSmoke
    $BUTTON_SEARCH.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $BUTTON_SEARCH.Font = New-Object System.Drawing.Font($MyFontFamily, 13.0, [System.Drawing.FontStyle]::Regular)
    $BUTTON_SEARCH.Text = "Search"
    $BUTTON_SEARCH.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $BUTTON_SEARCH.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Arrow })
    $BUTTON_SEARCH.Enabled = $false
    $BUTTON_SEARCH.Add_Click({ $COMBOBOX_DRIVE.SelectedIndex = $COMBOBOX_DRIVE.Items.IndexOf($(Invoke-AutoDetect $LIST_DRIVES)) })

    $SearchTip = New-Object System.Windows.Forms.ToolTip
    $TipText = "Automatically searches for a drive with the[br]Windows setup image on it and selects it[br]on the list." -replace "\[br\]", "`n"
    $SearchTip.AutoPopDelay = 5000
    $SearchTip.InitialDelay = 1000
    $SearchTip.ReshowDelay = 500
    $SearchTip.ShowAlways = $false
    $SearchTip.SetToolTip($BUTTON_SEARCH, $TipText)

    $ButtonNext = New-Object System.Windows.Forms.Button
    $ButtonNext.Location = New-Object System.Drawing.Point -ArgumentList 310, 505
    $ButtonNext.Size = New-Object System.Drawing.Size -ArgumentList 150, 50
    $ButtonNext.ForeColor = [System.Drawing.Color]::Black
    $ButtonNext.BackColor = [System.Drawing.Color]::WhiteSmoke
    $ButtonNext.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $ButtonNext.Font = New-Object System.Drawing.Font($MyFontFamily, 18.0, [System.Drawing.FontStyle]::Regular)
    $ButtonNext.Text = "Next"
    $ButtonNext.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $ButtonNext.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Arrow })
    $ButtonNext.Add_Click({ Validate-NextStep })

    $MountPanel.Controls.Add($LabelMountMode)
    $MountPanel.Controls.Add($LabelPathToIso)
    $MountPanel.Controls.Add($BUTTON_BROWSE)
    $MountPanel.Controls.Add($LabelDrive)
    $MountPanel.Controls.Add($BUTTON_SEARCH)
    $MountPanel.Controls.Add($ButtonNext)
    $MountPanel.Controls.Add($ModeGroupBox)
    return $MountPanel
}

## UI for image index mode
function Invoke-ImageIndexMode {
    $MyFontFamily = New-Object System.Drawing.FontFamily -ArgumentList "Cambria"

    $ImageIndexPanel = New-Object System.Windows.Forms.Panel
    $ImageIndexPanel.Location = New-Object System.Drawing.Point -ArgumentList 0, 0
    $ImageIndexPanel.Size = New-Object System.Drawing.Size -ArgumentList 800, 600
    $ImageIndexPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::None

    $LabelImageIndex = New-Object System.Windows.Forms.Label
    $LabelImageIndex.Text = "Please, select below the image index of the edition you wish to use:"
    $LabelImageIndex.Font = New-Object System.Drawing.Font($MyFontFamily, 16.0, [System.Drawing.FontStyle]::Bold)
    $LabelImageIndex.Location = New-Object System.Drawing.Point -ArgumentList 0, 300
    $LabelImageIndex.Size = New-Object System.Drawing.Size -ArgumentList 800, 50
    $LabelImageIndex.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    $COMBOBOX_INDEX = $(New-Object System.Windows.Forms.ComboBox)
    $COMBOBOX_INDEX.Location = New-Object System.Drawing.Point -ArgumentList 230, 395
    $COMBOBOX_INDEX.Size = New-Object System.Drawing.Size -ArgumentList 320, 45
    $COMBOBOX_INDEX.ForeColor = [System.Drawing.Color]::Black
    $COMBOBOX_INDEX.BackColor = [System.Drawing.Color]::WhiteSmoke
    $COMBOBOX_INDEX.Font = New-Object System.Drawing.Font($MyFontFamily, 13.0, [System.Drawing.FontStyle]::Regular)
    $COMBOBOX_INDEX.Items.AddRange($LIST_EDITIONS)
    $COMBOBOX_INDEX.SelectedIndex = 0
    $COMBOBOX_INDEX.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $COMBOBOX_INDEX.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $COMBOBOX_INDEX.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Arrow })

    $ButtonCreate = New-Object System.Windows.Forms.Button
    $ButtonCreate.Location = New-Object System.Drawing.Point -ArgumentList 280, 480
    $ButtonCreate.Size = New-Object System.Drawing.Size -ArgumentList 220, 50
    $ButtonCreate.ForeColor = [System.Drawing.Color]::Black
    $ButtonCreate.BackColor = [System.Drawing.Color]::WhiteSmoke
    $ButtonCreate.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $ButtonCreate.Font = New-Object System.Drawing.Font($MyFontFamily, 18.0, [System.Drawing.FontStyle]::Regular)
    $ButtonCreate.Text = "Create Tiny 11 ISO"
    $ButtonCreate.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $ButtonCreate.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Arrow })
    $ButtonCreate.Add_Click({ Validate-CreateTiny11 })

    $ImageIndexPanel.Controls.Add($LabelImageIndex)
    $ImageIndexPanel.Controls.Add($COMBOBOX_INDEX)
    $ImageIndexPanel.Controls.Add($ButtonCreate)
    return $ImageIndexPanel
}

#### EXPORT FUNCTIONS FIELD ####
Export-ModuleMember -Function Invoke-PopupInfo
Export-ModuleMember -Function Invoke-PopupError
Export-ModuleMember -Function Invoke-PopupYesOrNo
Export-ModuleMember -Function Open-IsoFile
Export-ModuleMember -Function Set-DrivesList
Export-ModuleMember -Function Set-EditionsList
Export-ModuleMember -Function Update-EventLoop
Export-ModuleMember -Function Get-ScreenStage
Export-ModuleMember -Function Get-ModeSelect
Export-ModuleMember -Function Get-IsoPath
Export-ModuleMember -Function Get-SelectedDrive
Export-ModuleMember -Function Get-SelectedImageIndex
Export-ModuleMember -Function Invoke-MainForm
Export-ModuleMember -Function Invoke-MountMode
Export-ModuleMember -Function Invoke-ImageIndexMode
