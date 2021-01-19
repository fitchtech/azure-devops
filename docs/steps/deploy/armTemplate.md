# ARM Template Steps Template

- Azure Resource Manager templates (ARM templates) provides Infrastructure as Code (IaC) for Azure. The armTemplate steps template deploys the provided ARM template
- Azure limits ARM deployments to 800 per resource group. This steps template includes an optional cleanup script to remove the oldest deployment so that the limit is not reach which would prevent deployments

## Serial Deployment of ARM Templates

The following example shows how to insert the armTemplate steps template into the [pipeline](../../pipeline.md) template with the minimum required params.

This pattern would deploy each of the templates in the armTemplates list serially within a single job.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into pipeline.yaml template:

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
- name: deploymentDir # Root path of ARM templates
  type: string
  default: '$(Build.Repository.LocalPath)'

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
                      deploymentDir: '${{ parameters.deploymentDir }}' # root path where ARM templates are located
                      deploymentTemplate: ${{ arm.template }} # ARM template within deploymentDir
                      ${{ if arm.parameters }}:
                        deploymentParameters: ${{ arm.parameters }} # Parameters file within deploymentDir 
                      ${{ if arm.override }}:
                        deploymentOverride: '${{ arm.override }}' # Optionally add args to override values in parameters file
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
# params to pass into pipeline.yaml template:

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
- name: deploymentDir # Root path of ARM templates
  type: string
  default: '$(Build.Repository.LocalPath)'

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
  # code: jobList inserted into code stage in stages
  # build: jobList inserted into build stage in stages
  # deploy: deploymentList inserted into deploy stage in stages param
    deploy:
    # - for each arm item in armTemplates parameter insert arm deployment job
      - ${{ each arm in parameters.armTemplates }}:
        - ${{ if and(arm.template, arm.job) }}:
          - deployment: ${{ arm.deployment }} # deployment name unique to stage
            displayName: 'Deploy ARM Template ${{ arm.template }}'
            pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
            ${{ if arm.condition }}:
              condition: ${{ arm.condition }}
            ${{ if not(arm.condition) }}:
              condition: succeeded()
          # variables:
            # key: 'value' # pairs of variables scoped to this job
            ${{ if arm.dependsOn }}:
              dependsOn:
              - ${{ each dependency in arm.dependsOn }}:
                - ${{ dependency }}
            ${{ if not(arm.dependsOn) }}:
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
                        deploymentDir: '${{ parameters.deploymentDir }}' # root path where ARM templates are located
                        deploymentTemplate: ${{ arm.template }} # ARM template within deploymentDir
                        ${{ if arm.parameters }}:
                          deploymentParameters: ${{ arm.parameters }} # Parameters file within deploymentDir 
                        ${{ if arm.override }}:
                          deploymentOverride: '${{ arm.override }}' # Optionally add args to override values in parameters file
                      # postSteps:
                        # - task: add postSteps into job

    # - deployment: insert additional deployment jobs into the deploy stage

  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```
