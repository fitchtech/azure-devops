# Build Container Image Steps Template

- [Build Container Image Steps Template](#build-container-image-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)
  - [Direct Steps Template Usage](#direct-steps-template-usage)

## Steps Template Usage

- You can add multiple Container Image build jobs into a jobLists so long as the job name is unique within the stage
- This template nests the [dotNetCore](dotNetCore.md) steps template to dotNet publish a project before docker build so that the publish output can be copied from the build agent into the container image.

## Insert Steps Template into Stages Template

The following example shows how to insert the containerImage steps template into the [stages](../../stages.md) template with the minimum required params. This shows one containerImage job added to the build stage jobLists. Additional, you can add as many build jobs as needed. This example has no deployments. However, it is recommended that you could create a single multistage pipeline that includes code, build, deploy, test, and promote stages in a single pipeline.

Alternatively, you could create a separate deployment pipeline that triggers from the completion of a build pipeline. This pattern could be used to create a build pipeline decoupled from deployments. To do this would require a pipeline resource trigger be added to the resources in your deployment pipeline. The resource in your deployment pipeline would be the build pipeline as a source. When the build pipeline completes if the source pipeline triggers match then the deployment pipeline would run.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:
- name: buildPool # Nested into pool param of build jobs
  type: object
  default: 
    vmImage: 'Ubuntu-16.04'
- name: projects # Required param to restore and publish a dotNet project
  type: string
  default: '**.csproj' # path or pattern match of projects to dotNet publish
- name: dockerFile # Nested into dockerFile of build jobs
  type: string
  default: '**.dockerfile' # path to dockerfile for docker build task
- name: dockerArgs # Nested into dockerArgs of build jobs
  type: string
  default: false # optional to add --build-arg in docker build task
- name: dockerTags
  type: object
  default: $(Build.BuildNumber)
- name: containerRegistry # Nested into containerRegistry param in containerImage job
  type: string
  default: '' # ADO Service Connection name
- name: containerRepository # repo path in registry
  type: string
  default: ''
- name: twistlockEnabled # enable twistlock scan task
  type: boolean
  default: false
- name: twistlockContinue # twistlock vulnerabilities register as warning instead of error in build stage
  type: boolean
  default: false

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
  # code: jobList inserted into code stage in stages param
  # build: jobList inserted into build stage in stages param
    build:
    # - if dockerfile, containerRegistry, containerRepository params are not null insert containerImage job into build stage
      - ${{ if and(parameters.dockerFile, parameters.containerRegistry, parameters.containerRepository) }}:
        - job: containerImage # job name must be unique within stage
          displayName: 'Build Container Image' # job display name
          pool: ${{ parameters.buildPool }} # param passed to pool of build jobs
          dependsOn: [] # job does not depend on other jobs
        # variables:
          # key: 'value' # pairs of variables scoped to this job
          steps:
          # - template: for containerImage steps
            - template: steps/build/containerImage.yaml
            # parameters within containerImage.yaml template
              parameters:
              # preSteps: 
                # - task: add preSteps into job
                projects: '${{ parameters.projects }}'
                containerRegistry: '${{ parameters.containerRegistry }}'
                containerRepository: '${{ parameters.containerRepository }}'
                dockerFile: '${{ parameters.dockerFile }}'
                dockerTags: ${{ parameters.dockerTags }}
                # If dockerArgs is not false
                ${{ if parameters.dockerArgs }}:
                  dockerArgs: '${{ parameters.dockerArgs }}'
                # If twistlockEnabled is true, insert twistlock scan task
                ${{ if parameters.twistlockEnabled }}:
                  twistlockEnabled: true # enable twistlock scan task
                  twistlockContinue: ${{ parameters.twistlockContinue }} # twistlock vulnerabilities register as warning instead of error in build stage
              # postSteps:
                # - task: add postSteps into job

      # - job: insert additional jobs into the build stage

  # deploy: deploymentList inserted into deploy stage in stages param
  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```

## Direct Steps Template Usage

The above example is the recommended pattern for standardizing stages, jobs, and deployments. However, you can use any steps template directly. The below example shows an alternative pattern.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
- name: buildPool # Nested into pool param of build jobs
  type: object
  default:
    vmImage: 'Ubuntu-16.04'
- name: projects # Required param to restore and publish a dotNet project
  type: string
  default: '**.csproj' # path or pattern match of projects to dotNet publish
- name: dockerFile # Nested into dockerFile of build jobs
  type: string
  default: '**.dockerfile' # path to dockerfile for docker build task
- name: dockerArgs # Nested into dockerArgs of build jobs
  type: string
  default: '' # optional to add --build-arg in docker build task
- name: containerRegistry # Nested into containerRegistry params in build job
  type: string
  default: 'ACR' # ADO Service Connection name
- name: containerRepository # repo path in registry
  type: string
  default: ''
- name: imageName # containerRepository/imageName nested into containerRepository of containerImage jobs
  type: string
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

stages:
- stage: build
  dependsOn: []
  jobs:
  - job: containerImage # job name must be unique within stage
    displayName: 'Build Container Image' # job display name
    pool: ${{ parameters.buildPool }} # param passed to pool of build jobs
    dependsOn: [] # job does not depend on other jobs
    steps:
      - template: steps/build/containerImage.yaml@template # resource identifier required as this is not extending from stages.yaml
        parameters:
          projects: '${{ parameters.projects }}'
          containerRegistry: '${{ parameters.containerRegistry }}'
          containerRepository: '${{ parameters.containerRepository }}/${{ parameters.imageName }}'
          dockerFile: '${{ parameters.dockerFile }}'
          dockerArgs: '${{ parameters.dockerArgs }}'
          dockerTags: ${{ parameters.dockerTags }}

```

It is also valid to omit stages and jobs when you need only one stage and job. You can also hard code values if you do not want the option to override at runtime.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

pool:
  vmImage: 'Ubuntu-16.04'

resources:
  repositories:
    - repository: templates # Resource identifier for template usage
      type: github
      name: fitchtech/AzurePipelines # This repository
      ref: refs/tags/v1 # The tagged release of the repository
      endpoint: GitHub # Azure Service Connection Name

steps:
- template: steps/build/containerImage.yaml@template # resource identifier required as this is not extending from stages.yaml
  parameters:
    projects: '**.csproj'
    containerRegistry: 'ACR'
    containerRepository: 'imageName'
    dockerFile: '**.dockerfile'
    dockerTags: $(Build.BuildNumber)

```
