```powershell
$RootDir = $PSScriptRoot
$LogFile = Join-Path $RootDir "rename-log.txt"

$Extensions = @(
    '.jpg', '.jpeg', '.png', '.webp',
    '.bmp', '.gif', '.tif', '.tiff'
)

function Write-Log($Message) {
    Write-Host $Message
    Add-Content -LiteralPath $LogFile -Value $Message
}

Set-Content -LiteralPath $LogFile -Value "Image renaming log - $(Get-Date)"
Write-Log "Root folder: $RootDir"
Write-Log ""

# Find every folder, including folders inside other folders.
$Folders = @(
    Get-ChildItem -LiteralPath $RootDir -Directory -Recurse |
    Sort-Object FullName
)

$FolderNumber = 0

foreach ($Folder in $Folders) {
    $FolderNumber++

    Write-Log "[$FolderNumber/$($Folders.Count)] Checking: $($Folder.FullName)"

    try {
        # Only process images directly inside this folder.
        $Images = @(
            Get-ChildItem -LiteralPath $Folder.FullName -File |
            Where-Object {
                $Extensions -contains $_.Extension.ToLowerInvariant()
            } |
            Sort-Object Name
        )

        if ($Images.Count -eq 0) {
            Write-Log "  No images found."
            Write-Log ""
            continue
        }

        $Correct = $true

        for ($i = 0; $i -lt $Images.Count; $i++) {
            $Expected = "$($Folder.Name)_$($i + 1)$($Images[$i].Extension)"

            if ($Images[$i].Name -cne $Expected) {
                $Correct = $false
                break
            }
        }

        if ($Correct) {
            Write-Log "  Already correct ($($Images.Count) images)."
            Write-Log ""
            continue
        }

        Write-Log "  FIXING $($Images.Count) images..."

        # Phase 1: Give every image a unique temporary name.
        $TempFiles = @()

        foreach ($Image in $Images) {
            $TempName = "__rename_$([guid]::NewGuid().ToString('N'))$($Image.Extension)"

            Rename-Item -LiteralPath $Image.FullName `
                -NewName $TempName -ErrorAction Stop

            $TempFiles += [PSCustomObject]@{
                TempName = $TempName
                Extension = $Image.Extension
            }
        }

        # Phase 2: Rename images sequentially using their folder name.
        for ($i = 0; $i -lt $TempFiles.Count; $i++) {
            $File = $TempFiles[$i]
            $NewName = "$($Folder.Name)_$($i + 1)$($File.Extension)"

            Rename-Item -LiteralPath (
                Join-Path $Folder.FullName $File.TempName
            ) -NewName $NewName -ErrorAction Stop

            Write-Log "  Created: $NewName"
        }

        Write-Log "  SUCCESS"
    }
    catch {
        Write-Log "  ERROR: $($_.Exception.Message)"
        Write-Log "  Folder: $($Folder.FullName)"
        Write-Log "  Check this folder before rerunning."
    }

    Write-Log ""
}

Write-Log "Finished checking all folders."
Write-Log "Log saved to: $LogFile"

Read-Host "Press Enter to close"
```