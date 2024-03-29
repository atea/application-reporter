# application-reporter

## Local Script
[Link](https://github.com/ateanorge/application-reporter/tree/master/Local)  
The local application (under .\local)
```
|Local
-|ApplicationReport.ps1
-|Run-FnDev.ps1
-|Run-FnLocal.ps1
-|Run
```
To run the actual script start "Run"

#### ApplicationReport.ps1
```
All parameters are optional.
Parameters:
 -Force  
        Runs the report automatically, without asking for user intervention. it will also run   the full report.

 -ReportingURl
        where to report the information

 -JsonSearchFolder
        What folder to user when searching for new report files
```

In basic steps the code will do:
1. Generate a hashed version of your computername. The times it hashes is defined by a number between 1 and 4000. This number will be calculated as the same number each time on the same computer, but will be different for each computer

2. This is defined by wether you have run the report before or not:  
* If you have run the script before it will ask if you want to use the already generated report or run the full collection again. if yes is selected, it will to step 3, if not it will go thought the full report again (see the other 2. step)
* Get all of the applications present in Registry and Win32_products wmi (Wmi/Cim takes a while). After this has be done, save a report to json in the same folder as where you ran the script from.   
**If there are other stores i should check out, please let me know.**

3. Go though the list for applications, and if it sees a install-location that references your username (IE c:\users\\{yourname}\appdata), it will replace {yourname} with The ID generated in step **1**.

4. Upload the report to azure.

#### Run.*.ps1
Mainly used for testing of different scenarios. -FnLocal.ps1 is used if you are running a functions instance locally, for rapid testing. -FnDev.ps1 is used for testing a dev function in azure.

## Azure
```
-- App Service Plan
    Used as hosting for appservice.
-- AppService/Functions
    Used to run azure functions.
-- Storage Account
    used to store data for aure functions.
-- Service principal
    Automatically generated by app service as "Managed identity"
```

## Deploy
```
To run Azure Functions locally:
    Modules:
        az
        aztables

    https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-local

To Deploy:
    Modules
        az
        Psake
use deploy.ps1
Options.psd1 Defines what to call the project and pipeline (Dev or Prod) 
```

