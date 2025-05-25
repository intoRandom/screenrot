# This script is just a launcher of main script
# Este script solamente inicia el script principal
$urlScript = "https://raw.githubusercontent.com/intoRandom/screenRot/refs/heads/main/run/script.ps1"

Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -Command `"iwr '$urlScript' -UseBasicParsing | iex`""
exit
