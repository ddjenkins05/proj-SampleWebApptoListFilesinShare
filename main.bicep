targetScope = 'resourceGroup'

@description('Deployment location for all resources.')
param location string = resourceGroup().location

@description('Storage account name. Must be globally unique, 3-24 chars, lowercase letters and numbers only.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'osstorage12341'

@description('Azure Files share name to create and mount into the web app.')
@minLength(3)
@maxLength(63)
param fileShareName string = 'hangfire'

@description('Web app name. Must be globally unique.')
param webAppName string = 'osstorage-poc-${uniqueString(resourceGroup().id)}'

@description('App Service plan name.')
param appServicePlanName string = 'asp-osstorage-poc'

@description('Use F1 for free/dev PoC, or B1 for basic dev/testing.')
@allowed([
  'F1'
  'B1'
])
param appServiceSkuName string = 'F1'

@description('Common tags for all resources.')
param tags object = {
  environment: 'dev'
  workload: 'osstorage-poc'
}

var normalizedStorageAccountName = toLower(storageAccountName)
// For Windows Web Apps the mount path must be a sub-directory of \\mounts
// Use UNC-style path here (escaped backslashes) so the ARM property is valid.
var storageMountPath = '\\mounts\\${fileShareName}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: normalizedStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    largeFileSharesState: 'Enabled'
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2024-01-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    enabledProtocols: 'SMB'
    accessTier: 'TransactionOptimized'
    shareQuota: 100
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServiceSkuName
    tier: appServiceSkuName == 'F1' ? 'Free' : 'Basic'
    size: appServiceSkuName
    capacity: 1
  }
  kind: 'app'
  properties: {
    reserved: false
  }
}

resource webApp 'Microsoft.Web/sites@2024-11-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

resource webAppAppSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'true'
    WEBSITE_NODE_DEFAULT_VERSION: '~20'
    SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
    STORAGE_ACCOUNT_NAME: storageAccount.name
    STORAGE_SHARE_NAME: fileShare.name
    STORAGE_MOUNT_PATH: storageMountPath
  }
}

resource webAppAzureStorageMount 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: webApp
  name: 'azurestorageaccounts'
  properties: {
    hangfireshare: {
      type: 'AzureFiles'
      accountName: storageAccount.name
      shareName: fileShare.name
      accessKey: storageAccount.listKeys().keys[0].value
      mountPath: storageMountPath
    }
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output storageAccountId string = storageAccount.id
output fileShareResourceId string = fileShare.id
output mountedPathInWebApp string = storageMountPath
output smbUncPath string = '\\\\${storageAccount.name}.file.${environment().suffixes.storage}\\${fileShare.name}'
