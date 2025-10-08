# ============================================================================
# Microsoft Sentinel Vectra XDR Complete Deployment Script
# ============================================================================

Write-Host "`n🚀 Welcome to the Microsoft Sentinel Vectra XDR Complete Deployment Script!" -ForegroundColor Cyan
Write-Host "This script will deploy the Vectra XDR Solution, Data Connector, Playbooks and Analytic Rules" -ForegroundColor Cyan
Write-Host "`n📋 Please ensure your Log Analytics workspace exists and Microsoft Sentinel is enabled." -ForegroundColor Cyan
Write-Host "`nLet's get started!" -ForegroundColor Green

# ============================================================================
# COMMON INPUTS
# ============================================================================
Write-Host "`n📝 Common Configuration" -ForegroundColor Yellow
$subscriptionId = Read-Host "Enter your Azure Subscription ID"
$resourceGroup = Read-Host "Enter the Resource Group name where Sentinel is enabled"
$workspaceName = Read-Host "Enter the Log Analytics Workspace name"
$workspaceLocation = Read-Host "Enter the Workspace Location (Example: eastus, westeurope)"

# ============================================================================
# AZURE LOGIN & CONTEXT
# ============================================================================
Write-Host "`n🔐 Checking Azure login..."
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "🔄 Logging in to Azure..."
        Connect-AzAccount | Out-Null
    }
}
catch {
    Write-Host "🔄 Logging in to Azure..."
    Connect-AzAccount | Out-Null
}

Write-Host "`n🔧 Setting subscription context..."
Set-AzContext -SubscriptionId $subscriptionId | Out-Null


# ============================================================================
# PART 1: SOLUTION DEPLOYMENT
# ============================================================================
Write-Host "`n"
Write-Host "PART 1: SOLUTION DEPLOYMENT" -ForegroundColor Magenta

do {
    $deploySolution = Read-Host "`nDo you want to deploy the Vectra XDR Sentinel Solution? (yes/no)"
    $deploySolution = $deploySolution.ToLower()
} while ($deploySolution -notmatch "^(yes|y|no|n)$")

if ($deploySolution -match "^(yes|y)$") {
    Write-Host "`n📝 Solution Configuration" -ForegroundColor Yellow

   #$solutionGithubUrl = "https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/Solutions/Vectra%20XDR/Package/mainTemplate.json"
    $solutionGithubUrl = "https://raw.githubusercontent.com/fenil-savani/Data-Connectors/refs/heads/main/mainTemplate.json"
    $tempSolutionPath = "$HOME/solution_mainTemplate.json"

    Write-Host "`n📥 Downloading Solution ARM template..."
    try {
        Invoke-WebRequest -Uri $solutionGithubUrl -OutFile $tempSolutionPath -UseBasicParsing
        Write-Host "✅ Solution template downloaded successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to download solution template: $_" -ForegroundColor Red
        Write-Host "⚠️ Continuing to next deployment..." -ForegroundColor Yellow
        $deploySolution = "failed"
    }

    if ($deploySolution -ne "failed") {
        $solutionParameters = @{
            "workspace"          = $workspaceName
            "workspace-location" = $workspaceLocation
        }

        $solutionDeploymentName = "SentinelSolution_" + (Get-Date -Format "yyyyMMddHHmmss")
        Write-Host "`n🚀 Starting solution deployment '$solutionDeploymentName'..."

        try {
            $deploymentResult = New-AzResourceGroupDeployment `
                -Name $solutionDeploymentName `
                -ResourceGroupName $resourceGroup `
                -TemplateFile $tempSolutionPath `
                -TemplateParameterObject $solutionParameters `
                -Verbose

            if ($deploymentResult.ProvisioningState -eq "Succeeded") {
                Write-Host "`n✅ Solution deployment completed successfully!" -ForegroundColor Green
            }
            else {
                Write-Host "`n❌ Solution deployment failed: $_" -ForegroundColor Red
                Write-Host "⚠️ Continuing to data connector deployment..." -ForegroundColor Yellow
                $deploySolution = "failed"
            }
        }
        catch {
            Write-Host "`n❌ Solution deployment failed: $_" -ForegroundColor Red
            Write-Host "⚠️ Continuing to data connector deployment..." -ForegroundColor Yellow
            $deploySolution = "failed"
        }
    }
}
else {
    Write-Host "`n⏭️ Solution deployment skipped." -ForegroundColor Yellow
}

# ============================================================================
# PART 2: DATA CONNECTOR DEPLOYMENT
# ============================================================================
Write-Host "`n"
Write-Host "PART 2: VECTRA XDR DATA CONNECTOR DEPLOYMENT" -ForegroundColor Magenta

do {
    $deployConnector = Read-Host "`nDo you want to deploy the Vectra XDR Data Connector? (yes/no)"
    $deployConnector = $deployConnector.ToLower()
} while ($deployConnector -notmatch "^(yes|y|no|n)$")

if ($deployConnector -match "^(yes|y)$") {
    Write-Host "`n📝 Vectra XDR Data Connector Configuration" -ForegroundColor Yellow

    # Function App Name
    $functionAppName = Read-Host "Enter Function App Name (1-11 characters, default: Vectra)"
    if ([string]::IsNullOrWhiteSpace($functionAppName)) {
        $functionAppName = "Vectra"
    }

    # Vectra Base URL
    do {
        $vectraBaseUrl = Read-Host "Enter Vectra Base URL starting with 'https://' (Example: https://your-vectra-instance.portal.vectra.ai)"
        if ($vectraBaseUrl -notmatch '^https://') {
            Write-Host "❌ URL must start with https://" -ForegroundColor Red
        }
    } until ($vectraBaseUrl -match '^https://')
    $vectraBaseUrl = $vectraBaseUrl.TrimEnd('/')

    # Azure Key Vault
    $azureKeyVault = "vault.azure"

    # Vectra API Credentials for different endpoints
    Write-Host "`n🔑 Vectra API Credentials Configuration"
    Write-Host "Note: You can leave fields empty if you don't want to configure specific APIs" -ForegroundColor Cyan
    
    $healthClientId = Read-Host "Enter Vectra Client ID for Health API (optional)"
    $healthClientSecret = Read-Host "Enter Vectra Client Secret for Health API (optional)"
    
    $entityScoringClientId = Read-Host "Enter Vectra Client ID for Entity Scoring API (optional)"
    $entityScoringClientSecret = Read-Host "Enter Vectra Client Secret for Entity Scoring API (optional)"
    
    $detectionsClientId = Read-Host "Enter Vectra Client ID for Detections API (optional)"
    $detectionsClientSecret = Read-Host "Enter Vectra Client Secret for Detections API (optional)"
    
    $auditsClientId = Read-Host "Enter Vectra Client ID for Audits API (optional)"
    $auditsClientSecret = Read-Host "Enter Vectra Client Secret for Audits API (optional)"
    
    $lockdownClientId = Read-Host "Enter Vectra Client ID for Lockdown API (optional)"
    $lockdownClientSecret = Read-Host "Enter Vectra Client Secret for Lockdown API (optional)"
    
    $hostEntityClientId = Read-Host "Enter Vectra Client ID for Host Entity API (optional)"
    $hostEntityClientSecret = Read-Host "Enter Vectra Client Secret for Host Entity API (optional)"
    
    $accountEntityClientId = Read-Host "Enter Vectra Client ID for Account Entity API (optional)"
    $accountEntityClientSecret = Read-Host "Enter Vectra Client Secret for Account Entity API (optional)"

    # Key Vault Configuration
    do {
        $createKeyVault = Read-Host "Do you want to create a new Key Vault for storing Vectra credentials? (yes/no)"
        $createKeyVault = $createKeyVault.ToLower()
    } while ($createKeyVault -notmatch "^(yes|y|no|n)$")

    if ($createKeyVault -match "^(yes|y)$") {
        do {
            $keyVaultName = Read-Host "Enter Key Vault Name"
        } while ([string]::IsNullOrWhiteSpace($keyVaultName))
    }
    else {
        do {
            $keyVaultName = Read-Host "Enter existing Key Vault Name"
        } while ([string]::IsNullOrWhiteSpace($keyVaultName))
    }

    if ($createKeyVault -match "^(yes|y)$") {
        Write-Host "📦 Creating Key Vault: $keyVaultName..."

        try {
            # Create Key Vault with access policy model (not RBAC)
            $keyVault = New-AzKeyVault `
                -Name $keyVaultName `
                -ResourceGroupName $resourceGroup `
                -Location $workspaceLocation `
                -EnabledForTemplateDeployment `
                -DisableRbacAuthorization
                
            Write-Host "✅ Key Vault created successfully with Vault Access Policy model" -ForegroundColor Green

            # Set access policy for current user after creation
            try {
                # Instead of getting current user's Object ID, get the Application's Object ID
                $currentUser = Get-AzContext
                $currentUserUPN = $currentUser.Account.Id
                    
                # Try to get current user's object ID
                try {
                    $azAccount = az account show --query user.name -o tsv 2>$null
                    if ($azAccount) {
                        $objectIdResult = az ad user show --id $azAccount --query id -o tsv 2>$null
                        if ($objectIdResult) {
                            $currentUserObjectId = $objectIdResult
                            Write-Host "✅ Got Object ID using Azure CLI: $currentUserObjectId" -ForegroundColor Green
                        }
                    }
                }
                catch {
                    Write-Host "⚠️ Azure CLI method failed: $_" -ForegroundColor Yellow
                }
                if ($currentUserObjectId) {
                    # Set access policy for the application instead of current user
                    Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $currentUserObjectId -PermissionsToKeys @('Get', 'List', 'Update', 'Create', 'Import', 'Delete', 'Recover', 'Backup', 'Restore') -PermissionsToSecrets @('Get', 'List', 'Set', 'Delete', 'Recover', 'Backup', 'Restore')
                    Write-Host "✅ Access policy set for current user" -ForegroundColor Green
                        
                    # Wait for access policy to propagate
                    Write-Host "⏳ Waiting for access policy to propagate..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 10
                    Write-Host "`n🔐 Storing Vectra API credentials in Key Vault..." -ForegroundColor Magenta

                    # Helper function to create a secret with error handling
                    function Set-KeyVaultSecretWithCheck {
                        param (
                            [string]$VaultName,
                            [string]$SecretName,
                            [string]$SecretValue,
                            [switch]$AsSecureString
                        )
    
                        if ([string]::IsNullOrWhiteSpace($SecretValue)) {
                            Write-Host "ℹ️ Skipping empty secret: $SecretName" -ForegroundColor Cyan
                            return
                        }
    
                        try {
                            $secValue = ConvertTo-SecureString $SecretValue -AsPlainText -Force
                            $result = Set-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -SecretValue $secValue
        
                            if ($result) {
                                Write-Host "✅ Created secret: $SecretName" -ForegroundColor Green
                            }
                            else {
                                Write-Host "❌ Failed to create secret: $SecretName" -ForegroundColor Red
                            }
                        }
                        catch {
                            Write-Host "❌ Error creating secret $SecretName $_" -ForegroundColor Red
                        }
                    }

                    if ($healthClientId) {
                        # Store Health API credentials
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Health-ClientId" -SecretValue $healthClientId
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Health-ClientSecret" -SecretValue $healthClientSecret
                    }

                    if ($entityScoringClientId) {
                        # Store Entity Scoring API credentials
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-EntityScoring-ClientId" -SecretValue $entityScoringClientId
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-EntityScoring-ClientSecret" -SecretValue $entityScoringClientSecret
                    }

                    if ($detectionsClientId) {
                        # Store Detections API credentials
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Detections-ClientId" -SecretValue $detectionsClientId
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Detections-ClientSecret" -SecretValue $detectionsClientSecret
                    }

                    if ($auditsClientId) {
                        # Store Audits API credentials
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Audits-ClientId" -SecretValue $auditsClientId
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Audits-ClientSecret" -SecretValue $auditsClientSecret
                    }
                            
                    if ($lockdownClientId) {
                        # Store Lockdown API credentials
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Lockdown-ClientId" -SecretValue $lockdownClientId
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Lockdown-ClientSecret" -SecretValue $lockdownClientSecret
                    }

                    if ($hostEntityClientId) {
                        # Store Host Entity API credentials
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-HostEntity-ClientId" -SecretValue $hostEntityClientId
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-HostEntity-ClientSecret" -SecretValue $hostEntityClientSecret
                    }
                            
                    if ($accountEntityClientId) {
                        # Store Account Entity API credentials
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-AccountEntity-ClientId" -SecretValue $accountEntityClientId
                        Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-AccountEntity-ClientSecret" -SecretValue $accountEntityClientSecret
                    }

                    Write-Host "`n✅ Finished storing Vectra API credentials in Key Vault" -ForegroundColor Green
                }
                else {
                    Write-Host "⚠️ Could not set access policy automatically - manual configuration required" -ForegroundColor Yellow
                    Write-Host "💡 Go to Key Vault → Access policies → Add access policy after deployment" -ForegroundColor Cyan
                }
            }
            catch {
                Write-Host "⚠️ Could not set access policy: $_" -ForegroundColor Yellow
                Write-Host "💡 You may need to set Key Vault access policy manually" -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "❌ Failed to create Key Vault: $_" -ForegroundColor Red
            Write-Host "⚠️ Continuing with existing Key Vault assumption..." -ForegroundColor Yellow
        }
    }

    # Azure App Registration Details
    Write-Host "`n🔐 Azure App Registration Details"
    do {
        $azureClientId = Read-Host "Enter Azure Client ID from app registration"
    } while ([string]::IsNullOrWhiteSpace($azureClientId))

    do {
        $azureClientSecret = Read-Host "Enter Azure Client Secret from app registration"
    } while ([string]::IsNullOrWhiteSpace($azureClientSecret))

    do {
        $azureTenantId = Read-Host "Enter Azure Tenant ID"
    } while ([string]::IsNullOrWhiteSpace($azureTenantId))

    do {
        $azureEntraObjectId = Read-Host "Enter Azure Entra Object ID"
    } while ([string]::IsNullOrWhiteSpace($azureEntraObjectId))
    

    # Optional Configuration
    $startTime = Read-Host "Enter Start Time for data collection (MM/DD/YYYY HH:MM:SS format, optional)"
    
    do {
        $includeScoreDecrease = Read-Host "Include Entity Scoring when score decreases? (true/false, default: false)"
        if ([string]::IsNullOrWhiteSpace($includeScoreDecrease)) {
            $includeScoreDecrease = "false"
        }
    } while ($includeScoreDecrease -notmatch "^(true|false)$")

    $auditTableName = Read-Host "Enter name of the table used to store Audit logs. (default: Audits_Data)"
    if ([string]::IsNullOrWhiteSpace($auditTableName)) {
        $auditTableName = "Audits_Data"
    }

    $detectionTableName = Read-Host "Enter name of the table used to store Detection logs. (default: Detections_Data)"
    if ([string]::IsNullOrWhiteSpace($detectionTableName)) {
        $detectionTableName = "Detections_Data"
    }

    $entityScoringTableName = Read-Host "Enter name of the table used to store Entity Scoring logs. (default: Entity_Scoring_Data)"
    if ([string]::IsNullOrWhiteSpace($entityScoringTableName)) {
        $entityScoringTableName = "Entity_Scoring_Data"
    }

    $lockdownTableName = Read-Host "Enter name of the table used to store Lockdown logs. (default: Lockdown_Data)"
    if ([string]::IsNullOrWhiteSpace($lockdownTableName)) {
        $lockdownTableName = "Lockdown_Data"
    }

    $healthTableName = Read-Host "Enter name of the table used to store Health logs. (default: Health_Data)"
    if ([string]::IsNullOrWhiteSpace($healthTableName)) {
        $healthTableName = "Health_Data"
    }

    $entitiesTableName = Read-Host "Enter name of the table used to store Entity logs. (default: Entities_Data)"
    if ([string]::IsNullOrWhiteSpace($entitiesTableName)) {
        $entitiesTableName = "Entities_Data"
    }

    do {
        $ExcludeGroupDetailsFromDetections = Read-Host "Select true to exclude group details from detections. (true/false, default: false)"
        if ([string]::IsNullOrWhiteSpace($ExcludeGroupDetailsFromDetections)) {
            $ExcludeGroupDetailsFromDetections = "false"
        }
    } while ($ExcludeGroupDetailsFromDetections -notmatch "^(true|false)$")

    # Log Level
    do {
        $logLevel = Read-Host "Select log level [Debug, Info, Error, Warning] (default: Info)"
        if ([string]::IsNullOrWhiteSpace($logLevel)) {
            $logLevel = "Info"
        }
    } while ($logLevel -notmatch "^(Debug|Info|Error|Warning)$")

    $lockdownSchedule = Read-Host "Enter a valid Quartz Cron-Expression. The default value is every 10 minutes starting from Minute :00 of every hour. (0 0/10 * * * *)"
    if ([string]::IsNullOrWhiteSpace($lockdownSchedule)) {
        $lockdownSchedule = "0 0/10 * * * *"
    }

    # Health API Schedule
    $healthSchedule = Read-Host "Enter a valid Quartz Cron-Expression for Health API. The default value is every 10 minutes starting from Minute :01 of every hour. (0 1/10 * * * *)"
    if ([string]::IsNullOrWhiteSpace($healthSchedule)) {
        $healthSchedule = "0 1/10 * * * *"
    }

    # Detections API Schedule
    $detectionsSchedule = Read-Host "Enter a valid Quartz Cron-Expression for Detections API. The default value is every 10 minutes starting from Minute :02 of every hour. (0 2/10 * * * *)"
    if ([string]::IsNullOrWhiteSpace($detectionsSchedule)) {
        $detectionsSchedule = "0 2/10 * * * *"
    }

    # Audits API Schedule
    $auditsSchedule = Read-Host "Enter a valid Quartz Cron-Expression for Audits API. The default value is every 10 minutes starting from Minute :05 of every hour. (0 5/10 * * * *)"
    if ([string]::IsNullOrWhiteSpace($auditsSchedule)) {
        $auditsSchedule = "0 5/10 * * * *"
    }

    # Entity Scoring API Schedule
    $entityScoringSchedule = Read-Host "Enter a valid Quartz Cron-Expression for Entity Scoring API. The default value is every 10 minutes starting from Minute :08 of every hour (0 8/10 * * * *)"
    if ([string]::IsNullOrWhiteSpace($entityScoringSchedule)) {
        $entityScoringSchedule = "0 8/10 * * * *"
    }

    # Entities API Schedule (for both Host and Account entities)
    $entitiesSchedule = Read-Host "Enter a valid Quartz Cron-Expression. The default value is every 10 minutes starting from Minute :09 of every hour. (0 9/10 * * * *)"
    if ([string]::IsNullOrWhiteSpace($entitiesSchedule)) {
        $entitiesSchedule = "0 9/10 * * * *"
    }


    #$connectorGithubUrl = "https://raw.githubusercontent.com/Azure/Azure-Sentinel/refs/heads/master/Solutions/Vectra%20XDR/Data%20Connectors/VectraDataConnector/azuredeploy_Connector_VectraXDR_AzureFunction.json"
    $connectorGithubUrl = "https://raw.githubusercontent.com/fenil-savani/Data-Connectors/refs/heads/main/azuredeploy_Connector_VectraXDR_AzureFunction.json"
    $tempConnectorPath = "$HOME/connector_template.json"
    
    Write-Host "`n📥 Downloading Data Connector ARM template..."
    try {
        Invoke-WebRequest -Uri $connectorGithubUrl -OutFile $tempConnectorPath -UseBasicParsing
        Write-Host "✅ Data Connector template downloaded successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to download connector template: $_" -ForegroundColor Red
        Write-Host "⚠️ Continuing to next deployment..." -ForegroundColor Yellow
        $deployConnector = "failed"
    }

    if ($deployConnector -ne "failed") {
        try {
            $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroup -Name $workspaceName

            # Get App Insights Resource ID
            Write-Host "🔍 Retrieving App Insights resource ID..."
            $appInsightsId = $workspace.ResourceId
            Write-Host "✅ App Insights Resource ID: $appInsightsId" -ForegroundColor Green
            
            Write-Host "✅ Workspace details retrieved successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to retrieve workspace details: $_" -ForegroundColor Red
            $deployConnector = "failed"
        }
    }

    if ($deployConnector -ne "failed") {
        # Build Data Connector Parameters
        $connectorParameters = @{
            "FunctionName"                           = $functionAppName
            "WorkspaceName"                          = $workspaceName
            "VectraBaseURL"                          = $vectraBaseUrl
            "VectraClientId - Health"                = $healthClientId
            "VectraClientSecretKey - Health"         = $healthClientSecret
            "VectraClientId - Entity Scoring"        = $entityScoringClientId
            "VectraClientSecretKey - Entity Scoring" = $entityScoringClientSecret
            "VectraClientId - Detections"            = $detectionsClientId
            "VectraClientSecretKey - Detections"     = $detectionsClientSecret
            "VectraClientId - Audits"                = $auditsClientId
            "VectraClientSecretKey - Audits"         = $auditsClientSecret
            "VectraClientId - Lockdown"              = $lockdownClientId
            "VectraClientSecretKey - Lockdown"       = $lockdownClientSecret
            "VectraClientId - Host-Entity"           = $hostEntityClientId
            "VectraClientSecretKey - Host-Entity"    = $hostEntityClientSecret
            "VectraClientId - Account-Entity"        = $accountEntityClientId
            "VectraClientSecretKey - Account-Entity" = $accountEntityClientSecret
            "KeyVaultName"                           = $keyVaultName
            "AzureClientID"                          = $azureClientId
            "AzureClientSecret"                      = $azureClientSecret
            "TenantID"                               = $azureTenantId
            "StartTime"                              = $startTime
            "IncludeScoreDecrease"                   = [bool]::Parse($includeScoreDecrease)
            "AuditsTableName"                        = $auditTableName
            "DetectionsTableName"                    = $detectionTableName
            "EntityScoringTableName"                 = $entityScoringTableName
            "LockdownTableName"                      = $lockdownTableName
            "HealthTableName"                        = $healthTableName            
            "EntitiesTableName"                      = $entitiesTableName
            "ExcludeGroupDetailsFromDetections"      = [bool]::Parse($ExcludeGroupDetailsFromDetections)
            "LogLevel"                               = $logLevel
            "LockdownSchedule"                       = $lockdownSchedule
            "HealthSchedule"                         = $healthSchedule
            "DetectionsSchedule"                     = $detectionsSchedule
            "AuditsSchedule"                         = $auditsSchedule
            "EntityScoringSchedule"                  = $entityScoringSchedule
            "EntitiesSchedule"                       = $entitiesSchedule
            "AzureEntraObjectID"                     = $azureEntraObjectId
            "AppInsightsWorkspaceResourceID"         = $appInsightsId
        }

        # Deploy Data Connector
        $connectorDeploymentName = "VectraXDR_DataConnector_" + (Get-Date -Format "yyyyMMddHHmmss")
        Write-Host "`n🚀 Initiating Vectra XDR Data Connector deployment '$connectorDeploymentName'..."

        try {
            $startTime = Get-Date

            # Deploy the function app
            $deploymentResult = New-AzResourceGroupDeployment `
                -Name $connectorDeploymentName `
                -ResourceGroupName $resourceGroup `
                -TemplateFile $tempConnectorPath `
                -TemplateParameterObject $connectorParameters `
                -Verbose
            
            if ($deploymentResult.ProvisioningState -eq "Succeeded") {
                Write-Host "`n✅ Vectra XDR Data Connector deployment completed successfully!" -ForegroundColor Green
                # Wait a moment for Azure to complete the registration
                Start-Sleep -Seconds 10
            }
            else {
                Write-Host "`n❌ Vectra XDR Data Connector deployment failed." -ForegroundColor Red
                Write-Host "⚠️ Continuing to playbook deployment..." -ForegroundColor Yellow
                $deployConnector = "failed"
            }
        }
        catch {
            Write-Host "`n❌ Vectra XDR Data Connector deployment failed: $_" -ForegroundColor Red
            Write-Host "⚠️ Continuing to playbook deployment..." -ForegroundColor Yellow
            $deployConnector = "failed"
        }
    }
}
else {
    Write-Host "`n⏭️ Vectra XDR Data Connector deployment skipped." -ForegroundColor Yellow
}

# ============================================================================
# Create keyvault access to function app
# ============================================================================

if ($deployConnector -match "^(yes|y)$" -and $deployConnector -ne "failed" -and $createKeyVault -match "^(yes|y)$") {
    try {
        $functionAppPrefix = $functionAppName
        $functionApps = Get-AzFunctionApp -ResourceGroupName $resourceGroup -WarningAction SilentlyContinue | 
        Where-Object { $_.Name -like "$functionAppPrefix*" }

        if ($functionApps -and $functionApps.Count -gt 0) {    
            # Use the most recently created one
            $functionApp = $functionApps | Sort-Object -Property CreatedTime -Descending | Select-Object -First 1
            $functionAppName = $functionApp.Name
            Write-Host "`nCreated function app: $functionAppName" -ForegroundColor Cyan
            if ($functionApp.IdentityType -eq "SystemAssigned" -or $functionApp.IdentityType -eq "SystemAssigned, UserAssigned") {
                # Get the function app's managed identity object ID
                $functionAppObjectId = $functionApp.IdentityPrincipalId
            
                if ($functionAppObjectId) {                
                    # Set Key Vault access policy for the function app
                    Write-Host "`n🔐 Setting Key Vault access policy for Function App..." -ForegroundColor Yellow
                
                    Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName `
                        -ObjectId $functionAppObjectId `
                        -PermissionsToSecrets @('Get', 'List', 'Set', 'Delete') `
                        -PermissionsToKeys @('Get', 'List', 'Update', 'Create')
                
                    Write-Host "✅ Key Vault access policy set for Function App: $functionAppName" -ForegroundColor Green
                }
                else {
                    Write-Host "❌ Could not retrieve Managed Identity Object ID for Function App: $functionAppName" -ForegroundColor Red
                    Write-Host "`n📝 Follow manual steps to enable system-assigned managed identity and set Key Vault access mentioned last under deployment summary." -ForegroundColor Yellow
                }
            }
            else {
                # If managed identity is not enabled, enable it
                Write-Host "⚠️ System-assigned managed identity is not enabled for Function App: $functionAppName" -ForegroundColor Yellow
                Write-Host "🔄 Enabling system-assigned managed identity..." -ForegroundColor Yellow
            
                # Enable system-assigned managed identity
                $functionApp = Update-AzFunctionApp -Name $functionAppName -ResourceGroupName $resourceGroup -IdentityType SystemAssigned
            
                # Get the function app's managed identity object ID after enabling it
                $functionAppObjectId = $functionApp.IdentityPrincipalId
            
                if ($functionAppObjectId) {
                    Write-Host "✅ Enabled system-assigned managed identity for Function App: $functionAppName" -ForegroundColor Green
                    Write-Host "✅ Managed Identity Object ID: $functionAppObjectId" -ForegroundColor Green
                
                    # Set Key Vault access policy for the function app
                    Write-Host "`n🔐 Setting Key Vault access policy for Function App..." -ForegroundColor Yellow
                
                    Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName `
                        -ObjectId $functionAppObjectId `
                        -PermissionsToSecrets @('Get', 'List', 'Set', 'Delete') `
                        -PermissionsToKeys @('Get', 'List', 'Update', 'Create')
                
                    Write-Host "✅ Key Vault access policy set for Function App: $functionAppName" -ForegroundColor Green
                }
                else {
                    Write-Host "❌ Failed to enable system-assigned managed identity for Function App: $functionAppName" -ForegroundColor Red
                    Write-Host "`n📝 Follow manual steps to enable system-assigned managed identity and set Key Vault access mentioned last under deployment summary." -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Host "No function apps found with prefix '$functionAppPrefix'" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error setting Key Vault access policy for Function App: $_" -ForegroundColor Red
        Write-Host "⚠️ You may need to set Key Vault access policy manually" -ForegroundColor Yellow
        Write-Host "💡 Go to Key Vault → Access policies → Add access policy after deployment" -ForegroundColor Cyan
    }
}


# ============================================================================
# PART 3: PLAYBOOK DEPLOYMENT
# ============================================================================
Write-Host "`n"
Write-Host "PART 3: VECTRA XDR PLAYBOOKS DEPLOYMENT" -ForegroundColor Magenta

do {
    $deployPlaybooks = Read-Host "`nDo you want to deploy Vectra XDR Playbooks? (yes/no)"
    $deployPlaybooks = $deployPlaybooks.ToLower()
} while ($deployPlaybooks -notmatch "^(yes|y|no|n)$")

if ($deployPlaybooks -match "^(yes|y)$") {
    Write-Host "`n📝 Vectra XDR Playbooks Configuration" -ForegroundColor Yellow

    # Available Playbooks
    $availablePlaybooks = @(
        "VectraGenerateAccessToken",
        "VectraAddNoteToEntity",
        "VectraAddTagToEntity",
        "VectraAddTagToEntityAllDetections",
        "VectraAddTagToEntitySelectedDetections",
        "VectraAssignDynamicUserToEntity",
        "VectraAssignStaticUserToEntity",
        "VectraDecorateIncidentBasedOnTag",
        "VectraDecorateIncidentBasedOnTagAndNotify",
        "VectraDynamicAssignMembersToGroup",
        "VectraDynamicResolveAssignment",
        "VectraIncidentTimelineUpdate",
        "VectraMarkDetectionsAsFixed",
        "VectraOperateOnEntitySourceIP",
        "VectraStaticAssignMembersToGroup",
        "VectraStaticResolveAssignment",
        "VectraUpdateIncidentBasedOnTagAndNotify",
        "VectraCloseDetections",
        "VectraOpenClosedDetections",
        "VectaDownloadPcapFileToStorage"
    )

    Write-Host "`n📋 Available Vectra XDR Playbooks:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $availablePlaybooks.Count; $i++) {
        Write-Host "  $($i + 1). $($availablePlaybooks[$i])" -ForegroundColor White
    }

    Write-Host "`n💡 IMPORTANT: VectraGenerateAccessToken Playbook" -ForegroundColor Yellow
    Write-Host "• This playbook generates access tokens for other Vectra playbooks" -ForegroundColor White
    Write-Host "• Ensure it's properly configured before using other playbooks" -ForegroundColor White

    # Playbook Selection
    do {
        $playbookSelection = Read-Host "`nSelect playbooks to deploy:`n1. Deploy all playbooks`n2. Select specific playbooks`nEnter your choice (1 or 2)"
    } while ($playbookSelection -notmatch "^[1-2]$")

    $selectedPlaybooks = @()
    switch ($playbookSelection) {
        "1" { 
            $selectedPlaybooks = $availablePlaybooks
            Write-Host "✅ Selected all playbooks for deployment" -ForegroundColor Green
        }
        "2" {
            Write-Host "`nEnter playbook numbers separated by commas (e.g., 1,3,5):"
            $playbookNumbers = Read-Host "Playbook numbers"
            $numbers = $playbookNumbers -split "," | ForEach-Object { $_.Trim() }
            foreach ($num in $numbers) {
                if ($num -match "^\d+$" -and [int]$num -ge 1 -and [int]$num -le $availablePlaybooks.Count) {
                    $selectedPlaybooks += $availablePlaybooks[[int]$num - 1]
                }
            }
            Write-Host "✅ Selected $($selectedPlaybooks.Count) playbooks for deployment" -ForegroundColor Green
        }
    }

    if ($selectedPlaybooks.Count -eq 0) {
        Write-Host "❌ No valid playbooks selected. Skipping playbook deployment." -ForegroundColor Red
        $deployPlaybooks = "failed"
    }

    if ($deployPlaybooks -ne "failed") {
        # Common Playbook Configuration
        $useExistingKeyVault = "no"
        if ($keyVaultName) {
            do {
                $useExistingKeyVault = Read-Host "Use existing Key Vault ($keyVaultName) for playbooks? (yes/no)"
                $useExistingKeyVault = $useExistingKeyVault.ToLower()
            } while ($useExistingKeyVault -notmatch "^(yes|y|no|n)$")
        } 

        if ($useExistingKeyVault -match "^(no|n)$") {
            do {
                $createKeyVaultforplaybook = Read-Host "Do you want to create a new Key Vault for storing Vectra credentials? (yes/no)"
                $createKeyVaultforplaybook = $createKeyVaultforplaybook.ToLower()
            } while ($createKeyVaultforplaybook -notmatch "^(yes|y|no|n)$")

            if ($createKeyVaultforplaybook -match "^(yes|y)$") {
                $keyVaultName = Read-Host "Enter Key Vault Name"
                Write-Host "📦 Creating Key Vault: $keyVaultName..."
                try {
                    # Create Key Vault with access policy model (not RBAC)
                    $keyVault = New-AzKeyVault `
                        -Name $keyVaultName `
                        -ResourceGroupName $resourceGroup `
                        -Location $workspaceLocation `
                        -EnabledForTemplateDeployment `
                        -DisableRbacAuthorization
                
                    Write-Host "✅ Key Vault created successfully with Vault Access Policy model" -ForegroundColor Green
                    # Set access policy for current user after creation
                    try {
                        # Instead of getting current user's Object ID, get the Application's Object ID
                        $currentUser = Get-AzContext
                        $currentUserUPN = $currentUser.Account.Id
                    
                        # Try to get current user's object ID
                        try {
                            $azAccount = az account show --query user.name -o tsv 2>$null
                            if ($azAccount) {
                                $objectIdResult = az ad user show --id $azAccount --query id -o tsv 2>$null
                                if ($objectIdResult) {
                                    $currentUserObjectId = $objectIdResult
                                    Write-Host "✅ Got Object ID using Azure CLI: $currentUserObjectId" -ForegroundColor Green
                                }
                            }
                        }
                        catch {
                            Write-Host "⚠️ Azure CLI method failed: $_" -ForegroundColor Yellow
                        }
                        if ($currentUserObjectId) {
                            # Set access policy for the application instead of current user
                            Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $currentUserObjectId -PermissionsToKeys @('Get', 'List', 'Update', 'Create', 'Import', 'Delete', 'Recover', 'Backup', 'Restore') -PermissionsToSecrets @('Get', 'List', 'Set', 'Delete', 'Recover', 'Backup', 'Restore')
                            Write-Host "✅ Access policy set for current user" -ForegroundColor Green
                        
                            # Wait for access policy to propagate
                            Write-Host "⏳ Waiting for access policy to propagate..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 10
                            Write-Host "`n🔐 Storing Vectra API credentials in Key Vault..." -ForegroundColor Magenta

                            # Helper function to create a secret with error handling
                            function Set-KeyVaultSecretWithCheck {
                                param (
                                    [string]$VaultName,
                                    [string]$SecretName,
                                    [string]$SecretValue,
                                    [switch]$AsSecureString
                                )
    
                                if ([string]::IsNullOrWhiteSpace($SecretValue)) {
                                    Write-Host "ℹ️ Skipping empty secret: $SecretName" -ForegroundColor Cyan
                                    return
                                }
    
                                try {
                                    $secValue = ConvertTo-SecureString $SecretValue -AsPlainText -Force
                                    $result = Set-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -SecretValue $secValue
        
                                    if ($result) {
                                        Write-Host "✅ Created secret: $SecretName" -ForegroundColor Green
                                    }
                                    else {
                                        Write-Host "❌ Failed to create secret: $SecretName" -ForegroundColor Red
                                    }
                                }
                                catch {
                                    Write-Host "❌ Error creating secret $SecretName $_" -ForegroundColor Red
                                }
                            }

                            do {
                                $createHealthAPIcredentials = Read-Host "Do you want to create Health API credentials? (yes/no)"
                                $createHealthAPIcredentials = $createHealthAPIcredentials.ToLower()
                            } while ($createHealthAPIcredentials -notmatch "^(yes|y|no|n)$")

                            if ($createHealthAPIcredentials -match "^(yes|y)$") {
                            
                                $healthClientId = Read-Host "Enter Health API Client ID"
                                $healthClientSecret = Read-Host "Enter Health API Client Secret"
                                # Store Health API credentials
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Health-ClientId" -SecretValue $healthClientId
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Health-ClientSecret" -SecretValue $healthClientSecret
                            }
                         
                            do {
                                $createEntityScoringAPIcredentials = Read-Host "Do you want to create Entity Scoring API credentials? (yes/no)"
                                $createEntityScoringAPIcredentials = $createEntityScoringAPIcredentials.ToLower()
                            } while ($createEntityScoringAPIcredentials -notmatch "^(yes|y|no|n)$")

                            if ($createEntityScoringAPIcredentials -match "^(yes|y)$") {
                            
                                $entityScoringClientId = Read-Host "Enter Entity Scoring API Client ID" 
                                $entityScoringClientSecret = Read-Host "Enter Entity Scoring API Client Secret"
                                # Store Entity Scoring API credentials
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-EntityScoring-ClientId" -SecretValue $entityScoringClientId
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-EntityScoring-ClientSecret" -SecretValue $entityScoringClientSecret
                            }

                            do {
                                $createDetectionsAPIcredentials = Read-Host "Do you want to create Detections API credentials? (yes/no)"
                                $createDetectionsAPIcredentials = $createDetectionsAPIcredentials.ToLower()
                            } while ($createDetectionsAPIcredentials -notmatch "^(yes|y|no|n)$")

                            if ($createDetectionsAPIcredentials -match "^(yes|y)$") {
                            
                                $detectionsClientId = Read-Host "Enter Detections API Client ID"
                                $detectionsClientSecret = Read-Host "Enter Detections API Client Secret"
                                # Store Detections API credentials
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Detections-ClientId" -SecretValue $detectionsClientId
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Detections-ClientSecret" -SecretValue $detectionsClientSecret
                            }

                            do {
                                $createAuditsAPIcredentials = Read-Host "Do you want to create Audits API credentials? (yes/no)"
                                $createAuditsAPIcredentials = $createAuditsAPIcredentials.ToLower()
                            } while ($createAuditsAPIcredentials -notmatch "^(yes|y|no|n)$")

                            if ($createAuditsAPIcredentials -match "^(yes|y)$") {
                            
                                $auditsClientId = Read-Host "Enter Audits API Client ID"
                                $auditsClientSecret = Read-Host "Enter Audits API Client Secret"
                                # Store Audits API credentials
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Audits-ClientId" -SecretValue $auditsClientId
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Audits-ClientSecret" -SecretValue $auditsClientSecret
                            }

                            do {
                                $createLockdownAPIcredentials = Read-Host "Do you want to create Lockdown API credentials? (yes/no)"
                                $createLockdownAPIcredentials = $createLockdownAPIcredentials.ToLower()
                            } while ($createLockdownAPIcredentials -notmatch "^(yes|y|no|n)$")

                            if ($createLockdownAPIcredentials -match "^(yes|y)$") {
                            
                                $lockdownClientId = Read-Host "Enter Lockdown API Client ID"
                                $lockdownClientSecret = Read-Host "Enter Lockdown API Client Secret"

                                # Store Lockdown API credentials
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Lockdown-ClientId" -SecretValue $lockdownClientId
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-Lockdown-ClientSecret" -SecretValue $lockdownClientSecret
                            }

                            do {
                                $createHostEntityAPIcredentials = Read-Host "Do you want to create Host Entity API credentials? (yes/no)"
                                $createHostEntityAPIcredentials = $createHostEntityAPIcredentials.ToLower()
                            } while ($createHostEntityAPIcredentials -notmatch "^(yes|y|no|n)$")

                            if ($createHostEntityAPIcredentials -match "^(yes|y)$") {
                            
                                $hostEntityClientId = Read-Host "Enter Host Entity API Client ID"
                                $hostEntityClientSecret = Read-Host "Enter Host Entity API Client Secret"

                                # Store Host Entity API credentials
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-HostEntity-ClientId" -SecretValue $hostEntityClientId
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-HostEntity-ClientSecret" -SecretValue $hostEntityClientSecret
                            }

                            do {
                                $createAccountEntityAPIcredentials = Read-Host "Do you want to create Account Entity API credentials? (yes/no)"
                                $createAccountEntityAPIcredentials = $createAccountEntityAPIcredentials.ToLower()
                            } while ($createAccountEntityAPIcredentials -notmatch "^(yes|y|no|n)$")
                            
                            if ($createAccountEntityAPIcredentials -match "^(yes|y)$") {
                            
                                $accountEntityClientId = Read-Host "Enter Account Entity API Client ID"
                                $accountEntityClientSecret = Read-Host "Enter Account Entity API Client Secret"
                                # Store Account Entity API credentials
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-AccountEntity-ClientId" -SecretValue $accountEntityClientId
                                Set-KeyVaultSecretWithCheck -VaultName $keyVaultName -SecretName "Vectra-AccountEntity-ClientSecret" -SecretValue $accountEntityClientSecret
                            }

                            Write-Host "`n✅ Finished storing Vectra API credentials in Key Vault" -ForegroundColor Green
                        }
                        else {
                            Write-Host "⚠️ Could not set access policy automatically - manual configuration required" -ForegroundColor Yellow
                            Write-Host "💡 Go to Key Vault → Access policies → Add access policy after deployment" -ForegroundColor Cyan
                        }
                    }
                    catch {
                        Write-Host "⚠️ Could not set access policy: $_" -ForegroundColor Yellow
                        Write-Host "💡 You may need to set Key Vault access policy manually" -ForegroundColor Cyan
                    }
                }
                catch {
                    Write-Host "❌ Failed to create Key Vault: $_" -ForegroundColor Red
                    Write-Host "⚠️ Continuing with existing Key Vault assumption..." -ForegroundColor Yellow
                }
            }
            else {
                $keyVaultName = Read-Host "Enter existing Key Vault Name"
                Write-Host "Make sure keyvault has required Client IDs and Secrets stored in it"
            }
        }
        else {
            Write-Host "`n📦 Make sure keyvault has required Client IDs and Secrets stored in it." -ForegroundColor Yellow
        }
        if (-not $azureTenantId) {
            $azureTenantId = Read-Host "Enter Azure Tenant ID"
        }

        if (-not $vectraBaseUrl) {
            do {
                $vectraBaseUrl = Read-Host "Enter Vectra Base URL starting with 'https://' (Example: https://your-vectra-instance.portal.vectra.ai)"
                if ($vectraBaseUrl -notmatch '^https://') {
                    Write-Host "❌ URL must start with https://" -ForegroundColor Red
                }
            } until ($vectraBaseUrl -match '^https://')
            $vectraBaseUrl = $vectraBaseUrl.TrimEnd('/')
        }

        # Teams Configuration (for playbooks that require it)
        $teamsPlaybooks = @("VectraAssignDynamicUserToEntity", "VectraDynamicResolveAssignment", "VectraAddNoteToEntity", "VectraAddTagToEntityAllDetections", "VectraDynamicAssignMembersToGroup", "VectraStaticAssignMembersToGroup", "VectraStaticResolveAssignment", "VectraAddTagToEntitySelectedDetections", "VectraUpdateIncidentBasedOnTagAndNotify", "VectraDecorateIncidentBasedOnTagAndNotify", "VectraAddTagToEntity", "VectraCloseDetections", "VectraOpenClosedDetections", "VectaDownloadPcapFileToStorage")
        $needsTeamsConfig = $false
        foreach ($playbook in $selectedPlaybooks) {
            if ($teamsPlaybooks -contains $playbook) {
                $needsTeamsConfig = $true
                break
            }
        }

        if ($needsTeamsConfig) {
            Write-Host "`n📢 Teams Configuration (required for some playbooks)" -ForegroundColor Yellow
            do {
                $teamsGroupId = Read-Host "Enter Teams Group ID"
            } while ([string]::IsNullOrWhiteSpace($teamsGroupId))

            do {
                $teamsChannelId = Read-Host "Enter Teams Channel ID"
            } while ([string]::IsNullOrWhiteSpace($teamsChannelId))
        }

        # Deploy Selected Playbooks
        Write-Host "`n🚀 Starting Playbook Deployments..." -ForegroundColor Magenta
        $GenerateAccessCredPlaybookName = ""
        $successfulDeployments = @()
        $failedDeployments = @()

        foreach ($oldplaybookName in $selectedPlaybooks) {
            $playbookName = Read-Host "Enter Playbook Name (Default: $oldplaybookName)"
            if ([string]::IsNullOrWhiteSpace($playbookName)) {
                $playbookName = $oldplaybookName
            }
            $playbookParameters = @{
                "PlaybookName" = $playbookName
                "KeyVaultName" = $keyVaultName
                "TenantId"     = $azureTenantId
                "BaseURL"      = $vectraBaseUrl
            }
            Write-Host "`n📦 Deploying $playbookName..." -ForegroundColor Yellow
            
            #$playbookGithubUrl = "https://raw.githubusercontent.com/Azure/Azure-Sentinel/refs/heads/master/Solutions/Vectra%20XDR/Playbooks/$playbookName/azuredeploy.json"
            if ($oldplaybookName -eq "VectraCloseDetections" -or $oldplaybookName -eq "VectraOpenClosedDetections" -or $oldplaybookName -eq "VectaDownloadPcapFileToStorage" -or $oldplaybookName -eq "VectraIncidentTimelineUpdate") {
                $playbookGithubUrl = "https://raw.githubusercontent.com/fenil-savani/Data-Connectors/refs/heads/main/playbook/$oldplaybookName/azuredeploy.json"
            }
            else {
                $playbookGithubUrl = "https://raw.githubusercontent.com/Azure/Azure-Sentinel/refs/heads/master/Solutions/Vectra%20XDR/Playbooks/$oldplaybookName/azuredeploy.json"
            }
            $tempPlaybookPath = "$HOME/playbook_template.json"

            Write-Host "`n📥 Downloading $playbookName Playbook ARM template..."
            try {
                Invoke-WebRequest -Uri $playbookGithubUrl -OutFile $tempPlaybookPath -UseBasicParsing
                Write-Host "✅ Playbook template downloaded successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "❌ Failed to download playbook template: $_" -ForegroundColor Red
                Write-Host "⚠️ Skipping playbook deployment..." -ForegroundColor Yellow
                $deployPlaybook = "failed"
            }

            if ($deployPlaybook -ne "failed") {

                if ($oldplaybookName -eq "GenerateAccessCredPlaybookName") {
                    $azureKeyvault = Read-Host "Enter value for azure key vault. (Default: vault.azure)"
                    if ([string]::IsNullOrWhiteSpace($azureKeyvault)) {
                        $azureKeyvault = "vault.azure"
                    }
                    $playbookParameters["azure key vault"] = $azureKeyvault
                }

                if ($oldplaybookName -eq "VectraAssignStaticUserToEntity") {
                    $userId = Read-Host "Enter a user id which will be assign to entity"
                    $playbookParameters["UserId"] = $userId
                }
               
                if ($oldplaybookName -eq "VectraMarkDetectionsAsFixed") {
                    $incidentComment = Read-Host "Enter comment you want to add in incident. (Default: Active Detections associated with an Entity has been fixed successfully.)"
                    if ([string]::IsNullOrWhiteSpace($incidentComment)) {
                        $incidentComment = "Active Detections associated with an Entity has been fixed successfully."
                    }
                    $entityNote = Read-Host "Enter a note you want to add in Vectra Entity. (Default: Active Detections associated with an Entity has been fixed successfully.)"
                    if ([string]::IsNullOrWhiteSpace($entityNote)) {
                        $entityNote = "Active Detections associated with an Entity has been fixed successfully."
                    }
                    $playbookParameters["IncidentComment"] = $incidentComment
                    $playbookParameters["EntityNote"] = $entityNote
                }

                if ($oldplaybookName -eq "VectraStaticResolveAssignment") {
                    $entityNote = Read-Host "Enter a note you want to add in Vectra Entity for assignment. (Default: Assignment has been resolved.)"
                    if ([string]::IsNullOrWhiteSpace($entityNote)) {
                        $entityNote = "Assignment has been resolved."
                    }
                    $playbookParameters["EntityNote"] = $entityNote
                }

                if ($oldplaybookName -eq "VectraDecorateIncidentBasedOnTag" -or $oldplaybookName -eq "VectraDecorateIncidentBasedOnTagAndNotify" -or $oldplaybookName -eq "VectraMarkDetectionsAsFixed") {
                    $incidentComment = Read-Host "Enter comment you want to add in incident create based on tag. NOTE: Entity id, type and tag will be added by default for incident comment. (Default: Incident has been created and escalated.)"
                    if ([string]::IsNullOrWhiteSpace($incidentComment)) {
                        $incidentComment = "Incident has been created and escalated."
                    }
                    $entityNote = Read-Host "Enter a note you want to add in Vectra Entity. NOTE: Incident link will be added by default to note. (Default: Incident is being tracked in Sentinel with link:)"
                    if ([string]::IsNullOrWhiteSpace($entityNote)) {
                        $entityNote = "Incident is being tracked in Sentinel with link:"
                    }
                    $playbookParameters["IncidentComment"] = $incidentComment
                    $playbookParameters["EntityNote"] = $entityNote
                }

                if ($oldplaybookName -eq "VectraUpdateIncidentBasedOnTagAndNotify") {
                    $tag = Read-Host "Enter Tag value based on which incident will be updated(Default: MDR - Customer Escalation)"
                    if ([string]::IsNullOrWhiteSpace($tag)) {
                        $tag = "MDR - Customer Escalation"
                    }
                    $incidentComment = Read-Host "Enter comment you want to add in incident which will be updated based on tag. (Default: Incident has been updated with High Severity.)"
                    if ([string]::IsNullOrWhiteSpace($incidentComment)) {
                        $incidentComment = "Incident has been updated with High Severity."
                    }
                    $workspacename_ = Read-Host "Enter workspace name(Default: $workspaceName)"
                    if ([string]::IsNullOrWhiteSpace($workspacename_)) {
                        $workspacename_ = $workspaceName
                    }
                    $playbookParameters["Tag"] = $tag
                    $playbookParameters["IncidentComment"] = $incidentComment
                    $playbookParameters["Workspacename"] = $workspacename_
                }

                # Add Teams parameters if needed
                if ($teamsPlaybooks -contains $oldplaybookName -and $teamsGroupId -and $teamsChannelId) {
                    $playbookParameters["TeamsGroupId"] = $teamsGroupId
                    $playbookParameters["TeamsChannelId"] = $teamsChannelId
                }

                if ($oldplaybookName -ne "VectraIncidentTimelineUpdate" -and $oldplaybookName -ne "VectraGenerateAccessToken") {
                    if ([string]::IsNullOrWhiteSpace($GenerateAccessCredPlaybookName)) {
                        do {
                            $GenerateAccessCredPlaybookName = Read-Host "Enter playbook name to generate access credential. (e.g. VectraGenerateAccessToken)"
                        } while ([string]::IsNullOrWhiteSpace($GenerateAccessCredPlaybookName))
                    }
                    $playbookParameters["GenerateAccessCredPlaybookName"] = $GenerateAccessCredPlaybookName
                }

                if ($oldplaybookName -eq "VectraIncidentTimelineUpdate") {
                    $workspacename_ = Read-Host "Enter workspace name(Default: $workspaceName)"
                    if ([string]::IsNullOrWhiteSpace($workspacename_)) {
                        $workspacename_ = $workspaceName
                    }
                    $playbookParameters = @{
                        "PlaybookName"  = $playbookName
                        "WorkSpaceName" = $workspacename_
                    }
                }

                try {
                    $playbookDeploymentName = "VectraXDR_$playbookName" + "_" + (Get-Date -Format "yyyyMMddHHmmss")
                    $playbookDeploymentName = $playbookDeploymentName.SubString(0, [Math]::Min(64, $playbookDeploymentName.Length))
                
                    $deploymentResult = New-AzResourceGroupDeployment `
                        -Name $playbookDeploymentName `
                        -ResourceGroupName $resourceGroup `
                        -TemplateFile $tempPlaybookPath `
                        -TemplateParameterObject $playbookParameters `
                        -Verbose

                    if ($deploymentResult.ProvisioningState -eq "Succeeded") {
                        Write-Host "✅ $playbookName deployed successfully!" -ForegroundColor Green
                        $successfulDeployments += $playbookName
                    }
                    else {
                        Write-Host "❌ $playbookName deployment failed." -ForegroundColor Red
                        $failedDeployments += $playbookName
                    }
                
                }
                catch {
                    Write-Host "❌ $playbookName deployment failed: $_" -ForegroundColor Red
                    $failedDeployments += $playbookName
                }
            }
        }

        # Deployment Summary for Playbooks
        Write-Host "`n📊 Playbook Deployment Summary:" -ForegroundColor Cyan
        Write-Host "✅ Successful deployments: $($successfulDeployments.Count)" -ForegroundColor Green
        foreach ($success in $successfulDeployments) {
            Write-Host "  - $success" -ForegroundColor Green
        }
        
        if ($failedDeployments.Count -gt 0) {
            Write-Host "❌ Failed deployments: $($failedDeployments.Count)" -ForegroundColor Red
            foreach ($failed in $failedDeployments) {
                Write-Host "  - $failed" -ForegroundColor Red
            }
        }
    }
}
else {
    Write-Host "`n⏭️ Vectra XDR Playbooks deployment skipped." -ForegroundColor Yellow
}


# ============================================================================
# AUTOMATED ROLE ASSIGNMENT FOR LOGIC APPS
# ============================================================================

if ($deployPlaybooks -match "^(yes|y)$" -and $successfulDeployments.Count -gt 0) {
    Write-Host "`n🔐 Automating Microsoft Sentinel Role Assignment for Playbooks..." -ForegroundColor Magenta

    foreach ($playbookName in $successfulDeployments) {
        Write-Host "`n🔧 Processing role assignment for $playbookName..." -ForegroundColor Yellow
        
        try {
            # Get the Logic App's 
            
            #managed identity
            $logicApp = Get-AzLogicApp -ResourceGroupName $resourceGroup -Name $playbookName -ErrorAction SilentlyContinue
            
            if ($logicApp) {
                # Get the Logic App's system-assigned managed identity
                $logicAppResource = Get-AzResource -ResourceGroupName $resourceGroup -Name $playbookName -ResourceType "Microsoft.Logic/workflows"
                
                if ($logicAppResource.Identity -and $logicAppResource.Identity.PrincipalId) {
                    $managedIdentityObjectId = $logicAppResource.Identity.PrincipalId
                    Write-Host "✅ Logic App managed identity found: $managedIdentityObjectId" -ForegroundColor Green
                    
                    # Get the Log Analytics workspace resource ID for scope
                    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroup -Name $workspaceName
                    $workspaceResourceId = $workspace.ResourceId
                    
                    # Check if role assignment already exists
                    $existingAssignment = Get-AzRoleAssignment -ObjectId $managedIdentityObjectId -RoleDefinitionName "Microsoft Sentinel Contributor" -Scope $workspaceResourceId -ErrorAction SilentlyContinue
                    
                    if ($existingAssignment) {
                        Write-Host "✅ Microsoft Sentinel Contributor role already assigned for $playbookName" -ForegroundColor Green
                    }
                    else {
                        Write-Host "🔧 Assigning Microsoft Sentinel Contributor role for $playbookName..." -ForegroundColor Yellow
                        
                        # Assign the Microsoft Sentinel Contributor role
                        $roleAssignment = New-AzRoleAssignment -ObjectId $managedIdentityObjectId -RoleDefinitionName "Microsoft Sentinel Contributor" -Scope $workspaceResourceId -ErrorAction SilentlyContinue
                        
                        if ($roleAssignment) {
                            Write-Host "✅ Microsoft Sentinel Contributor role assigned successfully for $playbookName" -ForegroundColor Green
                        }
                        else {
                            Write-Host "❌ Failed to assign role for $playbookName" -ForegroundColor Red
                        }
                    }
                    
                }
                else {
                    Write-Host "❌ Logic App managed identity not found for $playbookName" -ForegroundColor Red
                }
                
            }
            else {
                Write-Host "❌ Logic App not found: $playbookName" -ForegroundColor Red
            }
            
        }
        catch {
            Write-Host "❌ Failed to assign Microsoft Sentinel role for $playbookName`: $_" -ForegroundColor Red
        }
    }
}


# ============================================================================
# VECTRA ANALYTIC RULES CONFIGURATION
# ============================================================================
do {
    $deployAnalyticRules = Read-Host "`nDo you want to deploy Vectra XDR Analytic Rules? (yes/no)"
    $deployAnalyticRules = $deployAnalyticRules.ToLower()
} while ($deployAnalyticRules -notmatch "^(yes|y|no|n)$")

if ($deployAnalyticRules -match "^(yes|y)$") {
    Write-Host "`n📊 CONFIGURING VECTRA ANALYTIC RULES" -ForegroundColor Magenta
    $resourceGroupName = $resourceGroup
    #$githubBaseUrl = "https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/Solutions/Vectra%20XDR/Analytic%20Rules"
    $githubBaseUrl = "https://raw.githubusercontent.com/fenil-savani/Data-Connectors/refs/heads/main/vectra_rules"

    # Define Vectra analytic rules to deploy
    $vectraRules = @(
        @{
            name        = "Create_Incident_Based_On_Tag_For_Account_Entity"
            fileName    = "Create_Incident_Based_On_Tag_For_Account_Entity.yaml"
            description = "Creates incidents based on tags for account entities"
        },
        @{
            name        = "Create_Incident_Based_On_Tag_For_Host_Entity"
            fileName    = "Create_Incident_Based_On_Tag_For_Host_Entity.yaml"
            description = "Creates incidents based on tags for host entities"
        },
        @{
            name        = "Detection_Account"
            fileName    = "Detection_Account.yaml"
            description = "Creates detection alerts for account entities"
        },
        @{
            name        = "Detection_Host"
            fileName    = "Detection_Host.yaml"
            description = "Creates detection alerts for host entities"
        },
        @{
            name        = "Priority_Account"
            fileName    = "Priority_Account.yaml"
            description = "Creates priority alerts for account entities"
        },
        @{
            name        = "Priority_Host"
            fileName    = "Priority_Host.yaml"
            description = "Creates priority alerts for host entities"
        },
        @{
            name        = "Defender_Alert_Evidence"
            fileName    = "Defender_Alert_Evidence.yaml"
            description = "Defender Alert Evidence rule"
        }
    )

    # Install Required Module
    Write-Host "`n🔧 Installing PowerShell YAML module if needed..."
    try {
        if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
            Write-Host "📦 Installing powershell-yaml module..."
            Install-Module powershell-yaml -Force -Scope CurrentUser -AllowClobber
        }
        Import-Module powershell-yaml -Force
        Write-Host "✅ PowerShell YAML module loaded successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to install/import YAML module: $_" -ForegroundColor Red
        exit
    }

    # ============================================================================
    # HELPER FUNCTIONS
    # ============================================================================

    # TimeSpan Conversion Function
    function Convert-ToTimeSpan {
        param([string]$value)
        if ($value -match '(\d+)\s*m') { return "PT$($matches[1])M" } # ISO8601 duration
        elseif ($value -match '(\d+)\s*h') { return "PT$($matches[1])H" }
        elseif ($value -match '(\d+)\s*d') { return "P$($matches[1])D" }
        elseif ($value -match 'PT(\d+)M') { return $value } # Already in ISO8601 format
        elseif ($value -match 'PT(\d+)H') { return $value }
        elseif ($value -match 'P(\d+)D') { return $value }
        else { throw "Unsupported time format: $value" }
    }

    # Function to deploy a single analytic rule
    function Deploy-VectraAnalyticRule {
        param(
            [hashtable]$ruleConfig,
            [string]$baseUrl,
            [string]$resourceGroupName,
            [string]$workspaceName
        )
    
        $ruleName = $ruleConfig.name
        $fileName = $ruleConfig.fileName
        $githubRawUrl = "$baseUrl/$fileName"
    
        Write-Host "`n📥 Processing rule: $ruleName" -ForegroundColor Cyan
        Write-Host "📥 Downloading from: $githubRawUrl" -ForegroundColor Gray
    
        # Download YAML Template
        $tempYamlPath = "$HOME/$fileName"
    
        try {
            Invoke-WebRequest -Uri $githubRawUrl -OutFile $tempYamlPath -UseBasicParsing
            Write-Host "✅ Rule template downloaded successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to download rule template: $_" -ForegroundColor Red
            return $false
        }
    
        # Parse YAML
        Write-Host "📋 Parsing rule configuration..."
        try {
            $rule = (Get-Content $tempYamlPath -Raw | ConvertFrom-Yaml)
            Write-Host "✅ Rule configuration parsed successfully." -ForegroundColor Green
            Write-Host "📊 Rule Name: $($rule.name)" -ForegroundColor Cyan
            Write-Host "📊 Severity: $($rule.severity)" -ForegroundColor Cyan
            Write-Host "📊 Query Frequency: $($rule.queryFrequency)" -ForegroundColor Cyan
        }
        catch {
            Write-Host "❌ Failed to parse YAML configuration: $_" -ForegroundColor Red
            Remove-Item -Path $tempYamlPath -ErrorAction SilentlyContinue
            return $false
        }
    
        # Convert rule parameters
        Write-Host "⚙️ Converting rule parameters..."
        try {
            $frequency = Convert-ToTimeSpan $rule.queryFrequency
            $period = Convert-ToTimeSpan $rule.queryPeriod
            $suppressionDuration = if ($rule.suppressionDuration) { Convert-ToTimeSpan $rule.suppressionDuration } else { "PT1H" }
        
            $operatorMap = @{
                "GreaterThan" = "GreaterThan"
                "LessThan"    = "LessThan"
                "Equal"       = "Equal"
                "NotEqual"    = "NotEqual"
                "gt"          = "GreaterThan"
                "lt"          = "LessThan"
                "eq"          = "Equal"
                "ne"          = "NotEqual"
            }
        
            $triggerOperator = $operatorMap[$rule.triggerOperator]
            if (-not $triggerOperator) {
                $triggerOperator = $rule.triggerOperator  # Use as-is if not in map
            }
        
            Write-Host "✅ Rule parameters converted successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to convert rule parameters: $_" -ForegroundColor Red
            Remove-Item -Path $tempYamlPath -ErrorAction SilentlyContinue
            return $false
        }
    
        # Build Analytic Rule Configuration
        Write-Host "🔨 Building analytic rule configuration..."
        try {
            $ruleId = if ($rule.id) { $rule.id } else { (New-Guid).Guid }
        
            $alertRule = @{
                kind                = if ($rule.kind) { $rule.kind } else { "Scheduled" }
                displayName         = $rule.name
                description         = $rule.description
                severity            = $rule.severity
                enabled             = $true
                query               = $rule.query
                triggerOperator     = $triggerOperator
                triggerThreshold    = [int]$rule.triggerThreshold
                queryFrequency      = $frequency
                queryPeriod         = $period
                suppressionEnabled  = if ($rule.suppressionEnabled -ne $null) { [bool]$rule.suppressionEnabled } else { $false }
                suppressionDuration = $suppressionDuration
            }
        
            # Add optional fields if present in YAML
            if ($rule.tactics) { $alertRule.tactics = @($rule.tactics) }
            if ($rule.relevantTechniques) { $alertRule.techniques = @($rule.relevantTechniques) }
            if ($rule.entityMappings) { $alertRule.entityMappings = $rule.entityMappings }
            if ($rule.customDetails) { $alertRule.customDetails = $rule.customDetails }
            if ($rule.alertDetailsOverride) { $alertRule.alertDetailsOverride = $rule.alertDetailsOverride }
            if ($rule.eventGroupingSettings) { $alertRule.eventGroupingSettings = $rule.eventGroupingSettings }
            if ($rule.incidentConfiguration) { $alertRule.incidentConfiguration = $rule.incidentConfiguration }
        
            Write-Host "✅ Analytic rule configuration built successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to build rule configuration: $_" -ForegroundColor Red
            Remove-Item -Path $tempYamlPath -ErrorAction SilentlyContinue
            return $false
        }
    
        # Deploy Analytic Rule
        Write-Host "🚀 Deploying analytic rule to Microsoft Sentinel..."
        try {
            # Get workspace details
            $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $workspaceName
            $resourceUri = "$($workspace.ResourceId)/providers/Microsoft.SecurityInsights/alertRules/$ruleId"
        
            Write-Host "📍 Workspace: $workspaceName" -ForegroundColor Cyan
            Write-Host "📍 Rule ID: $ruleId" -ForegroundColor Cyan
            Write-Host "📍 Rule Name: $($rule.name)" -ForegroundColor Cyan
        
            # Create debug JSON for troubleshooting
            $debugPath = "$HOME/vectra_rule_debug_$($ruleName).json"
            $alertRule | ConvertTo-Json -Depth 20 | Out-File $debugPath
            Write-Host "🔍 Debug configuration saved to: $debugPath" -ForegroundColor Gray
        
            # Deploy the rule
            $deployResult = New-AzResource -ResourceId $resourceUri -Properties $alertRule -Force -ApiVersion "2023-02-01-preview" -ErrorAction Stop
        
            # Verify deployment was actually successful
            if ($deployResult) {
                Write-Host "✅ Analytic Rule '$($rule.name)' deployed successfully!" -ForegroundColor Green
                Write-Host "📊 Rule Details:" -ForegroundColor Cyan
                Write-Host "  • Name: $($rule.name)" -ForegroundColor White
                Write-Host "  • Severity: $($rule.severity)" -ForegroundColor White
                Write-Host "  • Frequency: $($rule.queryFrequency)" -ForegroundColor White
                Write-Host "  • Status: Enabled" -ForegroundColor White
            
                # Cleanup
                Remove-Item -Path $tempYamlPath -ErrorAction SilentlyContinue
                Remove-Item -Path $debugPath -ErrorAction SilentlyContinue
            
                return $true
            }
            else {
                throw "Deployment returned null result"
            }
        
        }
        catch {
            Write-Host "❌ Analytic Rule '$($rule.name)' deployment failed: $_" -ForegroundColor Red
            Remove-Item -Path $tempYamlPath -ErrorAction SilentlyContinue
            return $false
        }
    }

    # ============================================================================
    # MAIN DEPLOYMENT PROCESS
    # ============================================================================
    Write-Host "`n🚀 STARTING VECTRA ANALYTIC RULES DEPLOYMENT" -ForegroundColor Magenta

    $deploymentResults = @()
    $successCount = 0
    $failureCount = 0
    $skippedCount = 0

    foreach ($ruleConfig in $vectraRules) {
        do {
            $deploySolution = Read-Host "`nDo you want to deploy the $($ruleConfig.name) analytic rule? (yes/no)"
            $deploySolution = $deploySolution.ToLower()
        } while ($deploySolution -notmatch "^(yes|y|no|n)$")

        if ($deploySolution -eq "no" -or $deploySolution -eq "n") {
            Write-Host "👋 Skipping: $($ruleConfig.name)" -ForegroundColor Gray
            $skippedCount++
            continue
        }

        Write-Host "`n" + "="*80 -ForegroundColor DarkGray
        Write-Host "🔄 Deploying: $($ruleConfig.name)" -ForegroundColor Yellow
        Write-Host "📝 Description: $($ruleConfig.description)" -ForegroundColor Gray
    
        $deploymentSuccess = Deploy-VectraAnalyticRule -ruleConfig $ruleConfig -baseUrl $githubBaseUrl -resourceGroupName $resourceGroupName -workspaceName $workspaceName
    
        $deploymentResults += @{
            RuleName    = $ruleConfig.name
            Success     = $deploymentSuccess
            Description = $ruleConfig.description
        }
    
        if ($deploymentSuccess) {
            $successCount++
            Write-Host "✅ SUCCESS: $($ruleConfig.name)" -ForegroundColor Green
        }
        else {
            $failureCount++
            Write-Host "❌ FAILED: $($ruleConfig.name)" -ForegroundColor Red
        }
    
        Start-Sleep -Seconds 2  # Brief pause between deployments
    }

}


# ============================================================================
# CLEANUP & COMPLETION
# ============================================================================
Write-Host "`n🧹 Cleaning up temporary files..."
if ($tempSolutionPath -and $deploySolution -match "^(yes|y)$") {
    Remove-Item -Path $tempSolutionPath -ErrorAction SilentlyContinue
}
if ($tempConnectorPath) {
    Remove-Item -Path $tempConnectorPath -ErrorAction SilentlyContinue
}
if ($tempPlaybookPath) {
    Remove-Item -Path $tempPlaybookPath -ErrorAction SilentlyContinue
}

Write-Host "`n"
Write-Host "🎉 VECTRA XDR DEPLOYMENT COMPLETED!" -ForegroundColor Green

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================
Write-Host "`n📊 Final Deployment Summary:" -ForegroundColor Cyan

if ($deployConnector -match "^(yes|y)$" -and $deployConnector -ne "failed") {
    Write-Host "✅ Vectra XDR Data Connector: Deployed" -ForegroundColor Green

    Write-Host "`n📝 Manual steps to enable system-assigned managed identity and set Key Vault access (if error occured during automating the process):" -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Yellow

    Write-Host "`n1️⃣ Enable system-assigned managed identity:" -ForegroundColor Cyan
    Write-Host "   a. Go to Azure Portal: https://portal.azure.com" -ForegroundColor White
    Write-Host "   b. Navigate to Function App '$functionAppName'" -ForegroundColor White
    Write-Host "   c. Select 'Identity' from the left menu" -ForegroundColor White
    Write-Host "   d. On the 'System assigned' tab, set Status to 'On'" -ForegroundColor White
    Write-Host "   e. Click 'Save' and confirm with 'Yes'" -ForegroundColor White
    Write-Host "   f. Copy the 'Object (principal) ID' value" -ForegroundColor White

    Write-Host "`n2️⃣ Add Function App to Key Vault access policy:" -ForegroundColor Cyan
    Write-Host "   a. Navigate to Key Vault '$keyVaultName'" -ForegroundColor White
    Write-Host "   b. Select 'Access policies' from the left menu" -ForegroundColor White
    Write-Host "   c. Click '+ Add Access Policy'" -ForegroundColor White
    Write-Host "   d. Under 'Secret permissions', select:" -ForegroundColor White
    Write-Host "      - For full management: 'Get', 'List', 'Set', 'Delete'" -ForegroundColor White
    Write-Host "   e. Under 'Key permissions', select appropriate permissions" -ForegroundColor White
    Write-Host "   f. Click to 'Select principal'" -ForegroundColor White
    Write-Host "   g. Paste the Object ID you copied from the Function App" -ForegroundColor White
    Write-Host "   h. Select your Function App and click 'Select'" -ForegroundColor White
    Write-Host "   i. Click 'Add' to add the access policy" -ForegroundColor White
    Write-Host "   j. Click 'Save' to apply the changes" -ForegroundColor White
}
elseif ($deployConnector -eq "failed") {
    Write-Host "❌ Vectra XDR Data Connector: Failed" -ForegroundColor Red
}
else {
    Write-Host "⏭️ Vectra XDR Data Connector: Skipped" -ForegroundColor Yellow
}

if ($deployPlaybooks -match "^(yes|y)$" -and $successfulDeployments.Count -gt 0) {
    Write-Host "✅ Vectra XDR Playbooks: $($successfulDeployments.Count) deployed successfully" -ForegroundColor Green

    Write-Host "`n🔧 POST-DEPLOYMENT CONFIGURATION REQUIRED FOR PLAYBOOKS:" -ForegroundColor Yellow
    
    Write-Host "`n📋 STEP 1: Verify Key Vault Secrets" -ForegroundColor Cyan
    Write-Host "• Go to Key Vault '$keyVaultName' → Secrets" -ForegroundColor White
    Write-Host "• Ensure the secrets exist" -ForegroundColor White
    
    Write-Host "`n📋 STEP 2: Authorize API Connections" -ForegroundColor Cyan
    Write-Host "For each deployed playbook, authorize the connections:" -ForegroundColor White
    foreach ($playbook in $successfulDeployments) {
        Write-Host "• Logic App: $playbook" -ForegroundColor Gray
    }
    Write-Host "Steps for each playbook:" -ForegroundColor White
    Write-Host "  1. Go to Logic App → API connections" -ForegroundColor Gray
    Write-Host "  2. Select Key Vault connection resource" -ForegroundColor Gray
    Write-Host "  3. Go to General → Edit API connection" -ForegroundColor Gray
    Write-Host "  4. Click Authorize → Sign in → Save" -ForegroundColor Gray
    Write-Host "  5. Repeat above steps if playbook requires Teams connections" -ForegroundColor Gray

    Write-Host "`n📋 STEP 3: Configure Analytic Rules (if not already done)" -ForegroundColor Cyan
    Write-Host "• Create analytic rules based on Vectra XDR data" -ForegroundColor White
    Write-Host "• Ensure rules have proper Entity mapping for Host and Account entities" -ForegroundColor White
    Write-Host "• Configure Custom Details with relevant fields for playbook automation" -ForegroundColor White

    Write-Host "`n📋 STEP 4: Set Up Automation Rules" -ForegroundColor Cyan
    Write-Host "• Go to Microsoft Sentinel → Automation → Create → Automation rule" -ForegroundColor White
    Write-Host "• Configure conditions based on your analytic rules" -ForegroundColor White
    Write-Host "• Add 'Run playbook' actions for the deployed playbooks:" -ForegroundColor White
    foreach ($playbook in $successfulDeployments) {
        Write-Host "  - $playbook" -ForegroundColor Gray
    }

    if ($failedDeployments.Count -gt 0) {
        Write-Host "⚠️ Vectra XDR Playbooks: $($failedDeployments.Count) failed to deploy" -ForegroundColor Yellow
    }
}
elseif ($deployPlaybooks -eq "failed") {
    Write-Host "❌ Vectra XDR Playbooks: Failed" -ForegroundColor Red
}
else {
    Write-Host "⏭️ Vectra XDR Playbooks: Skipped" -ForegroundColor Yellow
}

if ($deployAnalyticRules -match "^(yes|y)$") {

    Write-Host "`n📈 Overall Results:" -ForegroundColor Cyan
    Write-Host "✅ Successful Analytic Rule deployments: $successCount" -ForegroundColor Green
    Write-Host "❌ Failed Analytic Rule deployments: $failureCount" -ForegroundColor Red
    Write-Host "📊 Skipped Analytic Rule deployments: $skippedCount" -ForegroundColor Gray
    Write-Host "📊 Total rules processed: $($vectraRules.Count)" -ForegroundColor Cyan

    Write-Host "`n📋 Detailed Results:" -ForegroundColor Cyan
    foreach ($result in $deploymentResults) {
        $status = if ($result.Success) { "✅ SUCCESS" } else { "❌ FAILED" }
        $color = if ($result.Success) { "Green" } else { "Red" }
        Write-Host "  $status - $($result.RuleName)" -ForegroundColor $color
    }
}
