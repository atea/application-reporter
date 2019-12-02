[CmdletBinding()]
Param(
    [String]$ReportingURl = "http://localhost:7071/api/Upload",
    [Switch]$Force,
    [String]$JsonSearchFolder = $PSScriptRoot
)
# $VerbosePreference = "Continue"
Function Get-StringHash([String] $String,$HashName = "MD5")
{
    $StringBuilder = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{
    [Void]$StringBuilder.Append($_.ToString("x2"))
    }
    $StringBuilder.ToString()
}

Function Get-Choice
{
    param(
        [String]$Caption = "Choose Action",
        [String]$Message = "What do you want to do?",
        [String[]]$Choices,
        [int]$DeafultChoice = 0
    )
    $_choices = [System.Management.Automation.Host.ChoiceDescription[]]::new($Choices.Count)
    for ($i = 0; $i -lt $Choices.Count; $i++) {
        $_choices[$i] =[System.Management.Automation.Host.ChoiceDescription]::new("&$($Choices[$i].tostring())",$Choices[$i].tostring())
    }

    $answer = $host.ui.PromptForChoice($caption,$message,$_choices,$DeafultChoice)
    return $answer
}

#Get wireless Mac address
$Maccaddress = (Get-WmiObject win32_networkadapterconfiguration |?{$_.description -like "*wireless*"}).macaddress|Select-Object -first 1
$MacNumber = [int]([regex]::Matches($Maccaddress,"(\d)").value -join "")
$MacNumber = Get-random -SetSeed $MacNumber -Maximum 4000

Write-host "`n`n## STARTUP ##"
Write-host "In order to not willfully give any user identifying information we will only use a hashed version of your ComputerName"
# Write-host "I will also try to replace all instances where c:\users\{username} with this MachineName."
$ComputerID = $env:COMPUTERNAME
Write-Host "Hashing Computername $macnumber times"
@(1..$MacNumber)|%{
    if($_%500 -eq 0)
    {
        Write-Verbose $_
    }
    #Get hash with a modulated set of algirithms.. Get-random will always return the same number for a set seed
    $ComputerID = Get-StringHash -String $ComputerID -HashName (@("Sha256","Md5",'SHA1')|get-random -SetSeed $_)
}
# Write-host "Hashing computername $MacNumber times with modulated sha256,sha1 and md5 to create computer ID"
Write-Host
Write-host "Your ID is: '$ComputerID'. This is the only idenifying info we get from you"

$LocalReport = Get-ChildItem $JsonSearchFolder -Filter "Report-*.json"
$Body = [pscustomobject]@{}
if($LocalReport)
{
    $File = ($localreport|Sort-Object name -Descending|Select-Object -First 1)
    $GetChoiceParam = @{
        Caption = "There is a previously created report ($($File.name))"
        Message = "do you want to use this?"
        Choices = @("no","yes")
        DeafultChoice = 0
    }
    $a = Get-Choice @GetChoiceParam

    if([bool]$a)
    {
        Write-Verbose "Loading $($file.fullname)"
        $ReportFile = $file.FullName 
        $Body = $file|get-content -raw|convertfrom-json
    }
}

if([string]::IsNullOrEmpty($Body))
{
    Write-host "Getting Installed Software from registry"
    $Reg = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*|
                ?{$_.displayname}|
                    Select-Object @{n="Name";e={$_.displayname}},
                                @{n="IDhash";e={Get-StringHash -String "$($_.displayname.replace(" ",'').tolower())$($_.Displayversion)"}},
                                @{n="Version";e={$_.Displayversion}},
                                InstallLocation,
                                InstallDate,
                                @{n="Vendor";e={$_.Publisher}},
                                @{n="Source";e={"Reg"}}
    
    Write-Verbose "Found $($reg.count) applications with REG"

    Write-host "Getting installed software from CIM/WMI (This is normally really really slow.. go take a coffee)"
    $Cim = Get-CimInstance -ClassName win32_product|
                Select-Object Name,
                            @{n="IDhash";e={Get-StringHash -String "$($_.Name.replace(" ",'').tolower())$($_.version)"}},
                            Version,
                            InstallLocation,
                            InstallDate,
                            Vendor,
                            @{n="Source";e={"Cim"}}
    Write-verbose "Found $($cim.count) application with CIM/WMI"
    $total = @()
    $total+=$Reg
    $total+=$Cim
    $Body = [pscustomobject]@{
        ComputerName = $ComputerID
        Applications = $total
    }
    $ReportFile = "$PSScriptRoot\Report-$([datetime]::now.ToString("yyMMddHHmm")).json"
    $Body|ConvertTo-Json -Depth 3|Out-File $ReportFile
}

Write-host "`n`n## CLEANUP ##"
Write-Host "Total applications found $($body.applications.count)"
Write-Host "Checking if any thing references local username or machine"
for ($i = 0; $i -lt $body.applications.count; $i++) {
    $This = $Body.applications[$i]
    if($this.installLocation -like "*$env:USERNAME*")
    # if($This.InstallLocation -match "[a-zA-Z]:\\[uU]sers\\(?'username'.*?)\\")
    {
        Write-Host "Replacing username with machine ID @ '$($this.Name)' InstallLocation"
        $Body.applications[$i].InstallLocation = $this.InstallLocation.replace($env:USERNAME,$ComputerID)
        Write-Verbose "New reported InstallLocation:'$($Body.applications[$i].InstallLocation)'"
    }
}
Write-host "`n`n## UPLOAD ##"
# Write-Host "if this script is re-run it will ask if you want to use this report again"
$GetChoiceParam = @{
    Caption = "A copy of this report is avalible at '$ReportFile'."
    Message = "Do you want to upload?"
    Choices = @("no","yes")
    DeafultChoice = 1
}
$a = Get-Choice @GetChoiceParam

#If result is 'no'
if(!$a)
{
    Write-host "Quitting"
    return $null
}

$URI = "$ReportingURl`?ID=$ComputerID"
Write-Host "Uploading to $uri"
Invoke-RestMethod -Method "Post" -Uri $URI -Body $($body|ConvertTo-Json -Depth 99)
Write-Host "Done!"