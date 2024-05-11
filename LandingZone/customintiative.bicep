targetScope = 'managementGroup'
param name string = ''
param displayName string = ''
param policyCategory string = ''
param description string = ''

@sys.description('Optional. The remediation failure threshold settings. A number between 0.0 to 1.0 representing the percentage failure threshold. The remediation will fail if the percentage of failed remediation operations (i.e. failed deployments) exceeds this threshold. 0 means that the remediation will stop after the first failure. 1 means that the remediation will not stop even if all deployments fail.')
param failureThresholdPercentage string = '1'

@sys.description('Optional. The filters that will be applied to determine which resources to remediate.')
param filtersLocations array = []

@sys.description('Optional. Determines how many resources to remediate at any given time. Can be used to increase or reduce the pace of the remediation. Can be between 1-30. Higher values will cause the remediation to complete more quickly, but increase the risk of throttling. If not provided, the default parallel deployments value is used.')
@minValue(1)
@maxValue(30)
param parallelDeployments int = 10

@sys.description('Optional. Determines the max number of resources that can be remediated by the remediation job. Can be between 1-50000. If not provided, the default resource count is used.')
@minValue(1)
@maxValue(50000)
param resourceCount int = 500

param identity string = 'UserAssigned'

var identityVar = identity == 'SystemAssigned' ? {
  type: identity
} : identity == 'UserAssigned' ? {
  type: identity
  userAssignedIdentities: {
    '${userAssignedIdentityId}': {}
  }
} : null
@sys.description('Optional. The Resource ID for the user assigned identity to assign to the policy assignment.')
param userAssignedIdentityId string = '' 

@sys.description('Optional. The Resource ID for the user assigned identity to assign to the policy assignment.')
param remediation bool = true

@sys.description('Optional. The policy definition mode. Default is All, Some examples are All, Indexed, Microsoft.KeyVault.Data.')
@allowed([
  'All'
  'Indexed'
  'Microsoft.KeyVault.Data'
  'Microsoft.ContainerService.Data'
  'Microsoft.Kubernetes.Data'
  'Microsoft.Network.Data'
])
param mode string = 'All'

@sys.description('Resource ID of the Log Analytics Workspace to stream Logs to. NonProduction')
param logAnalyticsIDnpe string = ''

var logAnalyticsID = logAnalyticsIDnpe

@sys.description('Location of the Deployment-Location Where the identity is created.')
param Location string = deployment().location

@sys.description('List of Objects which contian the Configurations required to configure Diagnoistics Settings for the resource')
param DiagConfigs array = []

@sys.description('Role Definiton Id of the Contributor role - required to deploy the Diag Settings')
param RoleDefID array = []

param builtinpolicies array = []
param custompolicies array = []
param intiativePolicyAssignmentName string = 'policyassignment'
param initativeparams object = {}

var locationField = '[field(${singleQuote}location${singleQuote})]'
param logAnalytics string = '[parameters(${singleQuote}logAnalytics${singleQuote})]'
var resourceNameField = '[field(${singleQuote}name${singleQuote})]'
var resourceDiagName = '[concat(parameters(${singleQuote}resourceName${singleQuote}), ${singleQuote}/${singleQuote}, ${singleQuote}Microsoft.Insights/resourceName-cyber-diagsetting${singleQuote})]'
param singleQuote string = '\''
param policyname string = '[concat(${singleQuote}cyber-diagSettings-${singleQuote}, field(${singleQuote}name${singleQuote}))]'
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = [for policy in custompolicies: {
  name: 'custommgDeployment-${policy.name}'
  properties: {
    policyType: 'Custom'
    mode: mode
    displayName: !empty(policy.displayName) ? policy.displayName : null
    description: !empty(policy.description) ? policy.description : null
    metadata: !empty(policy.metadata) ? policy.metadata : null
    parameters: !empty(policy.parameters) ? policy.parameters : null
    policyRule: policy.policyRule
  }
}]
resource diagSettingsPolicies 'Microsoft.Authorization/policyDefinitions@2021-06-01' = [for resourceDiagConfig in DiagConfigs: {
  name: resourceDiagConfig.name
  properties: { 
    displayName: '${resourceDiagConfig.displayName}'
    description: resourceDiagConfig.description
    metadata: {
      category: 'Monitoring'
    }
    mode: 'All'
    parameters: {
      logAnalytics: {
        type: 'string'
        metadata: {
          displayName: 'Log Analytics workspace'
          description: 'Select the Log Analytics workspace from dropdown list'
          strongType: 'omsWorkspace'
        }
        defaultValue: logAnalyticsID
      }
    }
    policyRule: {
      if: {
        field: 'type'
        equals: resourceDiagConfig.type
      }
      then: {
        effect: 'deployIfNotExists'
        details: {
          type: 'Microsoft.Insights/diagnosticSettings'
          name: policyname
          roleDefinitionIds: RoleDefID
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'http://schema.management.azure.com/schemas/2019-08-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  resourceName: {
                    type: 'string'
                  }
                  logAnalytics: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                }
                variables: {}
                resources: [
                  {
                    type: '${resourceDiagConfig.type}/providers/diagnosticSettings'
                    apiVersion: '2021-05-01-preview'
                    name: resourceDiagName
                    location: Location
                    dependsOn: []
                    properties: {
                      workspaceId: logAnalyticsID
                      metrics: resourceDiagConfig.metrics
                      logs: resourceDiagConfig.logs
                    }
                  }
                ]
                outputs: {}
              }
              parameters: {
                logAnalytics: {
                  value: logAnalytics
                }
                location: {
                  value: locationField
                }
                resourceName: {
                  value: resourceNameField
                }
              }
            }
          }
        }
      }
    }
  }
}]
var diagSettingsPoliciesIDs =[for index in range(0, length(DiagConfigs)): {
  policyDefinitionId: diagSettingsPolicies[index].id
  name : DiagConfigs[index].name
  remediation       : remediation
  parameters: {
    logAnalytics: {
      value: logAnalytics
    }
  } 
 }
]
var custompolicydefnitionids =[for index in range(0, length(custompolicies)): {
  policyDefinitionId: policyDefinition[index].id
  name              : custompolicies[index].name
  remediation       : custompolicies[index].? remediation
  parameters        : {}
}]
var builtindefid = [for policy in builtinpolicies: {
  policyDefinitionId: policy.policyDefinitionId
  remediation        : policy.remediation 
  name               : policy.name
  parameters: contains(policy, 'parameters') ? policy.parameters : {}      
}]
var policydefids =union(custompolicydefnitionids,builtindefid,diagSettingsPoliciesIDs)
resource diagSettingsInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: intiativePolicyAssignmentName
  properties: {
    displayName: 'Apply diagnostic settings for applicable resources - Log Analytics '
    description: 'This initiative configures application Azure resources to forward diagnostic logs and metrics to the Azure Log Analytics workspace.'
    metadata: {
      category: 'Monitoring'
    }
    parameters:{
      logAnalytics: {
        type: 'string'
        metadata: {
          displayName: 'Log Analytics workspace'
          description: 'Select the Log Analytics workspace from dropdown list'
          strongType: 'omsWorkspace'
        }
      }
    }
    policyDefinitions: policydefids
  }
  dependsOn:[
    diagSettingsPolicies
  ]
}
@sys.description('Array of the IDs of the Things that do not fall in the scope of the policies.')
param notScopesList array = []

resource diagSettingPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' ={
  name: intiativePolicyAssignmentName
  location: Location
  properties:{
    displayName: 'Apply diagnostic settings for applicable resources - Log Analytics'
    description: 'Apply diagnostic settings for applicable resources to stream logs and metrics to Specfied Log Analytics Workspace.'
    policyDefinitionId: diagSettingsInitiative.id
    parameters:{
      logAnalytics:{
        value: logAnalyticsID
      }
    }
    enforcementMode: 'Default'
    notScopes: notScopesList
  }
  identity: identityVar
}
output diagSettingPolicyAssignmentObj object = diagSettingPolicyAssignment

resource remediation_mg 'Microsoft.PolicyInsights/remediations@2021-10-01' = [for index in range(0, length(DiagConfigs)):{
  name: diagSettingsPolicies[index].name
  properties: {    
    failureThreshold: {
      percentage: json(failureThresholdPercentage)
    }
    filters: {
      locations: filtersLocations
    }
    parallelDeployments: parallelDeployments
    policyAssignmentId: diagSettingPolicyAssignment.id
    policyDefinitionReferenceId: diagSettingsInitiative.properties.policyDefinitions[index].policyDefinitionReferenceId
    resourceCount: resourceCount
    resourceDiscoveryMode: 'ExistingNonCompliant'
  }
}
]

module policySetDefinition_mgmt '../../Modules/Azurepolicies/policyinitative/policysetdefinition.bicep' = {
  name: name
  params: {
    name: name
    displayName: displayName
    description: description
    metadata: {
      category: policyCategory
    }
    parameters: initativeparams
    policyDefinitions: [for policydefid in policydefids:{
        policyDefinitionId: policydefid.policyDefinitionId
        parameters : policydefid.parameters
      }
    ]
    policyDefinitionGroups: []
    location : Location
    intiativePolicyAssignmentName : intiativePolicyAssignmentName
    identity: identity 
    userAssignedIdentityId: userAssignedIdentityId 
    policydefids          : policydefids
  }
}


