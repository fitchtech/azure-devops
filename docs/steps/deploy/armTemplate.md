# ARM Template Steps Template

- Azure Resource Manager templates (ARM templates) provides Infrastructure as Code (IaC) for Azure. The armTemplate steps template deploys the provided ARM template
- Azure limits ARM deployments to 800 per resource group. This steps template includes an optional cleanup script to remove the oldest 100 deployments so that the limit is not reach which would prevent deployments

## ARM Template Steps in Pipeline Template

The following example shows how to insert the armTemplate steps template into the [pipeline](../../pipeline.md) template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into pipeline.yaml template:

- name: deployPool # Nested into pool param of deploy jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: devAzure # Azure Subscription
  type: string
  default: ''
- name: devResourceGroup # Azure Resource Group
  type: string
  default: ''
- name: armTemplates
  type: object
  default:
  - deploymentTemplate: 'deployment1.json'
    deploymentParameters: 'parameters1.json'
  - deploymentTemplate: 'deployment2.json'
    deploymentParameters: 'parameters2.json'

# parameter defaults in the above section can be set on manual run of a pipeline to override

resources:
  repositories:
    - repository: templates # Resource identitifier for template usage
      type: github
      name: fitchtech/AzurePipelines # This repository
      ref: refs/tags/v1 # The tagged release of the repository
      endpoint: GitHub # Azure Service Connection Name

trigger:
  branches:
    include:
    - master # CI Trigger on commit to master
  tags:
    include:
    - v*.*.*-* # CI Trigger when tag matches format

extends:
# template: file path at repo resource id to extend from
  template: pipeline.yaml@templates
# parameters: within pipeline.yaml@templates
  parameters:
  # codeStages: stageList param to overrides default stages
    # - stage: codeAnalysis
  # codeAnalysis: jobList inserted into codeAnalysis stage in codeStages
  # devStages: stageList param to overrides default stages
    devStages:
    # - stage: devBuild | devDeploy | devPromote | devTests
      - stage: devDeploy
        dependsOn: []
      # variables:
        # key: 'value' # pairs of variables scoped to the jobs within stage

  # devBuild: jobList inserted into devBuild stage in devStages
  # devDeploy: deploymentList inserted into devDeploy stage in devStages
    devDeploy:
      - deployment: armTemplate # job name unique to stage
        displayName: 'Deploy ARM Template'
        pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
        condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        dependsOn: []
        strategy:
          runOnce:
            deploy:
              steps:
            # - for each arm item in armTemplates parameter insert arm deployment steps sequentially
              - ${{ each arm in parameters.armTemplates }}:
              # - if item in armTemplates parameter has deploymentTemplate
                - ${{ if arm.deploymentTemplate }}:
                  - template: steps/deploy/armTemplate.yaml
                    parameters:
                      azureSubscription: ${{ parameters.devAzure }} # Service connection to subscription for the resource group
                      resourceGroupName: ${{ parameters.devResourceGroup }} # RM Group name within subscription
                      deploymentDir: '$(Pipeline.Workspace)/armTemplates' # root path where ARM templates are located
                      deploymentTemplate: ${{ arm.deploymentTemplate }} # ARM template within deploymentDir
                      deploymentParameters: ${{ arm.deploymentParameters }} # Parameters file within deploymentDir 
                    # deploymentOverride: '' # Optionally add args to override values in deploymentParameters file

            # - task: add postSteps to deployment job
    # - deployment: for parallel deployments use multiple deployment jobs in stage

    # - deployment: insert additional deployment jobs into the devDeploy stage
```
