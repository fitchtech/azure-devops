# ARM Template Steps Template

- [ARM Template Steps Template](#arm-template-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Serial Deployment of ARM Templates](#serial-deployment-of-arm-templates)
  - [Parallel Deployment of ARM Templates](#parallel-deployment-of-arm-templates)

## Steps Template Usage

- Azure Resource Manager templates (ARM templates) provides Infrastructure as Code (IaC) for Azure. The armTemplate steps template deploys the provided ARM template
- Azure limits ARM deployments to 800 per resource group. This steps template includes an optional cleanup script to remove the oldest deployment so that the limit is not reach which would prevent deployments

## Serial Deployment of ARM Templates

The following example shows how to insert the armTemplate steps template into the [stages](../../stages.md) template with the minimum required params.

This pattern would deploy each of the templates in the armTemplates list serially within a single job.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:

- name: deployPool # Nested into pool param of deploy jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: checkout
  type: string
  default: self
- name: azureSubscription # Azure Subscription service connection name
  type: string
  default: ''
- name: resourceGroupName # Azure Resource Group within the subscription
  type: string
  default: ''
- name: armTemplates
  type: object
  default:
  - template: 'deployment1.json'
    parameters: 'parameters1.json'
  - template: 'deployment2.json'
    parameters: 'parameters2.json'
- name: templatePath # Root path of ARM templates
  type: string
  default: '$(Build.Repository.LocalPath)'

# parameter defaults in the above section can be set on manual run of a pipeline to override

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
      - deployment: armTemplate # job name unique to stage
        displayName: 'Deploy ARM Templates'
        pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
        condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        dependsOn: []
        strategy:
          runOnce:
            deploy:
              steps:
              - checkout: ${{ parameters.checkout }}
            # - for each arm item in armTemplates parameter insert arm deployment steps sequentially
              - ${{ each arm in parameters.armTemplates }}:
              # - if item in armTemplates parameter has template key
                - ${{ if arm.template }}:
                  - template: steps/deploy/armTemplate.yaml
                    parameters:
                    # preSteps: 
                      # - task: add preSteps into job
                      checkout: false # Disable checkout in preSteps
                      download: false # Disable download in preSteps
                      azureSubscription: ${{ parameters.azureSubscription }} # Service connection to subscription for the resource group
                      resourceGroupName: ${{ parameters.resourceGroupName }} # RM Group name within subscription
                      templatePath: '${{ parameters.templatePath }}' # root path where ARM templates are located
                      templateFile: ${{ arm.template }} # ARM template within deploymentDir
                      ${{ if arm.parameters }}:
                        parametersFile: ${{ arm.parameters }} # Parameters file within deploymentDir 
                      ${{ if arm.override }}:
                        overrideParameters: '${{ arm.override }}' # Optionally add args to override values in parameters file
                    # postSteps:
                      # - task: add postSteps into job

    # - deployment: insert additional deployment jobs into the deploy stage

  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```

## Parallel Deployment of ARM Templates

This pattern would deploy each of the templates in the armTemplates list parallelly with multiple job.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:

- name: deployPool # Nested into pool param of deploy jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: checkout
  type: string
  default: self
- name: azureSubscription # Azure Subscription service connection name
  type: string
  default: ''
- name: resourceGroupName # Azure Resource Group within the subscription
  type: string
  default: ''
- name: armTemplates
  type: object
  default:
  - deployment: 'armTemplate1' # deployment name must be unique
    template: 'deployment1.json'
    parameters: 'parameters1.json'
  - deployment: 'armTemplate2' # deployment name must be unique
    template: 'deployment2.json'
    parameters: 'parameters2.json'
  - deployment: 'armTemplate3' # deployment name must be unique
    template: 'deployment3.json'
    parameters: 'parameters3.json'
    # Example when armTemplate3 dependsOn armTemplate1 and armTemplate2 succeeded
    dependsOn:
      - armTemplate1
      - armTemplate2
- name: templatePath # Root path of ARM templates
  type: string
  default: '$(Build.Repository.LocalPath)'

# parameter defaults in the above section can be set on manual run of a pipeline to override

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
    # - for each deployment item in armTemplates parameter insert arm deployment job
      - ${{ each deployment in parameters.armTemplates }}:
        - ${{ if and(deployment.deployment, deployment.template, parameters.azureSubscription, parameters.resourceGroupName) }}:
          - deployment: ${{ deployment.deployment }} # deployment name unique to stage
            displayName: 'Deploy ARM Template ${{ arm.template }}'
            pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
            ${{ if deployment.condition }}:
              condition: ${{ deployment.condition }}
            ${{ if not(deployment.condition) }}:
              condition: succeeded()
          # variables:
            # key: 'value' # pairs of variables scoped to this job
            ${{ if deployment.dependsOn }}:
              dependsOn:
              - ${{ each dependency in deployment.dependsOn }}:
                - ${{ dependency }}
            ${{ if not(deployment.dependsOn) }}:
              dependsOn: []
            strategy:
              runOnce:
                deploy:
                  steps:
                    - template: steps/deploy/armTemplate.yaml
                      parameters:
                      # preSteps: 
                        # - task: add preSteps into job
                        azureSubscription: ${{ parameters.azureSubscription }} # Service connection to subscription for the resource group
                        resourceGroupName: ${{ parameters.resourceGroupName }} # RM Group name within subscription
                        templatePath: '${{ parameters.templatePath }}' # root path where ARM templates are located
                        templateFile: ${{ deployment.template }} # ARM template within deploymentDir
                        ${{ if deployment.parameters }}:
                          parametersFile: ${{ deployment.parameters }} # Parameters file within deploymentDir 
                        ${{ if deployment.override }}:
                          overrideParameters: '${{ deployment.override }}' # Optionally add args to override values in parameters file
                      # postSteps:
                        # - task: add postSteps into job

    # - deployment: insert additional deployment jobs into the deploy stage

  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```
