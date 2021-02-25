# Helm Template Steps Template

- [Helm Template Steps Template](#helm-template-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)

## Steps Template Usage

- The 'helm template' command is used to render Helm charts into Kubernetes Manifests which are published as an artifact
- When using helmTemplate steps in a build job you can publish an artifact of the rendered manifests to later download by a deployment job

## Insert Steps Template into Stages Template

The following example shows how to insert the helmTemplate steps template into the [stages](../../stages.md) template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:
- name: buildPool # Nested into pool param of build jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: namespace
  type: string
  default: default
- name: helmChartPath # Optional path within Pipeline.Workspace
  type: string
  default: ''
- name: helmValueFile
  type: string
  default: 'values.yaml'

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
    build:
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
            # preSteps: 
              # - task: add preSteps into job
              namespace: ${{ parameters.namespace }} # pass in namespace param
              ${{ if parameters.helmChartPath }}:
                helmChartPath: '$(Build.Repository.LocalPath)/${{ parameters.helmChartPath }}' # helmChartPath within source checkout root path where charts are located
                helmValueFile: '$(Build.Repository.LocalPath)/${{ parameters.helmChartPath }}/${{ parameters.helmValueFile }}' # values file within helmChartPath
              ${{ if not(parameters.helmChartPath) }}:
                helmChartPath: '$(Build.Repository.LocalPath)' # default source checkout root path
                helmValueFile: '$(Build.Repository.LocalPath)/${{ parameters.helmValueFile }}' # values file within helmChartPath
            # outputDir: '$(Pipeline.Workspace)/helmTemplate' # This is the default outputDir
            # publishEnabled: true # default publish artifact of rendered manifests
            # postSteps:
              # - task: add postSteps into job

    # - job: insert additional jobs into the build stage

  # deploy: deploymentList inserted into deploy stage in stages param
  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```
