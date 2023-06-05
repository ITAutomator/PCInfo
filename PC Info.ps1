################################################# 
Function IsAdmin() 
{
    <#
    .SYNOPSIS
    Checks if the running process has elevated priviledges.
    .DESCRIPTION
    To get elevation with powershell, right-click the .ps1 and run as administrator - or run the ISE as administrator.
    .EXAMPLE
    if (-not(IsAdmin))
        {
        write-host "No admin privs here, run this elevated"
        return
        }
    #>
    $wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $prp=new-object System.Security.Principal.WindowsPrincipal($wid)
    $adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
    $IsAdmin=$prp.IsInRole($adm)
    $IsAdmin
}
Function LocalAdmins
{
    ## Show Local admins
    $administratorsAccount = Get-WmiObject Win32_Group -filter "LocalAccount=True AND SID='S-1-5-32-544'" 
    $administratorQuery = "GroupComponent = `"Win32_Group.Domain='" + $administratorsAccount.Domain + "',NAME='" + $administratorsAccount.Name + "'`"" 
    $locadmins_wmi = Get-WmiObject Win32_GroupUser -filter $administratorQuery | Select-Object PartComponent
    $locadmins = @()
    $azadmins = @()
    $count = 0
    $account_warnings = 0
    $msg_accounts =""
    foreach ($locadmin_wmi in $locadmins_wmi)
    {
        $user1 = $locadmin_wmi.PartComponent.Split(".")[1]
        $user1 = $user1.Replace('"',"")
        $user1 = $user1.Replace('Domain=',"")
        $user1 = $user1.Replace(',Name=',"\")
        $Status = ""
        $domainname = $user1.Split("\")[0]
        $accountname = $user1.Split("\")[1]
        $locadmin_info = Get-LocalUser $accountname -ErrorAction SilentlyContinue
        if ($locadmin_info)
        {
            if (-not ($locadmin_info.Enabled))
            {
                #$Status = " [Disabled]"
            }
        }
        $count +=1
        $locadmins+="$($user1)$($Status)"
        Write-Output "$($user1)$($Status)"
        #### is this an AzureAD Admin that's enabled?
        if (($domainname -eq "AzureAD") -and (-not ($locadmin_info.Enabled)))
        {
            #$azadmins += $user1
        }
        ####
    }
}
################################################# 
Function RegGet ($keymain, $keypath, $keyname)
#########
## $ver=RegGet "HKCR" "Word.Application\CurVer"
## $ver=RegGet "HKLM" "System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections"
#########
    {
    $result = ""
    Switch ($keymain)
        {
            "HKLM" {$RegGetregKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($keypath, $false)}
            "HKCU" {$RegGetregKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($keypath, $false)}
            "HKCR" {$RegGetregKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($keypath, $false)}
        }
    if ($RegGetregKey)
        {
        $result=$RegGetregKey.GetValue($keyname, $null, "DoNotExpandEnvironmentNames")
        }
    $result
    }

### Main function header - Put RethinkitFunctions.psm1 in same folder as script
$scriptFullname = $PSCommandPath ; if (!($scriptFullname)) {$scriptFullname =$MyInvocation.InvocationName}
if ($scriptFullname) {
$scriptXML      = $scriptFullname.Substring(0, $scriptFullname.LastIndexOf('.'))+ ".xml"  ### replace .ps1 with .xml
$scriptDir      = Split-Path -Path $scriptFullname -Parent
$scriptName     = Split-Path -Path $scriptFullname -Leaf
$scriptBase     = $scriptName.Substring(0, $scriptName.LastIndexOf('.'))
$scriptVer      = "v"+(Get-Item $scriptFullname).LastWriteTime.ToString("yyyy-MM-dd")
}

Write-Host "PC Info.ps1" -NoNewline -ForegroundColor Yellow
Write-Host " (Gathering info)..."
#################################################
$userisadmin = if (IsAdmin) {"YES"} else {"NO"}
$dsregcmd = dsregcmd /status | Where-Object { $_ -match ' : ' } | ForEach-Object { $_.Trim() } | ConvertFrom-String -PropertyNames 'Name','Value' -Delimiter ' : '
###
## Read Teamviewer ID from registry
$tvid =RegGet "HKLM" "SOFTWARE\WOW6432Node\TeamViewer" "ClientID"
If ($tvid -eq "")
{
    $tvid =RegGet "HKLM" "SOFTWARE\TeamViewer" "ClientID"
}
$tvaccnt =RegGet "HKLM" "SOFTWARE\WOW6432Node\TeamViewer" "OwningManagerAccountName"
If ($tvaccnt -eq "")
{
    $tvaccnt =RegGet "HKLM" "SOFTWARE\TeamViewer" "OwningManagerAccountName"
}
###
$NetConnectionProfile= Get-NetConnectionProfile
$NetIPAddress        = Get-NetIPAddress -InterfaceIndex $NetConnectionProfile.InterfaceIndex -AddressFamily IPV4
$NetAdapter          = Get-NetAdapter -InterfaceIndex $NetConnectionProfile.InterfaceIndex
$macaddress= $NetAdapter.MacAddress
$ipaddress = $NetIPAddress.IPAddress
$network   = "$($NetConnectionProfile.InterfaceAlias) $($NetConnectionProfile.Name) ($($NetConnectionProfile.NetworkCategory))"
###
$disks= @(Get-disk)
$disk = $disks[0]
$computerInfo = Get-ComputerInfo
###

################ Public IP: START
### Look for public ip 
$PublicIP = Invoke-RestMethod http://ipinfo.io/json | Select -exp ip
################ Public IP: END

####### Windows settings
[string]$reg_hiberbootenabled = RegGet "HKLM" "SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled"
[string]$reg_toastenabled     = RegGet "HKCU" "SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled"
if ($reg_hiberbootenabled -eq "") {$reg_hiberbootenabled = "(blank)"}
if ($reg_toastenabled -eq "")     {$reg_toastenabled     = "(blank)"}
##
if ($reg_hiberbootenabled -eq "1") {$reg_hiberbootenabled_desc="Fast Boot is enabled"} else {$reg_hiberbootenabled_desc="Fast Boot is disabled (shutdown same as restart)"}
if ($reg_toastenabled -eq "0") {$reg_toastenabled_desc="System notifications are disabled for current user"} else {$reg_toastenabled_desc="System notifications are enabled for current user"} 
####### Windows settings

$pc = Get-WmiObject win32_operatingsystem | select csname, @{LABEL="LastBootUpTime";EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
$days_fromstartup = ((Get-Date)-($pc.LastBootUpTime)).TotalDays
###

####
$localuser = "$($env:userdomain)\$($env:username)" 
$localadmins=LocalAdmins
if ($localadmins -contains "$localuser" ) 
    {$IsLocalAdmin ="Yes"}
else 
    {$IsLocalAdmin ="No"} 
####    
$objProps = [ordered]@{
    ComputerSN    = $computerInfo.BiosSeralNumber
    OSInfo        = "$($computerInfo.OsName) ($($computerInfo.OSDisplayVersion)) v$($computerInfo.OsVersion) $($computerInfo.OsArchitecture)"
    Model         = "$($computerInfo.CsManufacturer) $($computerInfo.CsModel)"
    CPU           = $computerinfo.CsProcessors[0].Name + " (" + $computerinfo.CsProcessors[0].NumberOfCores + "C)"
    Memory        = ($computerInfo.CsTotalPhysicalMemory / 1GB).ToString("#.# GB")
    DiskName      = $disk.FriendlyName
    DiskSize      = ($disk.Size / 1GB).ToString("#.# GB")
    Computername  = $computerInfo.CsName
    IPAddress     = $ipaddress
    MACaddress    = $macaddress
    Network       = $network
    PublicIP      = $PublicIP
    TeamviewerID  = "$tvid ($($tvaccnt))"
    Domain        = $env:userdomain 
    User          = $localuser
    LocalAdmins   = $localadmins -join ", "
    IsLocalAdmin  = $IsLocalAdmin
    IsAdminNow    = $userisadmin
    #AZADAccount   = ($dsregcmd | Where-Object -Property Name -eq "Executing Account Name").Value
    AZADJoined    = ($dsregcmd | Where-Object -Property Name -eq "AzureAdJoined").Value
    DeviceId      = ($dsregcmd | Where-Object -Property Name -eq "DeviceId").Value
    TenantName    = ($dsregcmd | Where-Object -Property Name -eq "TenantName").Value
    TenantId      = ($dsregcmd | Where-Object -Property Name -eq "TenantId").Value
    Shutdown      = "$($reg_hiberbootenabled), $($reg_hiberbootenabled_desc)"
    Notifications = "$($reg_toastenabled), $($reg_toastenabled_desc)"
    LastBootUpTime= $pc.LastBootUpTime.tostring("g")
    LastBootDaysAgo= "$($days_fromstartup.tostring("0.#")) days ago"
    }

$infoObject = New-Object -TypeName psobject -Property $objProps
Write-Host "-----------------------------------------------------------------------------"
Write-Host "$($scriptName) $($scriptVer)       Computer:$($env:computername) User:$($env:username) PSver:$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
$infoObject
Write-Host "-----------------------------------------------------------------------------"
### Drop a report in the downloads folder
$folder_downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
$date = get-date -format "yyyy-MM-dd_HH-mm-ss"
$file = "$($folder_downloads)\PC Info $($date).txt"
$infoObject | Out-File $file
Invoke-Item $file
#################################################
Read-Host -Prompt "Press Enter to exit"