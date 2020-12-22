# Helm Template Steps Template

- [Helm Template Steps Template](#helm-template-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Adding Steps into Pipeline Template](#adding-steps-into-pipeline-template)

## Steps Template Usage

- The 'helm template' command is used to render Helm charts into Kubernetes Manifests which are published as an artifact
- When using helmTemplate steps in a build job you can publish an artifact of the rendered manifests to later download by a deployment job

## Adding Steps into Pipeline Template

The following example shows how to insert the helmTemplate) steps template into the [pipeline](../../pipeline.md) template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into pipeline.yaml template:
- name: buildPool # Nested into pool param of build jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: namespace
  type: string
  default: default
- name: helmChartPath
  type: string
  default: 'helm'
- name: helmValueFile
  type: string
  default: 'values.yaml'

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

  # devBuild: jobList inserted into devBuild stage in devStages
    devBuild:
      - job: helmTemplate # job name unique to stage
        displayName: 'Render Helm Charts'
        pool: ${{ parameters.buildPool }} # param passed to pool of deployment jobs
        condition: succeeded()
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        dependsOn: []
        steps:
          - template: steps/build/helmTemplate.yaml
            parameters:
              namespace: ${{ parameters.namespace }} # pass in namespace param
              helmChartPath: '$(Pipeline.Workspace)/${{ parameters.helmChartPath }}' # helmChartPath within Pipeline.Workspace where charts are located
              helmValueFile: '$(Pipeline.Workspace)/${{ parameters.helmChartPath }}/${{ parameters.helmValueFile }}' # values file within helmChartPath
            # outputDir: '$(Pipeline.Workspace)/helmTemplate' # This is the default outputDir
            # publishEnabled: true # publish artifact of rendered manifests
        # - task: add postSteps to deployment job
    # - job: insert additional jobs into the devBuild stage
```
