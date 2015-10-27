.\CheckAzurePowerShellVersion


#Cleanup Service Bus namespaces

Write-Host "WARNING: This script is going to delete resources that match resource names used in the lab. Please carefully review names of the resources before confirming delete operation" -ForegroundColor Yellow
Write-Host "Remove Service Bus namespaces starting with 'TollData'"
Get-AzureSBNamespace | Where-Object {$_.Name -like '*TollData*'} | Remove-AzureSBNamespace -Confirm

Write-Host "Remove Azure SQL servers with Administrator Login 'tolladmin'"
Get-AzureSqlDatabaseServer | Where-Object {$_.AdministratorLogin -eq 'tolladmin'} | Remove-AzureSqlDatabaseServer -Confirm

foreach ($storageaccount in Get-AzureStorageAccount | Where-Object {$_.StorageAccountName -like '*tolldata*'})
{
	$caption = "Choose Action";
	$message = "Are you sure you want to delete stroage account: " + $storageaccount.StorageAccountName + " ?";
	$yesanswer = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes";
	$noanswer = new-Object System.Management.Automation.Host.ChoiceDescription "&No","No";
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yesanswer,$noanswer);
	$answer = $host.ui.PromptForChoice($caption,$message,$choices,1)

	switch ($answer){
		0 {$storageaccount | Remove-AzureStorageAccount; break}
		1 {break}
	}
}
