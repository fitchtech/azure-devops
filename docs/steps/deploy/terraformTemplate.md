# Terraform Template Steps Template

- [Terraform Template Steps Template](#terraform-template-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Steps Template Schema](#steps-template-schema)
  - [Deployment of Terraform Templates](#deployment-of-terraform-templates)

## Steps Template Usage

- Inserts Terraform command tasks for each listed in commands parameter. e.g. - init, - plan, - validate, - apply, - destroy
- Terraform commands run in the order listed in the commands parameter
- Commands parameter is a list object where each item key is the command and value is commandOptions. e.g. commands: - apply: '-var="foo=bar"'
- Set task options and command flags for each Terraform command
- Optionally insert Terraform install task
- Commands:
  - init
  - plan
  - validate
  - apply: '-var="$(variableKey)=$(variableValue)"
  - destroy

## Steps Template Schema

```yaml
steps:
# - template: for Terraform steps
  - template: steps/deploy/terraformTemplate.yaml
  # parameters: within terraformTemplate.yaml template
    parameters:
    # preSteps: Optional: inserts stepList after checkout and download
      preSteps: 
        - script: echo add stepList of tasks into steps
      terraformVersion: '0.12.3' # Optional, the version of Terraform which should be installed on the agent if not already present. Omit terraformVersion parameter to skip task
    # provider: azurerm # azurerm (default) | aws | gcp 
      serviceConnection: serviceConnectionName # Required service connection name for provider
    # commands: list of Terraform command tasks executed serially in order. -command: commandOptions
      commands:
        - init
        - plan: '-var "foo=bar"'
        - validate
        - apply: '-var "foo=bar"'
        - destroy
          condition: failed()
      workingDirectory: $(Build.Repository.LocalPath) # Directory containing the Terraform configuration files
    # AzureRM Provider Terraform Storage Backend
      resourceGroupName: resourceGroupName # Required for AzurRM provider, the name of the resource group which contains the storage account selected below.
      storageAccountName: storageAccountName # Required for AzurRM provider, the name of the storage account which contains the Azure Blob container selected below.
      containerName: containerName # Required for AzurRM provider, the name of the Azure Blob container in which to store the Terraform remote state file.
      backendKey: 'terraform.tfstate' # The path to the Terraform remote state file inside the container. Used for azurerm and aws provider
    # bucketName: bucketName # Required for AWS or GCP provider, the name of the Amazon Simple Storage Service(S3) bucket or GCP storage bucket for storing the Terraform remote state file.
    # publishPlan: '$(Build.BuildNumber)_$(System.StageName)_$(Agent.JobName)_OutputPlan' # Default publish artifact name for $(jsonPlanFilePath)
    # publishVariables: '$(Build.BuildNumber)_$(System.StageName)_$(Agent.JobName)_OutputVariables' # Default publish artifact for $(jsonOutputVariablesPath)
    # publishEnabled: false # Disable the publish task, default true. Publishes the testResultsFolder
      replaceTokens: true # Optional to enable replace tokens task for variable replacement
      replaceTokensTargets: '**.tf*' # Target file match pattern for replace tokens task
    # postSteps: Optional: inserts stepList before the publish and clean steps
      postSteps: 
        - script: echo add stepList of tasks into steps

```

## Deployment of Terraform Templates

The following example shows how to insert the terraformTemplate steps template into the [stages](../../stages.md) template. This pattern would deploy each of the templates in the terraformDeployments list with multiple jobs in parallel or with dependencies.

```yaml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template
- name: terraformVersion # The version of Terraform which should be installed on the agent if not already present
  type: string
  default: '0.12.3'
- name: terraformDeployments
  type: object
  default:
  - deployment: 'terraformTemplate1' # deployment name must be unique
    workingDirectory: '$(Build.Repository.LocalPath)/template1'
  - deployment: 'terraformTemplate2' # deployment name must be unique
    workingDirectory: '$(Build.Repository.LocalPath)/template2'
  - deployment: 'terraformTemplate3' # deployment name must be unique
    workingDirectory: '$(Build.Repository.LocalPath)/template3'
    # Example when terraformTemplate3 dependsOn terraformTemplate1 and terraformTemplate2 succeeded
    dependsOn:
      - terraformTemplate1
      - terraformTemplate2
- name: commands # The terraform command to execute in this order. Set value for command for commandOptions, - command: commandOptions | e.g. - apply: '-var "foo=bar"'  
  type: object
  default:
    - init
    - plan
    - validate
    - apply
- name: azureSubscription # Default Azure Subscription service connection name for all jobs
  type: string
  default: ''
- name: resourceGroupName # Default Azure Resource Group within the subscription for all jobs
  type: string
  default: ''
- name: storageAccountName # Required for AzurRM provider, the name of the storage account which contains the Azure Blob container selected below.
  type: string
  default: ''
- name: containerName # Required for AzurRM provider, the name of the Azure Blob container in which to store the Terraform remote state file.
  type: string
  default: ''
- name: deployPool # Default pool param for all deploy jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: checkout # Default checkout repository
  type: string
  default: self

# parameter defaults in the above section can be set on the manual run of a pipeline to override

resources:
  repositories:
    - repository: templates # Resource identifier for template usage
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
  template: stages.yaml@templates
# parameters: within stages.yaml@templates
  parameters:
  # code: jobList inserted into code stage in stages
  # build: jobList inserted into build stage in stages
  # deploy: deploymentList inserted into deploy stage in stages param
    deploy:
    # - for each deployment item in terraformDeployments parameter insert arm deployment job
      - ${{ each deployment in parameters.terraformDeployments }}:
        - ${{ if and(deployment.deployment, deployment.template, parameters.azureSubscription, parameters.resourceGroupName) }}:
          - deployment: ${{ deployment.deployment }} # deployment name unique to stage
            displayName: 'Deploy Terraform Template'
            pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
            ${{ if deployment.condition }}:
              condition: ${{ deployment.condition }}
            ${{ if not(deployment.condition) }}:
              condition: succeeded()
          # variables:
            # key: 'value' # pairs of variables scoped to this job
            ${{ if deployment.dependsOn }}:
              dependsOn: ${{ deployment.dependsOn }}
            ${{ if not(deployment.dependsOn) }}:
              dependsOn: []
            strategy:
              runOnce:
                deploy:
                  steps:
                    - template: steps/deploy/terraformTemplate.yaml
                      parameters:
                      # preSteps: 
                        # - task: add preSteps into job
                        ${{ each param in deployment }}:
                          ${{ if in(param.key, 'azureSubscription', 'resourceGroupName', 'storageAccountName', 'containerName', 'workingDirectory', 'commands') }}:
                            ${{ param.key }}: ${{ param.value }}
                        ${{ if and(not(param.azureSubscription), parameters.azureSubscription) }}:
                          azureSubscription: ${{ parameters.azureSubscription }} # Service connection to subscription for the resource group
                        ${{ if and(not(param.resourceGroupName), parameters.resourceGroupName) }}:
                          resourceGroupName: ${{ parameters.resourceGroupName }} # RM Group name within subscription
                        ${{ if and(not(param.storageAccountName), parameters.storageAccountName) }}:
                          storageAccountName: '${{ parameters.storageAccountName }}' # root path where Terraform templates are located
                        ${{ if and(not(param.containerName), parameters.containerName) }}:
                          containerName: '${{ parameters.containerName }}' # root path where Terraform templates are located
                        ${{ if and(not(param.workingDirectory), parameters.workingDirectory) }}:
                          workingDirectory: '${{ parameters.workingDirectory }}' # root path where Terraform templates are located
                        ${{ if parameters.terraformVersion }}:
                          terraformVersion: ${{ parameters.terraformVersion }}
                      # postSteps:
                        # - task: add postSteps into job

    # - deployment: insert additional deployment jobs into the deploy stage

  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```
