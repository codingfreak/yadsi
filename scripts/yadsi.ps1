param (
    $DefinitionFile
)

function Get-State {
    $stateFile = "~/.initstate.json"
    if (!(Test-Path $stateFile)) {
        return 0
    }
    return Get-Content $stateFile
}

function Ensure-Choco {
    $choco = Get-Command choco -ErrorAction SilentlyContinue | Measure-Object
    if ($choco.Count -gt 0) {
        return
    }
    # choco is not installed
    Write-StatusStart -Message "Installing choco"
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null
    $added = New-EnvironmentPath -Path "C:\ProgramData\chocolatey\bin"
    if ($added) {
        Write-Host "Choco path was added to PATH."
    }
    Write-StatusResult -Message "Done" -Success
}

function Ensure-Winget {
    # This actually creates a lot of trouble. See https://github.com/microsoft/winget-cli/issues/2666
    return
    $winget = Get-Command winget -ErrorAction SilentlyContinue | Measure-Object
    if ($winget.Count -gt 0) {
        return
    }
    $progressPreference = 'silentlyContinue'
    Write-StatusStart -Message "Installing winget"
    Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle | Out-Null
    Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx | Out-Null
    Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile Microsoft.UI.Xaml.2.7.x64.appx | Out-Null
    Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx | Out-Null
    Add-AppxPackage Microsoft.UI.Xaml.2.7.x64.appx | Out-Null
    Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle | Out-Null
    Write-StatusResult -Message "Done" -Success
}

function Start-Reboot {
    param (
        $ScriptPathAfterReboot,
        $TaskNameSuffix,
        $WaitSeconds = 10
    )
    $user = whoami
    $trigger = New-ScheduledTaskTrigger -AtLogon -User $user
    $terminalPath = "%LocalAppData%\Microsoft\WindowsApps\wt.exe"
    $action = New-ScheduledTaskAction -WorkingDirectory $PSScriptRoot -Execute $terminalPath -Argument $ScriptPathAfterReboot
    Register-ScheduledTask -Action $action -TaskName "Init Script Continuation $TaskNameSuffix" -Trigger $trigger -RunLevel Highest | Out-Null
    Write-Host "Your computer will restart in $WaitSeconds seconds and continue the setup operation after you logged in again. NOTE: It may take a while!" -ForegroundColor Magenta
    Start-Sleep $WaitSeconds
    Restart-Computer -Force | Out-Null
}

function Set-State {
    param (
        $State
    )
    $stateFile = "~/.initstate.json"
    Set-Content $stateFile $State
}

function Write-StatusResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $Message,
        [Parameter(Mandatory = $false)] [switch] $Success,
        [Parameter(Mandatory = $false)] [switch] $Failure
    )
    Process {
        $color = "White"
        if ($Success) {
            $color = "Green"
        }
        if ($Failure) {
            $color = "Red"
        }
        Write-Host "$Message" -ForegroundColor $color
    }
}

function Write-StatusStart {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $Message
    )
    Process {
        Write-Host "$Message..." -NoNewline
    }
}

function New-EnvironmentPath {
    param (
        $Path
    )
    $current = $env:PATH
    if ($current.Contains($Path)) {
        return $false
    }
    $current += ";$Path"
    $env:PATH = $current
    return $true
}

function Get-IsSessionElevated {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RunsInTerminal {
    $currentParentId = (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $PID").ParentProcessId
    return (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $currentParentId").Name -eq "WindowsTerminal.exe"
}

function Disable-Wallpaper {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value '' -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name BackgroundType -Type DWORD -Value 1 | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name Background -Value "0 0 0" | Out-Null
}

function Get-Summary {
    param (
        $Definition
    )
    # CREATE DEFINITON SUMMARY
    $summary = @{
        Title              = $Definition.title
        ChocoPackages      = 0
        WingetPackages     = 0
        WindowsFeatures    = 0
        PowerShellCommands = 0
        Phases             = 0
        Steps              = 0
        DisabledPhases     = 0
        DisabledSteps      = 0
        Reboots            = 0
    }

    foreach ($phase in $Definition.phases) {
        $summary.Phases++
        if ($phase.disabled -eq $true) {
            $summary.DisabledPhases++
        }
        else {
            if ($phase.reboot -eq $true) {
                $summary.Reboots++
            }
        }
        foreach ($step in $phase.steps) {
            $summary.Steps++
            if ($phase.disabled -eq $true -or $step.disabled -eq $true) {
                $summary.DisabledSteps++
            }
            else {
                if ($step.type -eq 'choco') {
                    foreach ($package in $step.packages) {
                        $summary.ChocoPackages++
                    }
                }
                elseif ($step.type -eq 'winget') {
                    foreach ($package in $step.packages) {
                        $summary.WingetPackages++
                    }
                }
                elseif ($step.type -eq 'winfeat') {
                    foreach ($feature in $step.features) {
                        $summary.WindowsFeatures++
                    }
                }
                elseif ($step.type -eq 'ps') {
                    foreach ($cmd in $step.commands) {
                        $summary.PowerShellCommands++
                    }
                }
            }
        }
    }

    if ($summary.WingetPackages -gt 0) {
        throw "Sadly we are not ready for winget support because it causes potential issues when used from automation. Consider switching to chocolatey.org!"
    }

    return $summary
}

function Write-Summary {
    param (
        $Summary
    )
    Write-Host "`nSUMMARY"
    Write-Host "===============================================`n"
    Write-Host "Title               : $($Summary.title)`n"
    Write-Host "Phases              : $($Summary.Phases) ($($Summary.DisabledPhases) disabled)"
    Write-Host "Steps               : $($Summary.Steps) ($($Summary.DisabledSteps) disabled)"
    Write-Host "Planned reboots     : $($Summary.Reboots)"
    Write-Host "Chocolatey packages : $($Summary.ChocoPackages)"
    #Write-Host "Winget packages     : $($Summary.WingetPackages)"
    Write-Host "Windows features    : $($Summary.WindowsFeatures)"
    Write-Host "Posh commands       : $($Summary.PowerShellCommands)`n"
}

function Switch-FullScreen {
    $wshell = New-Object -ComObject wscript.shell;
    $wshell.SendKeys("{f11}")
}

function Get-IsVirtual {
    return ((Get-WmiObject win32_computersystem).model -eq 'VMware Virtual Platform' `
        -or ((Get-WmiObject win32_computersystem).model -eq 'Virtual Machine'))
}

# ----------------------------------------------
# Main script
# ----------------------------------------------

$ErrorActionPreference = 'Stop'

Clear-Host

# READING CONFIG FILE

$definition = Get-Content $DefinitionFile -Raw | ConvertFrom-Json

# ENSURE WINDOWS TERMINAL

if ($definition.requireWindowsTerminal -eq $true) {
    $isTerminal = Get-RunsInTerminal
    if ($isTerminal -eq $false) {
        throw "Run this tool in a Windows Terminal and be sure to set Windows Terminal as your default terminal in Windows!"
    }
}

# ENSURE ADMINISTRATIVE SESSION

$elevated = Get-IsSessionElevated
if ($elevated -eq $false) {
    throw "Run in an elevated shell!"
}

# MAIN RUN

Write-Host "You are running in elevated session." -ForegroundColor Green

$summary = Get-Summary -Definition $definition
Write-Summary -Summary $summary

# MAKE TERMINAL FULL SCREEN

if ($definition.tryFullScreenTerminal -eq $true) {
    Switch-FullScreen
}

# STATE HANDLING

$state = Get-State

# DEPS

if ($state -eq 0) {
    Write-Host "`n`nThis script will ensure that chocolatey and winget are present if they are needed for the steps. Be aware that this script will execute planned reboots whenever needed/defined.`n" -ForegroundColor Magenta
    Write-Host "`n`nAre you sure that you want to apply this definition to your computer now (type 'yes')?: " -NoNewline
    $answer = Read-Host
    if ($answer -ne "yes") {
        Switch-FullScreen
        return
    }
    # only run this on the first run
    if ($summary.WingetPackages -gt 0) {
        Ensure-Winget
    }
    if ($summary.ChocoPackages -gt 0) {
        Ensure-Choco
    }
    Clear-Host
    Write-Summary -Summary $summary
    if ($definition.disableSounds -eq $true) {
        Write-StatusStart -Message "Disabling Windows sounds"
        New-ItemProperty -path "HKCU:\AppEvents\Schemes" -Name "(Default)" -value ".None" -Force -ErrorAction SilentlyContinue | Out-Null
        Get-ChildItem -Path "HKCU:\AppEvents\Schemes\Apps" | `
            Get-ChildItem | `
            Get-ChildItem | `
            Where-Object { $_.PSChildName -eq ".Current" } | `
            Set-ItemProperty -Name "(Default)" -Value "" -Force -ErrorAction SilentlyContinue | Out-Null
        if ($?) {
            Write-StatusResult -Message "Done" -Success
        }
        else {
            Write-StatusResult -Message "Error" -Failure
        }
    }
    if ($definition.removeKeyboardDelay -eq $true) {
        Write-StatusStart -Message "Disabling keyboard delay"
        New-ItemProperty -path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -value "0" -Force -ErrorAction SilentlyContinue | Out-Null
        if ($?) {
            Write-StatusResult -Message "Done" -Success
        }
        else {
            Write-StatusResult -Message "Error" -Failure
        }
    }
    if ($definition.disableWallpaper -eq $true) {
        Write-StatusStart -Message "Disabling keyboard delay (after next login)"
        Disable-Wallpaper
        if ($?) {
            Write-StatusResult -Message "Done" -Success
        }
        else {
            Write-StatusResult -Message "Error" -Failure
        }
    }
}
else {
    # remove the previously created task
    Switch-FullScreen
    $taskName = "Init Script Continuation $state"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$isVirtual = Get-IsVirtual
if ($isVirtual) {
    Write-Host "`nYou are running inside a virtual machine so some features might not work as expected.`n" -ForegroundColor Yellow
}
$totalPhases = $definition.phases.Length
$currentPhase = 0
foreach ($phase in $definition.phases) {
    $currentPhase++
    if ($phase.index -lt $state) {
        continue
    }
    if ($phase.disabled -eq $true) {
        Write-Host "Phase $currentPhase of $totalPhases [$($phase.phaseName)] is disabled." -ForegroundColor DarkGray
        continue;
    }
    if ($isVirtual -and $phase.disabledInVm -eq $true) {
        Write-Host "Phase $currentPhase of $totalPhases [$($phase.phaseName)] is disabled in VM." -ForegroundColor DarkGray
        continue;
    }
    Write-Host "Running phase $currentPhase of $totalPhases [$($phase.phaseName)]."
    $totalSteps = $phase.steps.Length
    $currentStep = 0
    foreach ($step in $phase.steps) {
        $currentStep++
        if ($step.disabled -eq $true) {
            Write-Host "  Step $currentStep of $totalSteps [$($step.title) is disabled." -ForegroundColor DarkGray
            continue;
        }
        if ($isVirtual -and $step.disabledInVm -eq $true) {
            Write-Host "  Step $currentStep of $totalSteps [$($step.title)] is disabled in VM." -ForegroundColor DarkGray
            continue;
        }
        Write-Host -Message "  Running step $currentStep of $totalSteps [$($step.title)]..."
        if ($step.type -eq 'choco') {
            $total = $step.packages.Length
            $current = 0
            foreach ($package in $step.packages) {
                $current++
                $command = $package.Replace('\"', '`"')
                $isMatch = $command -match "\[SPECIALFOLDER:(.*)\]"
                if ($isMatch) {
                    $folder = [environment]::getfolderpath($Matches[1])
                    $command = $command.Replace($Matches[0], $folder)
                }
                $command += " | Out-Null"
                Write-StatusStart -Message "    Installing choco package $current of $total [$package]"
                Invoke-Expression "choco install $package -y | Out-Null" | Out-Null
                if ($?) {
                    Write-StatusResult -Message "Done" -Success
                }
                else {
                    Write-StatusResult -Message "Error" -Failure
                }
            }
        }
        # elseif ($step.type -eq 'winget') {
        #     $total = $step.packages.Length
        #     $current = 0
        #     foreach ($package in $step.packages) {
        #         Write-StatusStart -Message "    Installing winget package $current of $total [$package]"
        #         Invoke-Expression "winget install $package -y | Out-Null" | Out-Null
        #         if ($?) {
        #             Write-StatusResult -Message "Done" -Success
        #         }
        #         else {
        #             Write-StatusResult -Message "Error" -Failure
        #         }
        #     }
        # }
        elseif ($step.type -eq 'winfeat') {
            $total = $step.features.Length
            $current = 0
            foreach ($feature in $step.features) {
                Write-StatusStart -Message "    Installing winget package $current of $total [$($feature.title)]"
                Enable-WindowsOptionalFeature -Online -FeatureName $feature.name -NoRestart -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
                if ($?) {
                    Write-StatusResult -Message "Done" -Success
                }
                else {
                    Write-StatusResult -Message "Error" -Failure
                }
            }
        }
        elseif ($step.type -eq 'ps') {
            $total = $step.commands.Length
            $current = 0
            foreach ($cmd in $step.commands) {
                $current++
                $command = $cmd.command.Replace('\"', '`"')
                Write-StatusStart -Message "    Running PowerShell task $current of $total [$($cmd.title)]"
                try {
                    Invoke-Expression $command | Out-Null
                    Write-StatusResult -Message "Done" -Success
                }
                catch {
                    Write-StatusResult -Message "Error" -Failure
                    Write-Host $command
                }
            }
        }
    }

    Write-Host "Phase [$($phase.phaseName)] finished."

    if ($phase.reboot -eq $true) {
        # we have to reboot now
        $newIndex = $phase.index + 1
        Set-State -State $newIndex
        $cmd = '--title "YADSI" pwsh.exe -NoExit -Command "' + $PSCommandPath + ' -DefinitionFile ' + $DefinitionFile + '"'
        Start-Reboot -ScriptPathAfterReboot $cmd -TaskNameSuffix $newIndex
        return
    }
}

# CLEANUP
Write-Host "Cleaning up artifacts"
Remove-Item $DefinitionFile -Force
Remove-Item $PSCommandPath -Force
if (Test-Path "~/.initstate.json") {
    Remove-Item "~/.initstate.json"
}
