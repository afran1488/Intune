try {
    # Retrieve all installed software and filter by vendor
    $software = Get-WmiObject -Class Win32_Product | Where-Object { $_.Vendor -eq "NAMEOFVENDOR" }

    # If software count is greater than 0, APPNAME is present
    if ($software.Count -gt 0) {
        Write-Host "APPNAME is present."
        exit 1
    } else {
        Write-Host "APPNAME is not present."
        exit 0
    }

} catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}