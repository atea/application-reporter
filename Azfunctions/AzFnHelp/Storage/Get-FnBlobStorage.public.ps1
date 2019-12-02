function Get-FnBlobContainer {
    [CmdletBinding()]
    [outputtype([Microsoft.azure.Storage.Blob.CloudBlobContainer])]
    param (
        [string]$Container,
        [string]$Connectionstring,
        [switch]$CreateIfNotExists
    )
    
    begin {
        
    }
    
    process {
        $SA = [Microsoft.Azure.Storage.cloudstorageaccount]::Parse($Connectionstring)
        $BlobClient = [Microsoft.Azure.Storage.Blob.CloudBlobClient]::new($sa.BlobStorageUri,$sa.Credentials)
        [Microsoft.azure.Storage.Blob.CloudBlobContainer]$container = $BlobClient.GetContainerReference($Container)
        # $BlobClient.GetContainerReference().
        if($CreateIfNotExists)
        {
            [void]$Container.CreateIfNotExists()
        }
        return $Container
    }
    
    end {
        
    }
}