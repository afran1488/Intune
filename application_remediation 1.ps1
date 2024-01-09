try {
    $software = Get-WmiObject -Class Win32_Product | Where-Object { $_.Vendor -eq "APPNAME" }

    if ($software) {
        $software | ForEach-Object {
            Write-Host "Attempting to uninstall $($_.Name)..."
            
            $result = $_.Uninstall()
            if ($result.ReturnValue -eq 0) {
                Write-Host "$($_.Name) uninstalled successfully."
            } else {
                Write-Warning "Failed to uninstall $($_.Name). Error code: $($result.ReturnValue)"
            }
        }
    } else {
        Write-Host "APPNAME is not present. No action needed."
    }

    exit 0
} catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}