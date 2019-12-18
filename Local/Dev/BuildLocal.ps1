
$Files = @(
    "Run-FnProd.ps1"
    "ApplicationReport.ps1"
)

$archivename = "$(split-path $PSScriptRoot)\Report-Tool.zip"
$archive = get-item $archivename -ErrorAction SilentlyContinue
if([bool]$archive)
{
    $archive|remove-item
}

gci $PSScriptRoot|?{$_.name -in $Files}|Compress-Archive -CompressionLevel Optimal -DestinationPath $archivename #,"*report.ps1" #-Include $Files

# $archive = get-item "$(split-path $PSScriptRoot)\Report-Tool.zip" -ErrorAction SilentlyContinue



# $Files|
# $files|%{get-item "$PSScriptRoot\$file"|Compress-Archive -}
# Foreach($file in $files)
# {
# }