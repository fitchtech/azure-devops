# Helm Chart Steps Template

- [Helm Chart Steps Template](#helm-chart-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)

## Steps Template Usage

- The helmChart steps template uses the 'helm install/upgrade' command to deploy helm charts directly to a Kubernetes cluster
- Alternatively the [helmManifest](helmManifest.md) steps template uses the 'helm template' command to render Helm charts into manifests which are deployed to Kubernetes

## Insert Steps Template into Stages Template

The following example shows how to insert the helmChart steps template into the [stages](../../stages.md) template with the minimum required params.

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
- name: kubeNamespace # Kubernetes Namespace for Helm Charts
  type: string
  default: default
- name: helmChartPath # helmChartPath within Pipeline.Workspace where charts are located
  type: string
  default: 'helm'
- name: helmValueFile # values file within helmChartPath
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
  template: stages.yaml@templates
# parameters: within stages.yaml@templates
  parameters:
  # code: jobList inserted into code stage in stages
  # build: jobList inserted into build stage in stages
  # deploy: deploymentList inserted into deploy stage in stages param
    deploy:
      - deployment: helmDeploy # job name unique to stage
        displayName: 'Deploy Helm Charts'
        pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
        condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        dependsOn: []
        strategy:
          runOnce:
            deploy:
              steps:
              - template: steps/deploy/helmChart.yaml
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
