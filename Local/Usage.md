* Download report-tool.zip
* Unpack all files to a path of your choosing
* Start a new Powershell window and browse to your folder with `cd "c:\path\to\folder"`
* run the command `gci|unblock-file`
* run the command `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`
* run the file `.\Run-fnprod.ps1`