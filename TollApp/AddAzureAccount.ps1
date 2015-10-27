.\CheckAzurePowerShellVersion

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


