# Helm Chart Steps Template

- The helmChart steps template uses the 'helm install/upgrade' command to deploy helm charts directly to a Kubernetes cluster
- Alternatively the [helmManifest](helmManifest.md) steps template uses the 'helm template' command to render Helm charts into manifests which are deployed to Kubernetes

## Helm Chart Steps in Pipeline Template

The following example shows how to insert the helmChart steps template into the [pipeline](../../pipeline.md) template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into pipeline.yaml template:

- name: deployPool # Nested into pool param of deploy jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: devKubernetes # Kubernetes Service Connection Name
  type: string
  default: ''
- name: namespace # Kubernetes Namespace for Helm Charts
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
                  namespace: ${{ parameters.namespace }} # pass in namespace param
                  helmChartPath: '$(Pipeline.Workspace)/${{ parameters.helmChartPath }}' # helmChartPath within Pipeline.Workspace where charts are located
                  helmValueFile: '$(Pipeline.Workspace)/${{ parameters.helmChartPath }}/${{ parameters.helmValueFile }}' # values file within helmChartPath
                  kubernetesServiceConnection: ${{ parameters.devKubernetes }} # pass param for kube manifest deployment service connection

            # - task: add postSteps to deployment job
    # - deployment: insert additional deployment jobs into the devDeploy stage
```
