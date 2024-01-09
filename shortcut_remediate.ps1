#Using Remote Desktop app as an example. Replace with the app you are looking to create a shortcut for.
$ShortcutFolderPath = "C:\Users\Public\Desktop"
$fileNameToDetect = @("Remote Desktop.lnk")

try {
    $results = $fileNameToDetect | ForEach-Object {
        $filePath = Join-Path -Path $ShortcutFolderPath -ChildPath $_
        if (Test-Path $filePath) {
            $_
        }
    }

    if ($results.Count -eq $fileNameToDetect.Count) {
        # Shortcut detected, proceed with deletion.
        $results | ForEach-Object {
            $filePath = Join-Path -Path $ShortcutFolderPath -ChildPath $_
            # Delete the file forcefully
            Remove-Item -Path $filePath -Force -ErrorAction Stop
            Write-Host "Deleted Shortcut: $filePath"
        }
        Write-Host "Shortcut deleted successfully."
    } else {
        Write-Host "Shortcut not present. No action needed."
    }

    exit 0
} catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}