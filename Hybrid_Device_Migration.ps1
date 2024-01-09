# Unjoin Hybrid Azure AD joined device using dsregcmd /leave command
$dsregcmd = "${env:windir}\System32\dsregcmd.exe"
Start-Process $dsregcmd -ArgumentList "/leave" -NoNewWindow -Wait
Write-Output "Command to leave DOMAIN Azure AD tenant has been initiated."

# Wait for 10 seconds
Start-Sleep -Seconds 10

# Check if device is still joined to Azure AD
$status = & $dsregcmd /status | Select-String "AzureAdJoined"
if ($status -match "YES") {
    Write-Output "Device is still joined to Azure AD. Please see Juan for assistance."
    return
}
else {
    Write-Output "Device has been removed from Azure AD."
}

# Disable the scheduled task Automatic-Device-Join
Disable-ScheduledTask -TaskName "Automatic-Device-Join" -TaskPath "\Microsoft\Windows\Workplace Join" | Out-Null

# Remove keys in HKLM:\SOFTWARE\Microsoft\Enrollments and output message
Remove-Item "HKLM:\SOFTWARE\Microsoft\Enrollments\*" -Recurse -Force -Exclude Context,Status,ValidNodePaths,Ownership -ErrorAction SilentlyContinue
Write-Host "Enrollment keys have been deleted." -ForegroundColor Green

# Define the local user account and password to be used for the removal
$userName = "DOMAIN\ADMINACCOUNT"
$password = ConvertTo-SecureString "PASSWORD" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($userName, $password)

# Display a message indicating that the computer is being removed from the domain
Write-Host "Attempting to remove computer from DOMAIN.local." -ForegroundColor Yellow

# Check if the computer is part of the "DOMAIN.local" domain
$domain = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty Domain
if ($domain -eq "DOMAIN.local") {
    # Remove the computer from the domain with error handling
    try {
        Remove-Computer -Credential $cred -PassThru -Verbose -Force
        Write-Host "Computer has been removed from DOMAIN.local." -ForegroundColor Green
    }
    catch {
        Write-Output "An error occurred while removing the computer from the domain:"
        Write-Output $_
        Exit 1
    }
}
else {
    Write-Host "Computer is not part of DOMAIN.local. Skipping removal from the domain." -ForegroundColor Yellow
}

Start-Sleep -Seconds 10

# Enable the scheduled task Automatic-Device-Join
Enable-ScheduledTask -TaskName "Automatic-Device-Join" -TaskPath "\Microsoft\Windows\Workplace Join" | Out-Null

Write-Host "Importing Hardware ID to Intune." -ForegroundColor Yellow

#Install MSAL.ps module if not currently installed
If(!(Get-Module MSAL.ps)){
    Install-PackageProvider -Name NuGet -Force

    Install-Module MSAL.ps -Force

    Import-Module MSAL.ps -Force

}

#Use a client secret to authenticate to Microsoft Graph using MSAL
$authparams = @{
    ClientId    = '*****'
    TenantId    = '*****'
    ClientSecret = ('*****' | ConvertTo-SecureString -AsPlainText -Force )
}

$auth = Get-MsalToken @authParams

#Set Access token variable for use when making API calls
$AccessToken = $Auth.AccessToken

#Function to make Microsoft Graph API calls
Function Invoke-MsGraphCall {

    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$AccessToken,
        [Parameter(Mandatory=$True)]
        [string]$URI,
        [Parameter(Mandatory=$True)]
        [string]$Method,
        [Parameter(Mandatory=$False)]
        [string]$Body
    )


    #Create Splat hashtable
    $graphSplatParams = @{
        Headers     = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $($AccessToken)"
        }
        Method = $Method
        URI = $URI
        ErrorAction = "SilentlyContinue"
        #StatusCodeVariable = "scv"
    }

    #If method requires body, add body to splat
    If($Method -in ('PUT','PATCH','POST')){

        $graphSplatParams["Body"] = $Body

    }

    #Return API call result to script
    $MSGraphResult = Invoke-RestMethod @graphSplatParams

    #Return status code variable to script
    Return $SCV, $MSGraphResult

}


#Gather Autopilot details
$session = New-CimSession
$serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
$devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
$hash = $devDetail.DeviceHardwareData


#Create required variables
#The following example will update the management name of the device at the following URI
$URI = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities"
$Body = @{ "serialNumber" = "$serial"; "hardwareIdentifier" = "$hash" } | ConvertTo-Json
$Method = "POST"

Try{

    #Call Invoke-MsGraphCall
    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

    } Catch {

        Write-Output "An error occurred:"
        Write-Output $_
        Exit 1

    }

If($MSGraphCall) {
    Write-Output $MSGraphCall
}

Write-Host "Hardware ID has been imported to Intune." -ForegroundColor Green

Write-Host "Putting device into OOBE and Restarting." -ForegroundColor Green

Start-Sleep -Seconds 10

# Run sysprep with the specified arguments
Start-Process -FilePath "C:\Windows\System32\sysprep\sysprep.exe" -ArgumentList "/quiet /oobe /reboot"