#Using Remote Desktop app as an example. Replace with the app you are looking for.
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
        Write-Host "***Shortcut is present."
        exit 1
    } else {
        Write-Host "Shortcut is not present."
        exit 0
    }
} catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}