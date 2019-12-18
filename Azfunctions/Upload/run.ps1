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
    if($Request.Method -eq "POST")
    {
        if(![String]::IsNullOrEmpty($request.body))
        {
            $upload = $Request.Body|ConvertFrom-Json
            #Validate that the json contains "ComputerName" and 'Applications'
            if([String]::IsNullOrEmpty($upload.ComputerName))
            {
                $Body = "Could not find a ComputerID in Json: #\ComputerName\.."
                $status = [HttpStatusCode]::BadRequest
            }
            elseif ([String]::IsNullOrEmpty($upload.applications)) {
                $body = "Could not find applications field in the json: #\Applications\.."
                $status = [HttpStatusCode]::BadRequest
            }
            else {
                $Body = "Applications: $($upload.applications.count) ($(@(($upload.applications|select -Unique IDhash)).count) Unique)"
                $Containter = Get-FnBlobContainer -CreateIfNotExists -Connectionstring $env:AzureWebJobsStorage -Container "reports"
                $Blockblob = $Containter.GetBlockBlobReference("$($upload.ComputerName)-$([datetime]::UtcNow.ToString("yyMMddHHmm")).json")
                $Blockblob.UploadTextAsync(($Upload.applications|ConvertTo-Json -Depth 10))
            }
        }
        else {
            $body = "There was no information provided. please retry or contact mr bossman Bjørn Åge"
            $status = [HttpStatusCode]::BadRequest
        }
    }
    elseif($request.Method -eq "GET")
    {
        $body = "Pong"
        $status = [HttpStatusCode]::OK
    }
    else {
        $body = "It doesen't work like that, smartypants"
        $status = [HttpStatusCode]::BadRequest
        # [HttpStatusCode]::Redirect
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
