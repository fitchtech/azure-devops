# Build Container Image Steps Template

- [Build Container Image Steps Template](#build-container-image-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Adding Steps into Pipeline Template](#adding-steps-into-pipeline-template)
  - [Direct Steps Template Usage](#direct-steps-template-usage)

## Steps Template Usage

- You can add multiple Container Image build jobs into a jobLists so long as the job name is unique within the stage
- This template nests the [dotNetCore](dotNetCore.md) steps template to dotNet publish a project before docker build so that the publish output can be copied from the build agent into the container image.

## Adding Steps into Pipeline Template

The following example shows how to insert the containerImage steps template into the [pipeline](../../pipeline.md) template with the minimum required params. This shows one containerImage job added to devBuild, acptBuild, and prodBuild jobLists. This is useful when you have different container registries for isolated environments. Additional, you can add as many build jobs as needed. This example has no deployments, therefore acptBuild dependsOn devBuild, and prodBuild dependsOn acptBuild.

As an alternative to one CICD pipeline to both build and deploy, this pattern could be used to create a build pipeline decoupled from deployments. To do this would require a pipeline resource trigger be added to the resources in your deployment pipeline. The resource in your deployment pipeline would be the build pipeline as a source. When the build pipeline completes if the source pipeline triggers match then the deployment pipeline would run.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into pipeline.yaml template:
- name: buildPool # Nested into pool param of build jobs
  type: object
  default: 
    vmImage: 'Ubuntu-16.04'
- name: devRegistry # Nested into containerRegistry params in devBuild and dintBuild jobs
  type: string
  default: 'ACR' # ADO Service Connection name
- name: acptRegistry # Nested into containerRegistry params in acptBuild jobs
  type: string
  default: 'ACR' # ADO Service Connection name
- name: prodRegistry # Nested into containerRegistry params in prodBuild jobs
  type: string
  default: 'ACR' # ADO Service Connection name
- name: dotNetProject # Required param to restore and publish a dotNet project
  type: string
  default: '**.csproj' # path or pattern match of projects to dotNet publish
- name: dockerFile # Nested into dockerFile of build jobs
  type: string
  default: '**.dockerfile' # path to dockerfile for docker build task
- name: dockerArgs # Nested into dockerArgs of build jobs
  type: string
  default: '' # optional to add --build-arg in docker build task
- name: imageRepo # repo path in registry
  type: string
  default: ''
- name: imageName # imageRepo/imageName nested into containerRepository of containerImage jobs
  type: string

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
      - stage: devBuild
        dependsOn: []
      # variables:
        # key: 'value' # pairs of variables scoped to the jobs within stage
    dintStages: []
    acptStages:
    # - stage: acptBuild | acptDeploy | acptPromote | acptTests
      - stage: acptBuild
      # condition: run if devBuild succeeded, source branch is master or tag starts with 'v' and contains '.' e.g. v0.0.1
        condition: and(succeeded(), or(eq(variables['Build.SourceBranch'], 'refs/heads/master'), and(startsWith(variables['Build.SourceBranch'], 'refs/tags/v'), contains(variables['Build.SourceBranch'], '.'))))
        dependsOn: devBuild
    prodStages: stageList param to override default stages
    # - stage: prodBuild | prodDeploy | prodPromote | prodTests
      - stage: prodBuild
        condition: and(succeeded(), or(eq(variables['Build.SourceBranch'], 'refs/heads/master'), and(startsWith(variables['Build.SourceBranch'], 'refs/tags/v'), contains(variables['Build.SourceBranch'], '.'))))
        dependsOn: acptBuild
  # devBuild: jobList inserted into devBuild stage in devStages
    devBuild:
    # - if dockerfile param is not null insert containerImage job into devBuild stage
      - ${{ if parameters.dockerFile }}:
        - job: containerImage # job name must be unique within stage
          displayName: 'Build Container Image' # job display name
          pool: ${{ parameters.buildPool }} # param passed to pool of codAnalysis jobs
          dependsOn: [] # job does not depend on other jobs
        # variables:
          # key: 'value' # pairs of variables scoped to this job
          steps:
          # - task: add preSteps to containerImage job
          # - template: for containerImage steps
            - template: steps/build/containerImage.yaml
            # parameters within containerImage.yaml template
              parameters:
                dotNetProject: '${{ parameters.dotNetProject }}'
                containerRegistry: '${{ parameters.devRegistry }}'
                containerRepository: '${{ parameters.imageRepo }}/${{ parameters.imageName }}'
                twistlockEnabled: true # enable twistlock scan task
                twistlockContinue: true # twistlock vulnerabilities register as warning instead of error in dev stage
                dockerFile: '${{ parameters.dockerFile }}'
                dockerArgs: '${{ parameters.dockerArgs }}'
                dockerTags: ${{ parameters.dockerTags }}
          # - task: add postSteps to containerImage job
      # - job: insert additional jobs into the devBuild stage

  # devDeploy: deploymentList inserted into devDeploy stage in devStages
  # devPromote: deploymentList inserted into devPromote stage in devStages
  # devTests: jobList inserted into devTests stage in devStages

  # dintDeploy: deploymentList inserted into dintDeploy stage in dintStages
  # dintPromote: deploymentList inserted into dintPromote stage in dintStages
  # dintTests: jobList inserted into dintTests stage in dintStages

    acptBuild:
    # - if dockerfile param is not null insert containerImage job into acptBuild stage
      - ${{ if parameters.dockerFile }}:
        - job: containerImage # job name must be unique within stage
          displayName: 'Build Container Image' # job display name
          pool: ${{ parameters.buildPool }} # param passed to pool of codAnalysis jobs
          dependsOn: [] # job does not depend on other jobs
        # variables:
          # key: 'value' # pairs of variables scoped to this job
          steps:
          # - task: add preSteps to containerImage job
          # - template: for containerImage steps
            - template: steps/build/containerImage.yaml
            # parameters within containerImage.yaml template
              parameters:
                dotNetProject: '${{ parameters.dotNetProject }}'
                containerRegistry: '${{ parameters.acptRegistry }}'
                containerRepository: '${{ parameters.imageRepo }}/${{ parameters.imageName }}'
                dockerFile: '${{ parameters.dockerFile }}'
                dockerArgs: '${{ parameters.dockerArgs }}'
                dockerTags: ${{ parameters.dockerTags }}
          # - task: add postSteps to containerImage job
          # - template: steps/build/containerImage.yaml # build images serially by adding steps template multiple times
      # - job: insert additional jobs into the acptBuild stage

  # acptDeploy: deploymentList inserted into acptDeploy stage in acptStages
  # acptPromote: deploymentList inserted into acptPromote stage in acptStages
  # acptTests: jobList inserted into acptTests stage in acptStages

    prodBuild:
    # - if dockerfile param is not null insert containerImage job into prodBuild stage
      - ${{ if parameters.dockerFile }}:
        - job: containerImage # job name must be unique within stage
          displayName: 'Build Container Image' # job display name
          pool: ${{ parameters.buildPool }} # param passed to pool of codAnalysis jobs
          dependsOn: [] # job does not depend on other jobs
        # variables:
          # key: 'value' # pairs of variables scoped to this job
          steps:
          # - task: add preSteps to containerImage job
          # - template: for containerImage steps
            - template: steps/build/containerImage.yaml
            # parameters within containerImage.yaml template
              parameters:
                dotNetProject: '${{ parameters.dotNetProject }}'
                containerRegistry: '${{ parameters.prodRegistry }}'
                containerRepository: '${{ parameters.imageRepo }}/${{ parameters.imageName }}'
                dockerFile: '${{ parameters.dockerFile }}'
                dockerArgs: '${{ parameters.dockerArgs }}'
                dockerTags: ${{ parameters.dockerTags }}
          # - task: add postSteps to containerImage job
      # - job: insert additional jobs into the prodBuild stage

  # prodDeploy: deploymentList inserted into prodDeploy stage in prodStages
  # prodPromote: deploymentList inserted into prodPromote stage in prodStages
  # prodTests: jobList inserted into prodTests stage in prodStages

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
- name: containerRegistry # Nested into containerRegistry params in build job
  type: string
  default: 'ACR' # ADO Service Connection name
- name: dotNetProject # Required param to restore and publish a dotNet project
  type: string
  default: '**.csproj' # path or pattern match of projects to dotNet publish
- name: dockerFile # Nested into dockerFile of build jobs
  type: string
  default: '**.dockerfile' # path to dockerfile for docker build task
- name: dockerArgs # Nested into dockerArgs of build jobs
  type: string
  default: '' # optional to add --build-arg in docker build task
- name: imageRepo # repo path in registry
  type: string
  default: ''
- name: imageName # imageRepo/imageName nested into containerRepository of containerImage jobs
  type: string
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

stages:
- stage: build
  dependsOn: []
  jobs:
  - job: containerImage # job name must be unique within stage
    displayName: 'Build Container Image' # job display name
    pool: ${{ parameters.buildPool }} # param passed to pool of codAnalysis jobs
    dependsOn: [] # job does not depend on other jobs
    steps:
      - template: steps/build/containerImage.yaml@template # resource identifier required as this is not extending from pipeline.yaml
        parameters:
          dotNetProject: '${{ parameters.dotNetProject }}'
          containerRegistry: '${{ parameters.containerRegistry }}'
          containerRepository: '${{ parameters.imageRepo }}/${{ parameters.imageName }}'
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
    - repository: templates # Resource identitifier for template usage
      type: github
      name: fitchtech/AzurePipelines # This repository
      ref: refs/tags/v1 # The tagged release of the repository
      endpoint: GitHub # Azure Service Connection Name

steps:
- template: steps/build/containerImage.yaml@template # resource identifier required as this is not extending from pipeline.yaml
  parameters:
    dotNetProject: '**.csproj'
    containerRegistry: 'ACR'
    containerRepository: 'imageName'
    dockerFile: '**.dockerfile'
    dockerTags: $(Build.BuildNumber)

```
