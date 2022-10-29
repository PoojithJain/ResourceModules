// ============== //
//   Parameters   //
// ============== //

@description('Required. Name of the private cloud')
param name string

@description('Optional. Identity for the virtual machine.')
param identity object = {}

@description('Optional. Optionally, set the vCenter admin password when the private cloud is created')
@secure()
param vcenterPassword string = ''

@description('Optional. The block of addresses should be unique across VNet in your subscription as well as on-premise. Make sure the CIDR format is conformed to (A.B.C.D/X) where A,B,C,D are between 0 and 255, and X is between 0 and 22')
param networkBlock string = ''

@description('Optional. An ExpressRoute Circuit')
param circuit object = {}

@description('Optional. An ExpressRoute Circuit')
param secondaryCircuit object = {}

@description('Optional. Optionally, set the NSX-T Manager password when the private cloud is created')
@secure()
param nsxtPassword string = ''

@description('Required. The resource model definition representing SKU')
param sku object

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Optional. Connectivity to internet is enabled or disabled')
@allowed([
  'Enabled'
  'Disabled'
])
param internet string = 'Disabled'

@description('Optional. vCenter Single Sign On Identity Sources')
param identitySources array = []

@description('Optional. The properties describing private cloud availability zone distribution')
param availability object = {}

@description('Optional. The properties of customer managed encryption key')
param encryption object = {}

@description('Optional. The properties of a management cluster')
param managementCluster object = {}

@description('Optional. Resource tags')
param tags object = {}

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource ID of the diagnostic storage account. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the diagnostic log analytics workspace. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
param diagnosticWorkspaceId string = ''

@description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param diagnosticEventHubAuthorizationRuleId string = ''

@description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
param diagnosticEventHubName string = ''

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param diagnosticMetricsToEnable array = [
  'AllMetrics'
]

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'CapacityLatest'
  'DiskUsedPercentage'
  'EffectiveCpuAverage'
  'EffectiveMemAverage'
  'OverheadAverage'
  'TotalMbAverage'
  'UsageAverage'
  'UsedLatest'
])
param diagnosticLogCategoriesToEnable array = [
  'CapacityLatest'
  'DiskUsedPercentage'
  'EffectiveCpuAverage'
  'EffectiveMemAverage'
  'OverheadAverage'
  'TotalMbAverage'
  'UsageAverage'
  'UsedLatest'
]

@description('Optional. The name of the diagnostic setting, if deployed.')
param diagnosticSettingsName string = '${name}-diagnosticSettings'

@description('Optional. Specify the type of lock.')
@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
param lock string = ''

@description('Optional. The hcxEnterpriseSites to create as part of the privateCloud.')
param hcxEnterpriseSites array = []

@description('Optional. The cloudLinks to create as part of the privateCloud.')
param cloudLinks array = []

@description('Optional. The addons to create as part of the privateCloud.')
param addons array = []

@description('Optional. The scriptExecutions to create as part of the privateCloud.')
param scriptExecutions array = []

@description('Optional. The globalReachConnections to create as part of the privateCloud.')
param globalReachConnections array = []

@description('Optional. The clusters to create as part of the privateCloud.')
param clusters array = []

@description('Optional. The authorizations to create as part of the privateCloud.')
param authorizations array = []

@description('Optional. Enable telemetry via the Customer Usage Attribution ID (GUID).')
param enableDefaultTelemetry bool = true

var diagnosticsMetrics = [for metric in diagnosticMetricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var diagnosticsLogs = [for category in diagnosticLogCategoriesToEnable: {
  category: category
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var enableReferencedModulesTelemetry = false


// =============== //
//   Deployments   //
// =============== //

resource defaultTelemetry 'Microsoft.Resources/deployments@2021-04-01' = if (enableDefaultTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}


resource privateCloud 'Microsoft.AVS/privateClouds@2022-05-01' = {
  name: name
  identity: identity
  sku: sku
  location: location
  tags: tags
  properties: {
    vcenterPassword: vcenterPassword
    networkBlock: networkBlock
    circuit: circuit
    secondaryCircuit: secondaryCircuit
    nsxtPassword: nsxtPassword
    internet: internet
    identitySources: identitySources
    availability: availability
    encryption: encryption
    managementCluster: managementCluster
  }
}

resource privateCloud_diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(diagnosticWorkspaceId)) || (!empty(diagnosticEventHubAuthorizationRuleId)) || (!empty(diagnosticEventHubName))) {
  name: diagnosticSettingsName
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    eventHubAuthorizationRuleId: !empty(diagnosticEventHubAuthorizationRuleId) ? diagnosticEventHubAuthorizationRuleId : null
    eventHubName: !empty(diagnosticEventHubName) ? diagnosticEventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: privateCloud
}

resource keyVault_lock 'Microsoft.Authorization/locks@2017-04-01' = if (!empty(lock)) {
  name: '${privateCloud.name}-${lock}-lock'
  properties: {
    level: any(lock)
    notes: lock == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot modify the resource or child resources.'
  }
  scope: privateCloud
}

module privateCloud_hcxEnterpriseSites 'hcxEnterpriseSites/deploy.bicep' = [for (hcxEnterpriseSite, index) in hcxEnterpriseSites: {
name: '${uniqueString(deployment().name, location)}-privateCloud-hcxEnterpriseSite-${index}'
params: {
    privateCloudName: name
    name: hcxEnterpriseSite.name
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_cloudLinks 'cloudLinks/deploy.bicep' = [for (cloudLink, index) in cloudLinks: {
name: '${uniqueString(deployment().name, location)}-privateCloud-cloudLink-${index}'
params: {
    privateCloudName: name
    name: cloudLink.name
    linkedCloud: contains(cloudLink, 'linkedCloud') ? cloudLink.linkedCloud : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_addons 'addons/deploy.bicep' = [for (addon, index) in addons: {
name: '${uniqueString(deployment().name, location)}-privateCloud-addon-${index}'
params: {
    privateCloudName: name
    name: addon.name
    addonType: contains(addon, 'addonType') ? addon.addonType : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_scriptExecutions 'scriptExecutions/deploy.bicep' = [for (scriptExecution, index) in scriptExecutions: {
name: '${uniqueString(deployment().name, location)}-privateCloud-scriptExecution-${index}'
params: {
    privateCloudName: name
    name: scriptExecution.name
    retention: contains(scriptExecution, 'retention') ? scriptExecution.retention : ''
    output: contains(scriptExecution, 'output') ? scriptExecution.output : []
    failureReason: contains(scriptExecution, 'failureReason') ? scriptExecution.failureReason : ''
    parameters: contains(scriptExecution, 'parameters') ? scriptExecution.parameters : []
    hiddenParameters: contains(scriptExecution, 'hiddenParameters') ? scriptExecution.hiddenParameters : []
    scriptCmdletId: contains(scriptExecution, 'scriptCmdletId') ? scriptExecution.scriptCmdletId : ''
    namedOutputs: contains(scriptExecution, 'namedOutputs') ? scriptExecution.namedOutputs : {}
    timeout: contains(scriptExecution, 'timeout') ? scriptExecution.timeout : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_globalReachConnections 'globalReachConnections/deploy.bicep' = [for (globalReachConnection, index) in globalReachConnections: {
name: '${uniqueString(deployment().name, location)}-privateCloud-globalReachConnection-${index}'
params: {
    privateCloudName: name
    name: globalReachConnection.name
    expressRouteId: contains(globalReachConnection, 'expressRouteId') ? globalReachConnection.expressRouteId : ''
    authorizationKey: contains(globalReachConnection, 'authorizationKey') ? globalReachConnection.authorizationKey : ''
    peerExpressRouteCircuit: contains(globalReachConnection, 'peerExpressRouteCircuit') ? globalReachConnection.peerExpressRouteCircuit : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_clusters 'clusters/deploy.bicep' = [for (cluster, index) in clusters: {
name: '${uniqueString(deployment().name, location)}-privateCloud-cluster-${index}'
params: {
    privateCloudName: name
    name: cluster.name
    sku: cluster.sku
    clusterSize: contains(cluster, 'clusterSize') ? cluster.clusterSize : 
    hosts: contains(cluster, 'hosts') ? cluster.hosts : []
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_authorizations 'authorizations/deploy.bicep' = [for (authorization, index) in authorizations: {
name: '${uniqueString(deployment().name, location)}-privateCloud-authorization-${index}'
params: {
    privateCloudName: name
    name: authorization.name
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

// =========== //
//   Outputs   //
// =========== //

@description('The name of the privateCloud.')
output name string = privateCloud.name

@description('The resource ID of the privateCloud.')
output resourceId string = privateCloud.id

@description('The name of the resource group the privateCloud was created in.')
output resourceGroupName string = resourceGroup().name
