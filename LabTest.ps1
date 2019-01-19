function Set-LabSettings {
    #download Adventureworks DB from GitHub and put into the CMServer
    #   - use CMServer SQL Instance to create dummy users
    #process to create x number of workstation clients
    #Download and install SSMS
    #Download and install VSCode
    #process to create x number of dummy clients
    #find a solution to ensure the latest TP is installed
}
    
#endregion
#LAZY MODULE TESTING, WILL BE FIXED ONCE COMPLETED
foreach ($psfile in get-childitem -Filter *.ps1 | Where-Object {$_.name -notin ("NewENV.Tests.ps1", "labtest.ps1")}) {
    . ".\$psfile"
}
    
    
#region import JSON Settings
$scriptpath = $PSScriptRoot
$config = Get-Content "$scriptpath\env.json" -Raw | ConvertFrom-Json
$envConfig = $config.ENVConfig | Where-Object {$_.env -eq $config.env}
$script:logfile = "$($envConfig.vmpath)\Build.log"
if (!(Test-Path $envConfig.vmpath)) {new-item -ItemType Directory -Force -Path $envConfig.vmpath | Out-Null}
Write-LogEntry -Type Information -Message "Start of build process for $($config.env) ------"
$admpwd = $envConfig.AdminPW
Write-LogEntry -Type Information -Message "Admin password set to: $admpwd"
$localadmin = new-object -typename System.Management.Automation.PSCredential -argumentlist "administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
$domuser = new-object -typename System.Management.Automation.PSCredential -argumentlist "$($envconfig.env)\administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
$vmpath = $envConfig.VMPath
Write-LogEntry -Type Information -Message "Path for VHDXs set to: $vmpath"
$swname = $envConfig.SwitchName
Write-LogEntry -Type Information -Message "vSwitch name is: $swname"
$ipsub = $envConfig.ipsubnet
Write-LogEntry -type Information -Message "IP Subnet used for this lab is: $ipsub"
$DomainFQDN = $envconfig.DomainFQDN
Write-LogEntry -Type Information -Message "Fully Quilified Domain Name is: $domainfqdn"
$RRASname = $Config.RRASname
Write-LogEntry -Type Information -Message "Routing and Remote Access Services server name is: $RRASName"
$RefVHDX = $config.REFVHDX
Write-LogEntry -Type Information -Message "Path to Reference VHDX is: $RefVHDX"
$domainnetbios = $envconfig.DomainNetBiosName
Write-LogEntry -Type Information -Message "WINNT domain name is: $domainnetbios"
$cmsitecode = $envConfig.CMSiteCode
Write-LogEntry -Type Information -Message "SCCM Site code is: $cmsitecode"
$SCCMDLPreDown = $config.SCCMDLPreDown
Write-LogEntry -Type Information -Message "SCCM Content was Predownloaded: $($sccmdlpredown -eq 1)"
$vmsnapshot = if ($config.Enablesnapshot -eq 1) {$true}else {$false} 
Write-LogEntry -Type Information -Message "Snapshots have been: $vmsnapshot"
$unattendpath = $config.REFVHDX -replace ($config.REFVHDX.split('\') | Select-Object -last 1), "Unattended.xml"
Write-LogEntry -Type Information -Message "Windows 2016 unattend file is: $unattendpath"
$servertemplates = (Get-Content "$scriptpath\SVRTemplates.json" -Raw | ConvertFrom-Json).ServerTemplates
#endregion 
    
#region ENVConfig
$envconfig = [env]::new()
$envconfig.vmpath = $vmpath
$envConfig.RefVHDX = $RefVHDX
$envConfig.Win16ISOPath = $config.WIN16ISO
$envConfig.Win16Net35Cab = $config.WINNET35CAB
$envConfig.network = $swname
$envconfig.DefaultPwd = $admpwd
$envConfig.Save("$vmpath`\envconfig.json")
#endregion

#region RRASConfig
$RRASConfig = [RRAS]::new()
$RRASConfig.name = $RRASname
$RRASConfig.cores = 1
$RRASConfig.ram = 4
$RRASConfig.ipaddress = "$ipsub`1"
$RRASConfig.network = $swname
$RRASConfig.localadmin = $localadmin
$RRASConfig.vmSnapshotenabled = $false
$RRASConfig.VHDXpath = "$(split-path $vmpath)\RRASc.vhdx"
$RRASConfig.RefVHDX = $RefVHDX
$RRASConfig.Save("$(split-path $vmpath)\RRASConfig.json")
#endregion

#region DCConfig
$DCConfig = [DC]::new()
$DCConfig.Name = "$($config.env)`DC"
$DCConfig.cores = 1
$DCConfig.Ram = 4
$DCConfig.IPAddress = "$ipsub`10"
$DCConfig.network = $swname
$DCConfig.VHDXpath = "$vmpath\$($config.env)`DCc.vhdx"
$DCConfig.localadmin = $localadmin
$DCConfig.domainFQDN = $domainfqdn
$DCConfig.AdmPwd = $admpwd
$DCConfig.domainuser = $domuser
$DCConfig.VMSnapshotenabled = $false
$DCConfig.refvhdx = $RefVHDX
$DCConfig.Save("$vmpath\dcconfig.json")
#endregion

#region CMConfig
$CMConfig = [CM]::new()
$CMConfig.name = "$($config.env)`CM"
$CMConfig.cores = 4
$CMConfig.ram = 12
$CMConfig.IPAddress = "$ipsub`11"
$CMConfig.network = $swname
$CMConfig.VHDXpath = "$vmpath\$($config.env)`CMc.vhdx"
$CMConfig.localadmin = $localadmin
$CMConfig.domainuser = $domuser
$CMConfig.AdmPwd = $admpwd
$CMConfig.domainFQDN = $domainfqdn
$CMConfig.VMSnapshotenabled = $false
$CMConfig.cmsitecode = $cmsitecode
$CMConfig.SCCMDLPreDownloaded = $sccmdlpredown
$CMConfig.DCIP = $DCConfig.IPAddress
$CMConfig.RefVHDX = $RefVHDX
$CMConfig.SQLISO = $config.SQLISO
$CMConfig.SCCMPath = $config.SCCMPath
$CMConfig.ADKPath = $config.ADKPATH
$CMConfig.domainnetbios = $domainnetbios
$CMConfig.save("$vmpath\cmconfig.json")
#endregion

#region create VMs
new-env -ENVConfig $envconfig
new-RRASServer -RRASConfig $RRASConfig
#new-DC -DCConfig $DCConfig
new-SCCMServer -CMConfig $CMConfig
#new-ENV -domuser $domuser -vmpath $vmpath -RefVHDX $RefVHDX -config $config -swname $swname -dftpwd $admpwd
#new-RRASServer -vmpath $vmpath -RRASname $RRASname -RefVHDX $RefVHDX -localadmin $localadmin -swname $swname -ipsub $ipsub -vmSnapshotenabled:$vmsnapshot
#new-DC -vmpath $vmpath -envconfig $envConfig -localadmin $localadmin -swname $swname -ipsub $ipsub -DomainFQDN $DomainFQDN -admpwd $admpwd -domuser $domuser -vmSnapshotenabled:$vmsnapshot
#new-SCCMServer -envconfig $envConfig -vmpath $vmpath -localadmin $localadmin -ipsub $ipsub -DomainFQDN $DomainFQDN -domuser $domuser -config $config -admpwd $admpwd -domainnetbios $domainnetbios -cmsitecode $cmsitecode -SCCMDLPreDown $SCCMDLPreDown -vmSnapshotenabled:$vmsnapshot
#new-CAServer -envconfig $envConfig -vmpath $vmpath -localadmin $localadmin -ipsub $ipsub -DomainFQDN $DomainFQDN -domuser $domuser -config $config -admpwd $admpwd -domainnetbios $domainnetbios -vmSnapshotenabled:$vmsnapshot
#endregion