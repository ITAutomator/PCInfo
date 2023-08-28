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
Function IsLocalAdmin
{ ## if the user is in the local admins group
  $null -ne (whoami /groups /fo csv |
  ConvertFrom-Csv |
  Where-Object { $_.SID -eq "S-1-5-32-544" })
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

## Read Teamviewer ID from registry
$tvid = RegGet "HKLM" "SOFTWARE\WOW6432Node\TeamViewer" "ClientID"
If ($tvid -eq "") {$tvid = RegGet "HKLM" "SOFTWARE\TeamViewer" "ClientID"}
$tvaccnt = RegGet "HKLM" "SOFTWARE\WOW6432Node\TeamViewer" "OwningManagerAccountName"
If ($tvaccnt -eq "") {$tvaccnt = RegGet "HKLM" "SOFTWARE\TeamViewer" "OwningManagerAccountName"}
$TeamviewerID = $tvid
if (($tvaccnt -ne $null) -and ($tvaccnt -ne "")) {$TeamviewerID +="($($tvaccnt))"}

# Networks
$networks=@()
$NetConnectionProfiles = Get-NetConnectionProfile
ForEach ($NetConnectionProfile in $NetConnectionProfiles)
{
    $NetIPAddress        = Get-NetIPAddress -InterfaceIndex $NetConnectionProfile.InterfaceIndex -AddressFamily IPV4
    $NetAdapter          = Get-NetAdapter   -InterfaceIndex $NetConnectionProfile.InterfaceIndex
    #
    $network =    $NetIPAddress.IPAddress
    $network += " $($NetConnectionProfile.InterfaceAlias) $($NetConnectionProfile.Name) ($($NetConnectionProfile.NetworkCategory))"
    $network += " [$($NetAdapter.MacAddress)]"
    #
    $networks += $network
}

# Disks
$disks=@()
$Getdisks = Get-disk
ForEach ($Getdisk in $Getdisks)
{
    $disk = $Getdisk.FriendlyName
    $disk += " " + ($Getdisk.Size / 1GB).ToString("#.# GB")+""
    #
    $volumes = $Getdisk | Get-Partition | Get-Volume | Where-Object DriveLetter -ne $null
    ForEach ($volume in $volumes)
    {
        $disk += " [" + $volume.DriveLetter.ToString().ToUpper() + ": "
        $disk += ($volume.SizeRemaining / 1GB).ToString("#.# GB")+" free of "
        $disk += ($volume.Size / 1GB).ToString("#.# GB")+"]"
    }
    $disks += $disk
}

# Public IP
$PublicIP_Info = Invoke-RestMethod http://ipinfo.io/json -UseBasicParsing

# Windows settings
[string]$reg_hiberbootenabled = RegGet "HKLM" "SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled"
[string]$reg_toastenabled     = RegGet "HKCU" "SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled"
if ($reg_hiberbootenabled -eq "") {$reg_hiberbootenabled = "(blank)"}
if ($reg_toastenabled -eq "")     {$reg_toastenabled     = "(blank)"}
##
if ($reg_hiberbootenabled -eq "1") {$reg_hiberbootenabled_desc="Warning: Fast Boot is enabled"} else {$reg_hiberbootenabled_desc="OK: Fast Boot is disabled (shutdown same as restart)"}
if ($reg_toastenabled -eq "0") {$reg_toastenabled_desc="Warning: System notifications are disabled for current user"} else {$reg_toastenabled_desc="OK: System notifications are enabled for current user"} 

# PC boot
$pc = Get-WmiObject win32_operatingsystem | select csname, @{LABEL="LastBootUpTime";EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
$days_fromstartup = ((Get-Date)-($pc.LastBootUpTime)).TotalDays

# Local Admins
$localuser = "$($env:userdomain)\$($env:username)" 
$localadmins = LocalAdmins
$IsLocalAdmin = if (IsLocalAdmin) {"YES"} else {"NO"}
$IsAdmin      = if (IsAdmin)      {"YES"} else {"NO"}

# Azure Info
$dsregcmd = dsregcmd /status | Where-Object { $_ -match ' : ' } | ForEach-Object { $_.Trim() } | ConvertFrom-String -PropertyNames 'Name','Value' -Delimiter ' : '

# PC Info
$computerInfo = Get-ComputerInfo

####    
$objProps = [ordered]@{
    ComputerSN    = $computerInfo.BiosSeralNumber
    OSInfo        = "$($computerInfo.OsName) ($($computerInfo.OSDisplayVersion)) v$($computerInfo.OsVersion) $($computerInfo.OsArchitecture)"
    Model         = "$($computerInfo.CsManufacturer) $($computerInfo.CsModel)"
    CPU           = $computerinfo.CsProcessors[0].Name + " (" + $computerinfo.CsProcessors[0].NumberOfCores + "C)"
    Memory        = ($computerInfo.CsTotalPhysicalMemory / 1GB).ToString("#.# GB")
    Disks         = $Disks -join ", "
    Computername  = $computerInfo.CsName
    Networks      = $networks -join ", "
    PublicIP      = $PublicIP_Info.ip
    PublicIP_Loc  = "$($PublicIP_Info.city) $($PublicIP_Info.region) $($PublicIP_Info.postal) $($PublicIP_Info.country) [$($PublicIP_Info.org)]"
    TeamviewerID  = $TeamviewerID
    Domain        = $env:userdomain 
    User          = $localuser
    LocalAdmins   = $localadmins -join ", "
    IsLocalAdmin  = $IsLocalAdmin
    IsAdminNow    = $IsAdmin
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
$out_info = ($infoObject | Out-String).Trim()
$out_separator =  "-----------------------------------------------------------------------------"
$out_header = "$($scriptName) $($scriptVer)       Computer:$($env:computername) User:$($env:username) PSver:$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
$out_lines=@()
$out_lines+=$out_separator
$out_lines+=$out_header
$out_lines+=$out_separator
$out_lines+=$out_info
$out_lines+=$out_separator
$out_lines | Write-Host
### Drop a report in the downloads folder
$folder_downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
$date = get-date -format "yyyy-MM-dd_HH-mm-ss"
$file = "$($folder_downloads)\PC Info $($date).txt"
# write file
$out_lines | Out-File $file
# open file
Invoke-Item $file
#################################################
Read-Host -Prompt "Press Enter to exit"