# 
# CameraRotateTool.ps1 v0.1.0
# www.github.com/dge8/CameraRotateTool
# 
# SPDX-License-Identifier: MIT
# Copyright (c) 2021 Dan George <dgeor8@gmail.com>. All rights reserved.
# This software is provided with NO WARRANTY WHATSOEVER.
# 
# More information about the FSSensorOrientation registry key in Microsoft docs here:
# https://docs.microsoft.com/en-us/windows-hardware/drivers/stream/camera-device-orientation
# 

# Builtins, KSCATEGORY GUIDs from 
# https://docs.microsoft.com/en-us/windows-hardware/drivers/install/kscategory-video
$RegDeviceClassesRoot = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceClasses\'
$KsCategories   = @(('KSCATEGORY_VIDEO',         '{6994AD05-93EF-11D0-A3CC-00A0C9223196}'),
                    ('KSCATEGORY_VIDEO_CAMERA',  '{E5323777-F976-4f5b-9B55-B94699C46E44}'),
                    ('KSCATEGORY_SENSOR_CAMERA', '{24E552D7-6523-47F7-A647-D3465BF1F5CA}'),
                    ('KSCATEGORY_CAPTURE',       '{65E8773D-8F56-11D0-A3B9-00A0C9223196}'))

# Get configured cameras and current orientation information from the registry
function Get-Camera {
    param ()
    $PnpDevices = Get-PnpDevice |
        Where-Object { 'Image','Camera' -contains $_.Class } |
        Select-Object FriendlyName,InstanceId,Status
    $i = 0
    $Cameras = @()
    ForEach ($PnpDevice in $PnpDevices) {
        $DeviceRegistryId = '##?#' + ($PnpDevice.InstanceId -replace '\\','#') + '#'
        $SubDeviceKsCategories = @{}
        ForEach ($KsCategory in $KsCategories) {
            $devicePath = $regDeviceClassesRoot + $ksCategory[1] + '\' + $DeviceRegistryId + $ksCategory[1]
            If (-not (Test-Path -LiteralPath $devicePath)) { Continue }
            $subDevicePaths = (Get-ChildItem -LiteralPath $devicePath).Name
            ForEach ($subDevicePath in $subDevicePaths) {
                If ( -not (Test-Path -LiteralPath ('Registry::' + $subDevicePath + "\Properties")) -or 
                    -not (Test-Path -LiteralPath ('Registry::' + $subDevicePath + "\Device Parameters")) ) {
                    Continue
                }
                $subDeviceRegistryId = Split-Path -Path $subDevicePath -Leaf
                If ( $subDeviceKsCategories.ContainsKey($subDeviceRegistryId) ) {
                    $subDeviceKsCategories[$subDeviceRegistryId] += $ksCategory[0]
                } Else {
                    $subDeviceKsCategories[$subDeviceRegistryId] = @($ksCategory[0])
                }
            }
        }
        $SubDeviceKsCategories.GetEnumerator() | ForEach-Object {
            $SubDeviceNames = @()
            $FsSensorOrientations = @()
            ForEach ($KsCategoryName in $_.Value) {
                $KsCategoryId = ($KsCategories | Where {$_[0] -eq $KsCategoryName})[1]
                $SubDeviceParameterPath = $RegDeviceClassesRoot + $KsCategoryId + '\' + $DeviceRegistryId + $KsCategoryId + '\' + $_.Name + '\Device Parameters'
                Try {
                    $name = Get-ItemPropertyValue -LiteralPath $SubDeviceParameterPath -Name 'FriendlyName'
                    If ($SubDeviceNames -notcontains $name) { $SubDeviceNames += $name }
                } Catch { }
                Try {
                    $fsso = Get-ItemPropertyValue -LiteralPath $SubDeviceParameterPath -Name 'FSSensorOrientation'
                    If ($FsSensorOrientations -notcontains $fsso) { $FsSensorOrientations += $fsso }
                } Catch { }
            }
            If ($FsSensorOrientations.Count -eq 0) { $FsSensorOrientations += '0' }
            $i += 1
            $Cameras += [PSCustomObject]@{
                Id                  = $i
                Device              = $PnpDevice.FriendlyName
                Name                = $SubDeviceNames -join '/'
                Status              = $PnpDevice.Status
                Orientation         = $FsSensorOrientations -join '/'
                DeviceInstanceId    = $PnpDevice.InstanceId
                KsCategories        = $_.Value
                DeviceRegistryId    = $DeviceRegistryId
                SubDeviceRegistryId = $_.Name
            }
        }
    }
    $Cameras
}

# Set orientation of a camera
Function Set-CameraOrientation {
    Param(
        [PSCustomObject]$Camera,
        [String]$NewOrientation
    )
    If ('0','90','180','270' -notcontains $NewOrientation) { Throw "Orientation must be one of [0,90,180,270]." }
    ForEach ($KsCategoryName in $Camera.KsCategories) {
        $KsCategoryId = ($KsCategories | Where {$_[0] -eq $KsCategoryName})[1]
        $DeviceParameterPath = $RegDeviceClassesRoot + $KsCategoryId + '\' + $Camera.DeviceRegistryId + $KsCategoryId + '\' + $Camera.SubDeviceRegistryId + '\Device Parameters'
        If ($NewOrientation -eq '0') {
            Remove-ItemProperty -Path $DeviceParameterPath -Name 'FSSensorOrientation' -Force | Out-Null
        } Else {
            Set-ItemProperty -Path $DeviceParameterPath -Name 'FSSensorOrientation' -Value $NewOrientation -Type DWord -Force | Out-Null
        }
    }
}

# Check if running at least Windows 10 1607 and PowerShell 5.0
If ( [Environment]::OSVersion.Version.Major -ne 10 -or 
    [Environment]::OSVersion.Version.Build -lt 14393 -or
    $Host.Version.Major -lt 5 ) {
    Write-Host "Error: CameraRotateTool requires at least Windows 10 1607 and PowerShell 5.0" -ForegroundColor Red
    Write-Host ''
    Read-Host -Prompt "Press Enter to exit"
}

# Elevate to admin privileges if not already
If ( -not (New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
    )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $process = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
        $process.Arguments = $MyInvocation.MyCommand.Definition
        $process.Verb = "runas"
        [System.Diagnostics.Process]::Start($process) | Out-Null
        Exit
    }

# Main interactive loop
While ($true) {

    Clear-Host
    Write-Host ''
    Write-Host '================ CameraRotateTool v0.1.0 ================' -ForegroundColor Cyan
    Write-Host ''

    Write-Host 'Looking for cameras...'
    Write-Host ''
    $Cameras = Get-Camera    
    
    If (($Cameras | Measure-Object).Count -eq 0) {
        Write-Host "Error: Could not identify any compatible connected cameras or imaging devices." -ForegroundColor Red
        Write-Host ''
        Read-Host -Prompt "Press Enter to exit"
        Exit
    }
    
    Write-Host 'Identified cameras: '
    $Cameras | Select-Object Id,Device,Name,Status,Orientation | Format-Table
    
    Do {
        $Selection = Read-Host -Prompt 'Enter a camera ID to change the orientation, or Q to quit'
    } Until ($Selection -eq 'q' -or $Cameras.Id -contains $Selection)
    If ($Selection -eq 'q') { Exit }
    
    $CameraId = $Selection
    Do {
        $Selection = Read-Host -Prompt 'Enter the new orientation [90,180,270] or 0 to remove the orientation'
    } Until ('','0','90','180','270' -contains $Selection)
    If ($Selection -eq '') { Continue }

    $NewOrientation = $Selection
    $Camera = $Cameras | Where Id -eq $CameraId
    Set-CameraOrientation $Camera $NewOrientation
    
}
