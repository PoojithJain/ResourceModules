targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'ms.web.sites-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'wswa'

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = true

@description('Optional. A token to inject into the name of each resource.')
param namePrefix string = '[[namePrefix]]'

// ============ //
// Dependencies //
// ============ //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module nestedDependencies 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-nestedDependencies'
  params: {
    virtualNetworkName: 'dep-[[namePrefix]]-vnet-${serviceShort}'
    managedIdentityName: 'dep-[[namePrefix]]-msi-${serviceShort}'
    serverFarmName: 'dep-[[namePrefix]]-sf-${serviceShort}'
    relayNamespaceName: 'dep-[[namePrefix]]-ns-${serviceShort}'
    hybridConnectionName: 'dep-[[namePrefix]]-hc-${serviceShort}'
  }
}

// Diagnostics
// ===========
module diagnosticDependencies '../../../../.shared/.templates/diagnostic.dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-diagnosticDependencies'
  params: {
    storageAccountName: 'dep${namePrefix}diasa${serviceShort}01'
    logAnalyticsWorkspaceName: 'dep-${namePrefix}-law-${serviceShort}'
    eventHubNamespaceEventHubName: 'dep-${namePrefix}-evh-${serviceShort}'
    eventHubNamespaceName: 'dep-${namePrefix}-evhns-${serviceShort}'
    location: location
  }
}

// ============== //
// Test Execution //
// ============== //
module testDeployment '../../main.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-test-${serviceShort}'
  params: {
    enableDefaultTelemetry: enableDefaultTelemetry
    name: '${namePrefix}${serviceShort}001'
    kind: 'app'
    serverFarmResourceId: nestedDependencies.outputs.serverFarmResourceId
    diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
    diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
    diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
    diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
    httpsOnly: true
    slots: [
      {
        name: 'slot1'
        diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
        diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
        diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
        diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
        privateEndpoints: [
          {
            service: 'sites'
            subnetResourceId: nestedDependencies.outputs.subnetResourceId
            privateDnsZoneGroup: {
              privateDNSResourceIds: [
                nestedDependencies.outputs.privateDNSZoneResourceId
              ]
            }
            tags: {
              Environment: 'Non-Prod'
              Role: 'DeploymentValidation'
            }
          }
        ]
        roleAssignments: [
          {
            roleDefinitionIdOrName: 'Reader'
            principalIds: [
              nestedDependencies.outputs.managedIdentityPrincipalId
            ]
            principalType: 'ServicePrincipal'
          }
        ]
        siteConfig: {
          alwaysOn: true
          metadata: [
            {
              name: 'CURRENT_STACK'
              value: 'dotnetcore'
            }
          ]
        }
        hybridConnectionRelays: [
          {
            resourceId: nestedDependencies.outputs.hybridConnectionResourceId
            sendKeyName: 'defaultSender'
          }
        ]
      }
      {
        name: 'slot2'
      }
    ]
    privateEndpoints: [
      {
        service: 'sites'
        subnetResourceId: nestedDependencies.outputs.subnetResourceId
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            nestedDependencies.outputs.privateDNSZoneResourceId
          ]
        }
        tags: {
          Environment: 'Non-Prod'
          Role: 'DeploymentValidation'
        }
      }
    ]
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Reader'
        principalIds: [
          nestedDependencies.outputs.managedIdentityPrincipalId
        ]
        principalType: 'ServicePrincipal'
      }
    ]
    siteConfig: {
      alwaysOn: true
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnetcore'
        }
      ]
    }
    systemAssignedIdentity: true
    userAssignedIdentities: {
      '${nestedDependencies.outputs.managedIdentityResourceId}': {}
    }
    basicPublishingCredentialsPolicies: [
      {
        name: 'ftp'
      }
      {
        name: 'scm'
      }

    ]
    hybridConnectionRelays: [
      {
        resourceId: nestedDependencies.outputs.hybridConnectionResourceId
        sendKeyName: 'defaultSender'
      }
    ]
  }
}
