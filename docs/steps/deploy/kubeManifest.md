# Kubernetes Manifest Steps Template

- Deploy Kubernetes Manifests to the Kubernetes Service Connection or ADO Environment Resource
- Deploy standard or canary pods for deployment manifests
- Create/update image pull secret using docker and kubernetes service connection
- Bake Kustomize, Docker Compose, or Helm2 charts that are then deployed
- Scale an existing replica set
- Delete a Kubernetes object
- Create Kubernetes secrets from Azure KeyVault Secrets

## Kubernetes Manifest Steps in Pipeline Template

The following example shows how to insert the kubeManifest steps template into the [pipeline](../../pipeline.md) template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into pipeline.yaml template:

- name: deployPool # Nested into pool param of deploy jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: devRegistry # Nested into containerRegistry params in devBuild and dintBuild jobs
  type: string
  default: '' # ADO Service Connection name
- name: devKubernetes # Kubernetes Service Connection Name
  type: string
  default: ''
- name: namespace
  type: string
  default: default
- name: kubeManifests # Deployment manifest for canary deploy, promote, and reject jobs
  type: string
  default: '$(Pipeline.Workspace)/deployment.yaml'

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
      - deployment: kubeDeploy # job name unique to stage
        displayName: 'Canary Deployment'
        pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
        condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        dependsOn: []
        strategy:
          runOnce:
            deploy:
              steps:
              - template: steps/deploy/kubeManifest.yaml
                parameters:
                  namespace: ${{ parameters.namespace }} # pass in namespace param
                  imagePullSecret: 'harbor-cred'
                  dockerRegistryEndpoint: ${{ parameters.devRegistry }}
                  kubernetesServiceConnection: ${{ parameters.devKubernetes }} # pass param for kube manifest deployment service connection
                  kubeAction: deploy
                  kubeStrategy: canary
                  kubeManifests: ${{ parameters.kubeManifests }}

    devPromote:
      - deployment: kubePromote # job name unique to stage
        displayName: 'Promote Canary Deployment'
        pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
        condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        dependsOn: []
        strategy:
          runOnce:
            deploy:
              steps:
              - template: steps/deploy/kubeManifest.yaml
                parameters:
                  namespace: ${{ parameters.namespace }} # pass in namespace param
                  kubernetesServiceConnection: ${{ parameters.devKubernetes }} # pass param for kube manifest deployment service connection
                  kubeAction: promote
                  kubeStrategy: canary
                  kubeManifests: ${{ parameters.kubeManifests }}
      - deployment: kubeReject # job name unique to stage
        displayName: 'Reject Canary Deployment'
        pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
        condition: and(failed(), ne(variables['Build.Reason'], 'PullRequest'))
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        dependsOn: kubePromote
        strategy:
          runOnce:
            deploy:
              steps:
              - template: steps/deploy/kubeManifest.yaml
                parameters:
                  namespace: ${{ parameters.namespace }} # pass in namespace param
                  kubernetesServiceConnection: ${{ parameters.devKubernetes }} # pass param for kube manifest deployment service connection
                  kubeAction: reject
                  kubeStrategy: canary
                  kubeManifests: ${{ parameters.kubeManifests }}

            # - task: add postSteps to deployment job
    # - deployment: insert additional deployment jobs into the devDeploy stage
```
