targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'ms.network.frontdoorWebApplicationFirewallPolicies-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'nagwafpcom'

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = true

@description('Optional. A token to inject into the name of each resource.')
param namePrefix string = '[[namePrefix]]'

// ============ //
// Dependencies //
// ============ //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
}

module nestedDependencies 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-nestedDependencies'
  params: {
    managedIdentityName: 'dep-${namePrefix}-msi-${serviceShort}'
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
    lock: 'CanNotDelete'
    sku: 'Premium_AzureFrontDoor'
    policySettings: {
      mode: 'Prevention'
      redirectUrl: 'http://www.bing.com'
      customBlockResponseStatusCode: 200
      customBlockResponseBody: 'PGh0bWw+CjxoZWFkZXI+PHRpdGxlPkhlbGxvPC90aXRsZT48L2hlYWRlcj4KPGJvZHk+CkhlbGxvIHdvcmxkCjwvYm9keT4KPC9odG1sPg=='
    }
    customRules: {
      rules: [
        {
          name: 'CustomRule1'
          priority: 2
          enabledState: 'Enabled'
          action: 'Block'
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 10
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              selector: null
              operator: 'GeoMatch'
              negateCondition: false
              transforms: []
              matchValue: [
                'CH'
              ]
            }
            {
              matchVariable: 'RequestHeader'
              selector: 'UserAgent'
              operator: 'Contains'
              negateCondition: false
              transforms: []
              matchValue: [
                'windows'
              ]
            }
            {
              matchVariable: 'QueryString'
              operator: 'Contains'
              negateCondition: false
              transforms: [
                'UrlDecode'
                'Lowercase'
              ]
              matchValue: [
                '<?php'
                '?>'
              ]
            }
          ]
        }
      ]
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
    tags: {
      Environment: 'Non-Prod'
      Role: 'DeploymentValidation'
    }
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Reader'
        principalIds: [
          nestedDependencies.outputs.managedIdentityPrincipalId
        ]
        principalType: 'ServicePrincipal'
      }
    ]
  }
}
