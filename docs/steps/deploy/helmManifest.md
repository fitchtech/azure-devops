# Helm Manifest Steps Template

- [Helm Manifest Steps Template](#helm-manifest-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)

## Steps Template Usage

- The 'helm template' command is used to render Helm charts into Kubernetes Manifests which are then deployed via the service connection
- This steps template nests [helmTemplate](../build/helmTemplate.md) and [kubeManifest](kubeManifest.md) steps templates

## Insert Steps Template into Stages Template

The following example shows how to insert the helmManifest steps template into the [stages](../../stages.md) template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:

- name: deployPool # Nested into pool param of deploy jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: kubeServiceConnection # Kubernetes Service Connection Name
  type: string
  default: ''
- name: kubeNamespace
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
      - deployment: helmDeploy # job name unique to stage
        displayName: 'Render Helm Charts and Deploy Manifests'
        pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
        condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        dependsOn: []
        strategy:
          runOnce:
            deploy:
              steps:
              - template: steps/deploy/helmManifest.yaml
                parameters:
                # preSteps: 
                  # - task: add preSteps into job
                  namespace: ${{ parameters.kubeNamespace }} # pass in namespace param
                  kubernetesServiceConnection: ${{ parameters.kubeServiceConnection }} # pass param for kube manifest deployment service connection
                  helmChartPath: '$(Pipeline.Workspace)/${{ parameters.helmChartPath }}' # helmChartPath within Pipeline.Workspace where charts are located
                  helmValueFile: '$(Pipeline.Workspace)/${{ parameters.helmChartPath }}/${{ parameters.helmValueFile }}' # values file within helmChartPath
                # postSteps:
                  # - task: add postSteps into job

    # - deployment: insert additional deployment jobs into the deploy stage

  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```
