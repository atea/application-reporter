using namespace System.Net

# Input bindings are passed in via param block.
param(
    [Microsoft.Azure.Functions.PowerShellWorker.HttpRequestContext]$Request, 
    $TriggerMetadata
)


ipmo (join-path (split-path $PSScriptRoot) "AzFnHelp")
# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

$Body = "Something happened.."

try{
    if($Request.Query.ID)
    {
        $upload = $Request.Body|ConvertFrom-Json
        $Body = "Applications: $($upload.applications.count) ($(@(($upload.applications|select -Unique IDhash)).count) Unique)"
        $Containter = Get-FnBlobContainer -CreateIfNotExists -Connectionstring $env:AzureWebJobsStorage -Container "reports"
        $Blockblob = $Containter.GetBlockBlobReference("$($Request.Query.ID)-$([datetime]::UtcNow.ToString("yyMMddHHmm")).json")
        $Blockblob.UploadTextAsync(($Upload.applications|ConvertTo-Json))
        $status = [HttpStatusCode]::OK
    }
    else {
        $body = "I need a ID to process this"
        $status = [HttpStatusCode]::Conflict
    }
}
catch{
    $status = [HttpStatusCode]::Conflict
    $Body = "Error from webpage: $_"
}

# $status = [HttpStatusCode]::OK
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})
