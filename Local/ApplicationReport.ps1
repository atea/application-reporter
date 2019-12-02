[CmdletBinding()]
Param(
    [ValidateNotNullOrEmpty()]
    [String]$ReportingURl,
    [Switch]$Force,
    [String]$ReportFolder = $PSScriptRoot
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


#Get Computer GUID, set from OEM
$ID = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
#IF GUID is NIL or "FF...", it means that OEM didnt add this key. fo to fallback.
if([string]::IsNullOrEmpty($ID) -or $id -eq "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
{
    #Fallback: GUID Set dring Windows install
    Write-Verbose "Machine GUID Not found. Falling back to System GUID"
    $ID = (Get-ItemProperty "HKlm:\SOFTWARE\Microsoft\Cryptography").machineGUID
}

#Scale all the numbers down to INT64
$IDNumber = [long]"$([regex]::Matches($ID,"(\d)").value -join '')".Substring(0,18)
#Modulate it down to Int32. get random only support Int32
$IDNumber = $IDNumber%[int]::MaxValue
#Get a random numer between IdNumber and 4000
$IDNumber = Get-random -SetSeed $IdNumber -Maximum 4000

Write-host "`n`n## STARTUP ##"
Write-host "In order to not willfully give any user identifying information we will only use a hashed version of your ComputerName"
$ComputerID = $env:COMPUTERNAME
Write-Host "Hashing Computername $IDNumber times"
#For each number between 1 and whatever number you get
@(1..$IDNumber)|%{

    #Report verbose about progress
    if($_%500 -eq 0)
    {
        Write-Verbose $_
    }
    #Get hash with a modulated set of hashing algorithms.. Get-random will always return the same number for a set seed
    $ComputerID = Get-StringHash -String $ComputerID -HashName (@("Sha256","Md5",'SHA1')|get-random -SetSeed $_)
}

Write-Host ""
Write-host "Your ID is: '$ComputerID'. This is the only 'idenifying' info we get from you"

#Get all reports from the same folder as script that starts with 'Report-' and ends with '.json'
$LocalReport = Get-ChildItem $ReportFolder -Filter "Report-*.json"
$Body = [pscustomobject]@{}

#If there is a report file AND -Force is not defined when starting the script
if($LocalReport -and !$Force)
{
    $File = ($localreport|Sort-Object name -Descending|Select-Object -First 1)
    $GetChoiceParam = @{
        Caption = "There is a previously created report ($($File.name))"
        Message = "do you want to use this?"
        Choices = @("no","yes")
        DeafultChoice = 0
    }
    $a = Get-Choice @GetChoiceParam

    #If yes is selected
    if([bool]$a)
    {
        Write-Verbose "Loading $($file.fullname)"
        $ReportFile = $file.FullName 
        $Body = $file|get-content -raw|convertfrom-json
    }
}
else 
{
    #Creating report of applications installed on wow6432. not shoing the items that doesnet have a displayname
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
    
    #Gerating report from ye olde WMI win32_product (Now called CIM). Jesus this thing is slow
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
    
    #Combining the reports
    $total = @()
    $total+=$Reg
    $total+=$Cim
    
    #Creating a report of comuptername and applications
    $Body = [pscustomobject]@{
        ComputerName = $ComputerID
        Applications = $total
    }
    
    #Output the report to a json file
    $ReportFile = "$ReportFolder\Report-$([datetime]::now.ToString("yyMMddHHmm")).json"
    $Body|ConvertTo-Json -Depth 3|Out-File $ReportFile
}

Write-host "`n`n## CLEANUP ##"
Write-Host "Total applications found $($body.applications.count)"
Write-Host "Checking if any thing references local username or machine"
for ($i = 0; $i -lt $body.applications.count; $i++) {
    $This = $Body.applications[$i]
    
    #If install location references username, replace them with machine ID
    if($this.installLocation -like "*$env:USERNAME*")
    {
        Write-Host "Replacing username with machine ID @ '$($this.Name)' InstallLocation"
        $Body.applications[$i].InstallLocation = $this.InstallLocation.replace($env:USERNAME,$ComputerID)
        Write-Verbose "New reported InstallLocation:'$($Body.applications[$i].InstallLocation)'"
    }
}
Write-host "`n`n## UPLOAD ##"
if(!$Force)
{
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
}

$URI = "$ReportingURl`?ID=$ComputerID"
Write-Host "Uploading to $uri"
Invoke-RestMethod -Method "Post" -Uri $URI -Body $($body|ConvertTo-Json -Depth 99)
Write-Host "Done!"