@{
    Project = @{
        Pipeline = "Prod"
        Name = "ConsultApplication"
        ConfigName = "Config"
        #Config should never be more than 2 levels
        Azconfig = @{
        }
    }
    Az = @{
        TenantName = "zemindar.onmicrosoft.com"
        SubscriptionName = "zem"
        Location = "Westeurope"
        Resources = @{
            ResourceGroup = @{
                Name = "{Pipeline}-{Options.Project.Name}-RG"
            }
            Functions = @{
                Name = "{Pipeline}{Options.Project.Name}FN"
                LocalPath = "AzFunctions"
                #How many threads do you want to run at once max for the function runspace? 1-10
                Concurrencycount = 10
            }
            StorageAccount = @{
                #Select a random number at the end here..
                Name = "{Pipeline}{Options.Project.Name}SA"
                Sku = "Standard_LRS"
                Tables = @(
                )
                Queues = @(
                )
                Containers = @(
                    "import"
                )
            }
            AppservicePlan = @{
                Name = "{Pipeline}-{Options.Project.Name}-ASP"
            }
        }
    }
    Powershell = @{
        RequiredModules = @{
            az = "2.8.*"
            azTable = "2.0.*"
            pscognitiveservice = "0.4.*"
        }
    }
}