---
name: wsl-windows-gui
description: Utiliser quand une tache demande de piloter, inspecter ou valider une application Windows graphique depuis WSL.
---

# WSL Windows GUI Control

Contrôler des applications Windows GUI depuis WSL via PowerShell.

## Prérequis

- WSL avec interop Windows activé (défaut)
- Session Windows interactive déverrouillée
- `powershell.exe` accessible dans le PATH WSL

## Lancer une application

```powershell
$proc = Start-Process notepad -PassThru
Start-Sleep -Seconds 3
```

Ne pas vérifier immédiatement avec `Get-Process -Id` : le processus peut ne pas être prêt.

## Activer la fenêtre et saisir du texte

```powershell
$wshell = New-Object -ComObject WScript.Shell

# Par PID (souvent False) ou par titre (plus fiable)
$wshell.AppActivate($proc.Id)
# Fallback : $wshell.AppActivate("Bloc-notes") / $wshell.AppActivate("Notepad")

$wshell.SendKeys("Texte à saisir{ENTER}")
```

Pour des interactions précises (boutons, champs spécifiques), préférer **UI Automation** :

```powershell
Add-Type -AssemblyName UIAutomationClient
$auto = [System.Windows.Automation.AutomationElement]::RootElement
# ... recherche par Name/AutomationId/ControlType
```

## Capture d'écran et relecture

```powershell
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bmp.Save("C:\Windows\Temp\capture.png", [System.Drawing.Imaging.ImageFormat]::Png)
```

Puis lire `/mnt/c/Windows/Temp/capture.png` avec `view_image` (ou recadrer pour zoomer).

## Pièges courants

| Symptôme | Cause | Solution |
|---|---|---|
| `Get-Process` échoue après `Start-Process` | Trop tôt | `Start-Sleep 3` minimum |
| `AppActivate` retourne False | Fenêtre pas prête / mauvais titre | Essayer titres alternatifs ("Bloc-notes", "Sans titre", "Untitled") |
| Texte tronqué / caractères spéciaux | Encodage ou SendKeys timing | Éviter accents dans le script ; ralentir avec `Start-Sleep` |
| Capture d'écran noire | Session verrouillée | Vérifier que la session Windows est active |

## Nettoyage

Toujours supprimer les scripts et captures temporaires après usage :

```bash
rm -f /mnt/c/Windows/Temp/mon-script.ps1 /mnt/c/Windows/Temp/capture-*.png
```
