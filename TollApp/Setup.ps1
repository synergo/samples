<#
********************************************************* 
* 
*    Copyright (c) Microsoft. All rights reserved. 
*    This code is licensed under the Microsoft Public License. 
*    THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF 
*    ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY 
*    IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR 
*    PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT. 
* 
*********************************************************
#>


[CmdletBinding()]
Param(
   [Parameter()]
   [Alias("mode")]
   [string]$global:mode = 'deploy',

   [Parameter()]
   [Alias("location")]
   [string]$global:customlocation = ''
)


function ValidateParameters{
    $modeList = 'deploy', 'list', 'delete'
	$global:SupportedLocations = 'South Central US', 'North Central US', 'Central US', 'West US', 'East US', 'East US2', 'Japan East', 'Japan West', 'East Asia', 'South East Asia'
    
	if($modeList -notcontains $global:mode){
        Write-Host ''
        Write-Host 'MISSING REQUIRED PARAMETER: -mode parameter must be set to one of: ' $modeList
        $global:mode = Read-Host 'Enter mode'
        while($modeList -notcontains $global:mode){
            Write-Host 'Invalid mode. Please enter a mode from the list above.'
            $global:mode = Read-Host 'Enter mode'                     
        }
    }

	if ($global:customlocation -ne ''){
		$validLocations = $SupportedLocations | foreach  {"$($_.ToLower())"}
		
		if($validLocations  -notcontains $global:customlocation.ToLower()){
			Write-Host ''
			Write-Host 'INVALID OPTIONAL PARAMETER: -location parameter must be set to one of: ' 
			Write-Host $SupportedLocations -Separator ", "
			$global:customlocation = Read-Host 'Enter Location'
			while($validLocations -notcontains $global:customlocation.ToLower()){
				Write-Host 'Invalid location. Please enter a location from the list above.'
				$global:customlocation = Read-Host 'Enter Location'                     
			}
		}
	}
}

function LoadLocation{
    $rowNumber = 1
    $LabLocations = 'South Central US', 'West US', 'East US', 'Central US'
    $validLocations = $global:SupportedLocations | foreach  {"$($_.ToLower())"}
    if($global:location -eq $null) {$global:location = ''}
    
    if($validLocations  -contains $global:location.ToLower()){
        return
    }

    # Select a random location
    Write-Host "Indentifying Location for your lab " -NoNewLine
    $randLocationIndex = Get-Random -Minimum 1 -Maximum ($LabLocations.Count + 1)
    $global:location = $LabLocations[$randLocationIndex - 1]
    Write-Host $global:location 
}

function SetResourceParams {
    $global:useCaseName = "TollData"
    $global:defaultResourceName =  $global:useCaseName + $global:resourceSuffix  
	$global:entryEventHubName = "entry"
    $global:exitEventHubName = "exit"
	$global:ServiceBusNamespace = $global:defaultResourceName
    $global:sqlDBName = $global:useCaseName + "DB"
    $global:sqlServerLogin = 'tolladmin'
    $global:sqlServerPassword = '123toll!'   
    $global:storageAccountName = "tolldata" + $global:resourceSuffix   
}


function InitializeSubscription{
    $global:Validated = $false
    ValidateSubscription

    if($global:AzureAccountIntialized -ne 1){InitSubscription}

    # Check if subscription is already initialized
    $SubscriptionSettingFile = $PSScriptRoot + '\\Settings-' + $global:subscriptionId + '.xml'
    $FileExists = Test-Path $SubscriptionSettingFile
    If ($FileExists -eq $True) {
        $loaded = LoadSubscription $SubscriptionSettingFile
    }
    if($loaded -ne $true){
        $global:resourceSuffix = Get-Random -Maximum 9999999999
		if($global:customLocation -eq ''){
			$global:location = $null
		}
		else
		{
			$global:location = $global:customLocation
		}
        
    }
    LoadLocation
    SetResourceParams
    SaveSubscription
}

function LoadSubscription($fileName){
    try
    {
        [xml] $settings = Get-Content $fileName
        $global:location = $settings.Settings.Location
        $global:resourceSuffix = $settings.Settings.ResourceSuffix
        $global:sqlServerName = $settings.Settings.SqlServerName

        return $true
    }
    catch{
        return $false
    }
}

function SaveSubscription{
    $fileName = $PSScriptRoot + '\\Settings-' + $global:subscriptionId + '.xml'
    Out-File -filePath $fileName -force -InputObject "<Settings><Location>$global:location</Location><ResourceSuffix>$global:resourceSuffix</ResourceSuffix><SqlServerName>$global:sqlserverName</SqlServerName></Settings>"
}

function InitSubscription{
       
    #Remove all Azure Account from Cache if any
    Get-AzureAccount | ForEach-Object { Remove-AzureAccount $_.ID -Force -WarningAction SilentlyContinue }

    #login
    Add-AzureAccount -WarningAction SilentlyContinue | out-null
    $account = Get-AzureAccount
	Write-Host You are signed-in with $account.id

 	$subList = Get-AzureSubscription
	if($subList.Length -lt 1){
		throw 'Your azure account does not have any subscriptions.  A subscription is required to run this tool'
	} 

	$subCount = 0
	foreach($sub in $subList){
		$subCount++
		$sub | Add-Member -type NoteProperty -name RowNumber -value $subCount
	}

	if($subCount -gt 1)
	{
		Write-Host ''
		Write-Host 'Your Azure Subscriptions: '
		
		$subList | Format-Table RowNumber,SubscriptionId,SubscriptionName -AutoSize
		$rowNum = Read-Host 'Enter the row number (1 -'$subCount') of a subscription'

		while( ([int]$rowNum -lt 1) -or ([int]$rowNum -gt [int]$subCount)){
			Write-Host 'Invalid subscription row number. Please enter a row number from the list above'
			$rowNum = Read-Host 'Enter subscription row number'                     
		}
	}
	else{
		$rowNum = 1
	}
	
	$global:subscriptionID = $subList[$rowNum-1].SubscriptionId;
	$global:subscriptionDefaultAccount = $subList[$rowNum-1].DefaultAccount.Split('@')[0]

#switch to appropriate subscription 
    try{ 
        Select-AzureSubscription -SubscriptionId $global:subscriptionID 
    }  
    catch{ 
        throw 'Subscription ID provided is invalid: ' + $global:subscriptionID     
    } 

}

function ValidateSubscription{
    #Check if the current subscription is available
    $global:AzureAccountIntialized = 0
    if($global:subscriptionID -ne $null -and $global:subscriptionID -ne ''){
        $subscription = Get-AzureSubscription -SubscriptionId $global:subscriptionID -ErrorAction SilentlyContinue
        if($subscription -ne $null){
            $locations = Get-AzureLocation -ErrorAction SilentlyContinue
            if($locations -ne $null){
                $global:AzureAccountIntialized = 1
            }
        }
    }
}

function CreateAndValidateStorageAccount{
    $containerName = "tolldata"
    $storageAccount = Get-AzureStorageAccount -StorageAccountName $global:storageAccountName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if($storageAccount -eq $null){
		Write-Host "Creating AzureStorageAccount [ $global:storageAccountName ]...." -NoNewline
        New-AzureStorageAccount -StorageAccountName $global:storageAccountName -Location $global:location -Label "ASAHandsOnLab"
        Write-Host Write-Host "AzureStorageAccount [ $global:storageAccountName ] created." 
    }
	else{
		Write-Host "AzureStorageAccount [ $global:storageAccountName ] already exists." 
	}
	
    $storageKeys = Get-AzureStorageKey -StorageAccountName $storageAccountName
    $global:storageAccountKey = $storageKeys.Primary
    $storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKeys.Primary
    $container = $null
    
    try{
        $container = Get-AzureStorageContainer -Name $containerName -Context $storageContext -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
    catch{
        $container = $null
    }
    
    if($container -eq $null){
		Write-Host "Creating Container [ $containerName ]...." -NoNewline
        $container = New-AzureStorageContainer -Name $containerName -Context $storageContext 
		Write-Host "created"
    }
	else{
		Write-Host "Container [ $containerName ] exists" 
	}
	
	Write-Host "Uploading reference data to container...." -NoNewline
    $copyResult = Set-AzureStorageBlobContent -file ($PSScriptRoot + "\\Data\\Registration.json") -Container tolldata -Blob "registration.json" -Context $storageContext -Force
    Write-Host "Completed"
}

function CreateSqlServer{
	Write-Host 'Creating SQL Server ...... ' -NoNewline
    $sqlsvr = New-AzureSqlDatabaseServer -location $global:location -AdministratorLogin $global:sqlServerLogin -AdministratorLoginPassword $global:sqlServerPassword
    if($sqlsvr -eq $null){
        throw $Error
    }

    $sqlsvrname = $sqlsvr.ServerName
    $createdNew = $TRUE;
                
    Write-Host '[svr name: ' $sqlsvrname ']....created.' 
    $global:sqlserverName = $sqlsvrname

    #Setting firewall rule
    $rule = New-AzureSqlDatabaseServerFirewallRule -ServerName $sqlsvr.ServerName -RuleName "demorule" -StartIPAddress "0.0.0.0" -EndIPAddress "255.255.255.255" -ErrorAction Stop
}

function CreateAndValidateSQLServerAndDB{
    process{
        
        #create sql server & DB
        $sqlsvr = $null
        $createdNew = $FALSE
        try{ 
     
            if($global:sqlserverName -eq $null -or $global:sqlserverName.Length -le 1){
                CreateSqlServer
            }
            else{
                $server = Get-AzureSqlDatabaseServer -ServerName $global:sqlserverName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                if($server -eq $null)
                {
                    CreateSqlServer
                }
				else{
					Write-Host "SQL Server [ $global:sqlserverName ] exists." 
				}
            }

            $check = Get-AzureSqlDatabase -ServerName $global:sqlserverName -DatabaseName $global:sqlDBName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if(!$check){
                #Creating Database
                Write-Host "Creating SQL DB [ $global:sqlDBName ]......" -NoNewline 
                $servercredential = new-object System.Management.Automation.PSCredential($global:sqlServerLogin, ($global:sqlServerPassword  | ConvertTo-SecureString -asPlainText -Force))
                #create a connection context
                $ctx = New-AzureSqlDatabaseServerContext -ServerName $global:sqlserverName -Credential $serverCredential
                $sqldb = New-AzureSqlDatabase $ctx -DatabaseName $global:sqlDBName -Edition Basic | out-null
                Write-Host 'created.'
            }
			else{
				Write-Host "SQL Database [ $global:sqlDBName ] exists in server [ $global:sqlserverName ]" 
			}
        } 
        catch{        
            Write-Host 'error.'
            throw
        }
        return $sqldb
    }
}

function CreateSqlTable{
	# Create Sql tables
	Write-Host "Creating required sqlTables......" -NoNewline
	$sqlConnString = GetSqlConnectionString
	$sqlConn= New-Object System.Data.SqlClient.SqlConnection($sqlConnString)
	$sqlConn.Open()

	$cmdText = [System.IO.File]::ReadAllText("$PSScriptRoot\\SqlScripts\\CreateTables.sql")
	$sqlCmd= New-Object System.Data.SqlClient.SqlCommand($cmdText,$sqlConn)
	$cmdResult = $sqlCmd.ExecuteNonQuery()
	$sqlConn.Close()
	Write-Host "created."
}

function GetSqlConnectionString{
    return "Server=tcp:$global:sqlserverName.database.windows.net,1433;Database=$global:sqlDBName;Uid=$global:sqlServerLogin@$global:sqlserverName;Pwd=

$global:sqlServerPassword;Encrypt=yes;Connection Timeout=30;"
}


function CreateAndValidateSBNamespace{
  
    Process{
        $namespace = $null
        try{
			# WARNING: Make sure to reference the latest version of the \Microsoft.ServiceBus.dll
			$namespace = Get-AzureSBNamespace -Name $global:ServiceBusNamespace 
			if($namespace.name -eq $null){
			    Write-Host "Creating the Service Bus Namespace [ $global:ServiceBusNamespace ]......" -NoNewline
                #create a new Service Bus Namespace
                $namespace = New-AzureSBNamespace -Name $global:ServiceBusNamespace -Location $global:location -CreateACSNamespace $true -NamespaceType Messaging -ErrorAction Stop
			    Write-Host 'created.'
			}
			else{
			    Write-Host "ServiceBusNamespace $global:ServiceBusNamespace exists"
			}
	    }
        catch{
            Write-Host 'error.'
            throw
        }
               
        try{		
            $global:constring = Get-AzureSBAuthorizationRule -Namespace $global:ServiceBusNamespace
			$constringparse = $global:constring.ConnectionString.Split(';')
			$global:sharedaccesskeyname = $constringparse[1].Substring(20)
			$global:sharedaccesskey = $constringparse[2].Substring(16)
        }
        catch{
            Write-Host 'error.'
		    throw
        }
    }
}


function CreateAndValidateEventHub($eventHubName)
{
 
    Process{
        $namespace = $null
		$eventhub = $null
        
        try{		
			#Create the NamespaceManager object to create the event hub
			$currentnamespace = Get-AzureSBNamespace -Name $global:ServiceBusNamespace
            $nsMgrType = [System.Reflection.Assembly]::LoadFrom($PSScriptRoot +"\Microsoft.ServiceBus.dll").GetType("Microsoft.ServiceBus.NamespaceManager")
			
            $namespacemanager = $nsMgrType::CreateFromConnectionString($currentnamespace.ConnectionString);
			Write-Host 'Creating EventHub [' $eventHubName ']......' -NoNewline
			$eventhub = $namespacemanager.CreateEventHubIfNotExists($eventHubName)
			Write-Host 'created.'
        }
        catch{
            Write-Host 'error.'
		    throw
        }
    }
}

function DeleteSBNameSpace {
#Cleanup Service Bus namespaces

Write-Host "WARNING: This script is going to delete resources that match resource names used in the lab. Please carefully review names of the resources before confirming 

delete operation" -ForegroundColor Yellow
Write-Host "Remove Service Bus namespaces starting with '$global:useCaseName'"
Get-AzureSBNamespace | Where-Object {$_.Name -like "*" + $global:useCaseName + "*"} | Remove-AzureSBNamespace -Confirm
}

function DeleteSqlServer{
Write-Host "Remove Azure SQL servers with Administrator Login 'tolladmin'"
Get-AzureSqlDatabaseServer | Where-Object {$_.AdministratorLogin -eq 'tolladmin'} | Remove-AzureSqlDatabaseServer -Confirm
}

function DeleteStorageAccount{
foreach ($storageaccount in Get-AzureStorageAccount -WarningAction SilentlyContinue | Where-Object {$_.StorageAccountName -like "*$global:useCaseName*"})
{
	$caption = "Choose Action";
	$message = "Are you sure you want to delete stroage account: " + $storageaccount.StorageAccountName + " ?";
	$yesanswer = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes";
	$noanswer = new-Object System.Management.Automation.Host.ChoiceDescription "&No","No";
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yesanswer,$noanswer);
	$answer = $host.ui.PromptForChoice($caption,$message,$choices,1)

	switch ($answer){
		0 {$storageaccount | Remove-AzureStorageAccount -WarningAction SilentlyContinue; break}
		1 {break}
	}
}
}

function ShowMenu{

    Write-Host ""
    Write-Host " Command Options "
    Write-Host ""
    Write-Host '1 - Create or Validate Resources'
    Write-Host '2 - List Resources'
    Write-Host '3 - Start Event Generator'
    Write-Host '4 - Delete Resources'
    Write-Host '5 - Exit'
    Write-Host ""

    $SelectedAction = Read-Host 'Enter menu option (1 - 5)'
	while( ([int]$SelectedAction -lt 1) -or ([int]$SelectedAction -gt 5)){
		Write-Host 'Invalid Menu option. Please enter a number from the list above'
		$SelectedAction = Read-Host 'Enter menu option (1 - 5)'                     
	}

    return $SelectedAction
}

function IntitializeAccount{
	InitSubscription
	ValidateSubscription
}


function CreateAndValidateResources{
	
    Write-Host "Creating/Validating resources for Toll App"
    CreateAndValidateSBNamespace
	CreateAndValidateEventHub($global:entryEventHubName)
	CreateAndValidateEventHub($global:exitEventHubName)
    CreateAndValidateSQLServerAndDB
    CreateSqlTable
    CreateAndValidateStorageAccount
    SaveSubscription
    $global:Validated = $true
}

function LaunchGenerator{
    if($global:Validated -eq $false){
        Write-Host "Create/Validate resource before List Resources"
        return
    }
    $configFile = "$PSScriptRoot\\TollApp.exe.config"
    $exeFile = "$PSScriptRoot\\TollApp.exe"
    [xml] $configXml = Get-Content $configFile
    $configXml.configuration.appSettings.add.value = $global:constring.ConnectionString
    $configXml.Save($configFile)
    start-process $exeFile 
}

function ListResources{
    if($global:Validated -eq $false){
        Write-Host "Create/Validate resource before List Resources"
        return
    }
	$account = Get-AzureAccount
	$subscription = Get-AzureSubscription -SubscriptionId $global:subscriptionID
    Write-Host ""
    Write-Host "All Resource Names"
    Write-Host ""
	Write-Host "You are signed-in with " $account.id
	Write-Host "Subscription Id: " $subscription.SubscriptionID
	Write-Host "Subscription Name: " $subscription.SubscriptionName
	Write-Host ""
    Write-Host "Service Bus:"
    Write-Host "`tNamespace: $global:ServiceBusNamespace"
    Write-Host "`tSharedAccessKeyName: $global:sharedaccesskeyname"
    Write-Host "`tSharedAccessKey: $global:sharedaccesskey"
    Write-Host ""
    Write-Host "Sql Server:"
    Write-Host "`tServer: $global:sqlserverName.database.windows.net"
    Write-Host "`tSqlLogin: $global:sqlServerLogin"
    Write-Host "`tPassword: $global:sqlServerPassword"
    Write-Host "`tDatabaseName: $global:sqlDBName"
    Write-Host ""
    Write-Host "Storage Account:"
    Write-Host "`tAccountName: $global:storageAccountName"
    Write-Host "`tAccountKey: $global:storageAccountKey"
    Write-Host ""
    Write-Host "Location: " $global:location 
    Write-Host ""
    Write-Host ""
}

function DeleteResources{
    DeleteSBNameSpace 
    DeleteSqlServer
    DeleteStorageAccount
    Remove-Item "$PSScriptRoot\\Settings-$global:subscriptionId.xml" -ErrorAction SilentlyContinue
    $global:subscriptionID = ""
    exit
}

#start of main script
$storePreference = $Global:VerbosePreference
$debugPreference= $Global:DebugPreference


$Global:VerbosePreference = "SilentlyContinue"
$Global:DebugPreference="SilentlyContinue"

dir | unblock-file
ValidateParameters
InitializeSubscription

switch($global:mode){
    'deploy'{
        CreateAndValidateResources
        ListResources
        LaunchGenerator
    }
    'list'{
        CreateAndValidateResources
        ListResources
    }
    'delete'{ DeleteResources }
}

$Global:VerbosePreference = $storePreference
$Global:DebugPreference= $debugPreference
