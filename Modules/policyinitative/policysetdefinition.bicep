targetScope = 'managementGroup'

@sys.description('Optional. The managed identity associated with the policy assignment. Policy assignments must include a resource identity when assigning \'Modify\' policy definitions.')
@allowed([
  'SystemAssigned'
  'UserAssigned'
  'None'
])
param identity string = 'UserAssigned'
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


@sys.description('Optional. The Resource ID for the user assigned identity to assign to the policy assignment.')
param userAssignedIdentityId string = ''

var identityVar = identity == 'SystemAssigned' ? {
  type: identity
} : identity == 'UserAssigned' ? {
  type: identity
  userAssignedIdentities: {
    '${userAssignedIdentityId}': {}
  }
} : null

@sys.description('Array of the IDs of the Things that do not fall in the scope of the policies.')
param notScopesList array = []


param location string = ''
@sys.description('Required. Specifies the name of the policy Set Definition (Initiative).')
@maxLength(64)
param name string

param intiativePolicyAssignmentName string = ''
@sys.description('Optional. The display name of the Set Definition (Initiative). Maximum length is 128 characters.')
@maxLength(128)
param displayName string = ''

@sys.description('Optional. The description name of the Set Definition (Initiative).')
param description string = ''

@sys.description('Optional. The group ID of the Management Group. If not provided, will use the current scope for deployment.')
param managementGroupId string = managementGroup().name

@sys.description('Optional. The Set Definition (Initiative) metadata. Metadata is an open ended object and is typically a collection of key-value pairs.')
param metadata object = {}

@sys.description('Required. The array of Policy definitions object to include for this policy set. Each object must include the Policy definition ID, and optionally other properties like parameters.')
param policyDefinitions array

@sys.description('Optional. The metadata describing groups of policy definition references within the Policy Set Definition (Initiative).')
param policyDefinitionGroups array = []

@sys.description('Optional. The metadata describing groups of policy definition references within the Policy Set Definition (Initiative).')
param policydefids array = []

@sys.description('Optional. The Set Definition (Initiative) parameters that can be used in policy definition references.')
param parameters object = {}

param assignmentparameters object = {}

resource policySetDefinition 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: name
  properties: {
    policyType: 'Custom'
    displayName: !empty(displayName) ? displayName : null
    description: !empty(description) ? description : null
    metadata: !empty(metadata) ? metadata : null
    parameters: !empty(parameters) ? parameters : null
    policyDefinitions: policyDefinitions
    policyDefinitionGroups: !empty(policyDefinitionGroups) ? policyDefinitionGroups : []
  }
}

resource PolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' ={
  name: intiativePolicyAssignmentName
  location: location
  properties:{
    displayName: displayName
    description: description
    policyDefinitionId: policySetDefinition.id
    parameters: assignmentparameters
    enforcementMode: 'Default'
    notScopes: notScopesList
  }
  identity: identityVar
}

resource remediation_mg 'Microsoft.PolicyInsights/remediations@2021-10-01' = [for (policyDefinition,i) in policydefids:if(policyDefinition.remediation == true){
  name: policyDefinition.name
  properties: {    
    failureThreshold: {
      percentage: json(failureThresholdPercentage)
    }
    filters: {
      locations: filtersLocations
    }
    parallelDeployments: parallelDeployments
    policyAssignmentId: PolicyAssignment.id
    policyDefinitionReferenceId: policySetDefinition.properties.policyDefinitions[i].policyDefinitionReferenceId
    resourceCount: resourceCount
    resourceDiscoveryMode:'ExistingNonCompliant'
  }
}]
output diagSettingPolicyAssignmentObj object = PolicyAssignment
@sys.description('Policy Set Definition Name.')
output name string = policySetDefinition.name
@sys.description('Policy Set Definition Name.')
output id string = policySetDefinition.id

@sys.description('Policy Set Definition resource ID.')
output resourceId string = extensionResourceId(tenantResourceId('Microsoft.Management/managementGroups', managementGroupId), 'Microsoft.Authorization/policySetDefinitions', policySetDefinition.name)
