function CheckAzurePowerShellVersion {
	if (Get-Module | where-object {$_.Name -eq "Azure"})
	{
	    Write-Host 'Found Azure module' 
    }
	else
	{
		if (Get-Module | where-object {$_.Name -eq "AzureRM"})
		{
			Write-Host 'Because of the recent breaking changes, this version of powershell is not supported. Please install any version less than or equal to 0.9.8.1' -ForegroundColor Yellow
			Write-Host 'The program will now exit' -ForegroundColor Yellow
			exit
		}
		else
		{
			Write-Host 'Unable to find Azure module, please install Azure Powershell Module' -ForegroundColor Yellow
			Write-Host 'The program will now exit' -ForegroundColor Yellow
			exit
		}
	}
} 
CheckAzurePowerShellVersion
