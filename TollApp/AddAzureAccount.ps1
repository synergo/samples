function CheckAzurePowerShellVersion {
	if (Get-Module -ListAvailable -Name Azure)
	{
	    Write-Host 'Found Azure module' 
    }
	else
	{
		if (Get-Module -ListAvailable -Name AzureRM)
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

# Add Azure account
Add-AzureAccount

# If there are multiple subscriptions we will need to select one
$subscriptions = Get-AzureSubscription
if ($subscriptions.GetType().IsArray)
{
	Write-Host "Multiple subscriptions found:"  -ForegroundColor Yellow
	$subscriptions | select SubscriptionName
	Write-Host "There are mutiple subscriptions found for your account. Please type the name of the subscription you want to use:" -ForegroundColor Yellow

	$subscriptinName = Read-Host "Subscription Name"
	Select-AzureSubscription -SubscriptionName $subscriptinName
}


