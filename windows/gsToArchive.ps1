# We use -mx=0 because screenshots are already compressed, and we don't want to waste time compressing them further.
# Bring your own Archiver, this script uses 7z CLI.

if (-not (Get-Command 7z -ErrorAction SilentlyContinue)) {
    Write-Host "7z CLI is not installed or not in PATH. Please install 7-Zip and ensure it's in your system PATH."
    exit 1
}

while ($true) {
    $sourceDir = Read-Host "Enter the path to the Greenshot screenshots directory (or type 'exit' to quit) (or use '.' to use current directory)"

    if ($sourceDir -eq 'exit') { exit 0 }

    if (-not (Test-Path $sourceDir -PathType Container)) {
        Write-Host "The specified path does not exist or is not a directory. Please try again."
        continue
    }

    break
}

while ($true) {
    $year = Read-Host "Enter the desired archival year (or type 'exit' to quit)"

    if ($year -eq 'exit') { exit 0 }

    if (-not ($year -as [int])) {
        Write-Host "Invalid year. Please enter a valid year."
        continue
    }

    $filesToArchive = Get-ChildItem -Path $sourceDir -File |
        Where-Object { $_.LastWriteTime.Year -eq [int]$year }

    if (-not $filesToArchive) {
        Write-Host "No screenshots found for the specified year. Please try again."
        continue
    }

    break
}

while ($true) {
    $outputDir = Read-Host "Enter output directory for the archive (or '.' for current directory, or blank to use the source directory)"

    if ($outputDir -eq '') {
        $outputDir = $sourceDir
        break
    }

    if (-not (Test-Path $outputDir -PathType Container)) {
        Write-Host "The specified output path does not exist or is not a directory. Please try again."
        continue
    }

    break
}

$arcName = "Benji_${year}_GreenshotScreenshot_archive.7z"
$arcPath = Join-Path $outputDir $arcName

$batchSize = 50 # If there's an error, downscale it please!
$success = $true

$filesToArchive | ForEach-Object -Begin {
    $batch = @()
    $index = 0
} -Process {
    $batch += $_.FullName
    $index++

    if ($batch.Count -eq $batchSize) {
        & 7z u -mx=0 $arcPath @batch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "7z failed on batch ending at file $index (exit code $LASTEXITCODE)"
            $success = $false
        }
        $batch = @()
    }
} -End {
    if ($batch.Count -gt 0) {
        & 7z u -mx=0 $arcPath @batch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "7z failed on final batch (exit code $LASTEXITCODE)"
            $success = $false
        }
    }
}

if ($success) {
    Write-Host "Archive created: $arcPath ($($filesToArchive.Count) files)"

    $deleteChoice = Read-Host "Delete the $($filesToArchive.Count) archived screenshots from '$sourceDir'? (y/N)"

    if ($deleteChoice -eq 'y' -or $deleteChoice -eq 'Y') {
        $confirm = Read-Host "This cannot be undone. Type 'DELETE' to confirm"

        if ($confirm -eq 'DELETE') {
            $deleteFailures = 0

            foreach ($file in $filesToArchive) {
                try {
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                } catch {
                    Write-Host "Failed to delete: $($file.FullName) - $($_.Exception.Message)"
                    $deleteFailures++
                }
            }

            if ($deleteFailures -eq 0) {
                Write-Host "Deleted $($filesToArchive.Count) files."
            } else {
                Write-Host "Deleted $($filesToArchive.Count - $deleteFailures) files, $deleteFailures failed - see above."
            }
	
	    $stillPresent = $filesToArchive | Where-Object { Test-Path -LiteralPath $_.FullName }
	    Write-Host "$($stillPresent.Count) files still exist on disk despite deletion attempt."
        
	} else {
            Write-Host "Confirmation not received. Files were not deleted."
        }
    } else {
        Write-Host "Files were not deleted."
    }
} else {
    Write-Host "Archive may be incomplete - check the errors above. Skipping deletion for safety."
}
