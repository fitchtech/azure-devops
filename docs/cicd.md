# Azure Pipeline Templates

- [Azure Pipeline Templates](#azure-pipeline-templates)
  - [Template Parameter Schema](#template-parameter-schema)
  - [Pipeline Template](#pipeline-template)

## Template Parameter Schema

```yaml
extends:
  # file path to template at repo resource id to extend from
  template: presets/cicd.yaml@templates
  parameters:
# code: stage in stages
  # dotNetTests: list of projects for dotNet test task of each item
    dotNetTests:
      - projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # Pattern search for unit test projects
        arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
        displayName: 'dotNet Unit Tests'
      - projects: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj' # Pattern search for cli test projects
        arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
        displayName: 'dotNet CLI Tests'
# build: stage in stages
  # dockerFiles: list of docker build jobs. Job, dockerFile, containerRegistry, and containerRepository, required for each
    dockerFiles:
      - job: containerImage1
        dockerFile: App1.Dockerfile
        containerRegistry: 'Docker' # Optional override of dockerRegistry parameter. Container registry service connection name
        containerRepository: 'App1' # Optional path within registry that overrides dockerRepository param. registry/repository/name:tag
      - job: containerImage2
        dependsOn: containerImage1
        dockerFile: App2.Dockerfile
        containerRegistry: 'Docker' # Optional override of dockerRegistry parameter. Container registry service connection name
        containerRepository: 'App2' # Optional path within registry that overrides dockerRepository param. registry/repository/name:tag
        dockerArgs: '--build-arg repository=baseimages/dotnet/core/aspnet'
        dockerTags: '$(Build.BuildNumber)' # Optional list of image tags. Default is $(Build.BuildNumber)
# deploy: stage in stages
    armTemplates:
      - deployment: 'armTemplate1' # Required: deployment name must be unique
        template: 'deployment1.json' # Required: ARM template file name
        parameters: 'parameters1.json' # Optional: ARM parameters file name
      - deployment: 'armTemplate2'
        template: 'deployment2.json'
        parameters: 'parameters2.json'
      - deployment: 'armTemplate3' # Required: deployment name must be unique
        template: 'deployment3.json'
        parameters: 'parameters3.json'
        subscription: 'subscriptionServiceConnectionName'
        resourceGroup: 'resourceGroupName'
      # dependsOn: Optional list of dependencies. Example of armTemplate3 depending on armTemplate1 and armTemplate2 succeeding
        dependsOn:
          - armTemplate1
          - armTemplate2
      # Insert steps for deployment strategy lifecycle hooks of the deployment
        preDeploy:
          - script: echo add stepList of tasks into preDeploy steps lifecycle hook
        routeTraffic:
          - script: echo add stepList of tasks into routeTraffic steps lifecycle hook
        postRouteTraffic:
          - script: echo add stepList of tasks into postRouteTraffic steps lifecycle hook
        onFailure:
          - script: echo add stepList of tasks into on failure steps lifecycle hook
        onSuccess:
          - script: echo add stepList of tasks into on failure steps lifecycle hook
    kubeDeployments:
      - deployment: kubeDeploy
        kubeServiceConnection: 'serviceConnectionName'
        kubeManifests: 'deployment.yaml'
        kubeAction: deploy
        kubeStrategy: canary
      # Insert steps for deployment strategy lifecycle hooks of the deployment
        preDeploy:
          - script: echo add stepList of tasks into preDeploy steps lifecycle hook
        routeTraffic:
          - script: echo add stepList of tasks into routeTraffic steps lifecycle hook
        postRouteTraffic:
          - script: echo add stepList of tasks into postRouteTraffic steps lifecycle hook
        onFailure:
          - script: echo add stepList of tasks into on failure steps lifecycle hook
        onSuccess:
          - script: echo add stepList of tasks into on failure steps lifecycle hook

```

## Pipeline Template

This repository stores templates to be used by azure-pipelines. It is recommended that you extend from the pipeline.yaml template.

To use the pipeline templates in this repository it must be listed as a resource in your pipeline YAML file. This allows you to reference paths in another repository by using the resource identifier.

```yaml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

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
  # file path to template at repo resource id to extend from
  template: presets/cicd.yaml@templates
  parameters:
    dotNetTests:
      - projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # Pattern search for unit test projects
        arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
        displayName: 'dotNet Unit Tests'
      - projects: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj' # Pattern search for cli test projects
        arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
        displayName: 'dotNet CLI Tests'
    dockerFiles:
      - job: containerImage1
        dockerFile: App1.Dockerfile
        containerRegistry: 'Docker' # Optional override of dockerRegistry parameter. Container registry service connection name
        containerRepository: 'App1' # Optional path within registry that overrides dockerRepository param. registry/repository/name:tag
      - job: containerImage2
        dependsOn: containerImage1
        dockerFile: App2.Dockerfile
        containerRegistry: 'Docker' # Optional override of dockerRegistry parameter. Container registry service connection name
        containerRepository: 'App2' # Optional path within registry that overrides dockerRepository param. registry/repository/name:tag
        dockerArgs: '--build-arg repository=baseimages/dotnet/core/aspnet'
        dockerTags: '$(Build.BuildNumber)' # Optional list of image tags. Default is $(Build.BuildNumber)
    armTemplates:
      - deployment: 'armTemplate1' # deployment name must be unique
        template: 'deployment1.json'
        parameters: 'parameters1.json'
      - deployment: 'armTemplate2' # deployment name must be unique
        template: 'deployment2.json'
        parameters: 'parameters2.json'
      - deployment: 'armTemplate3' # deployment name must be unique
        template: 'deployment3.json'
        parameters: 'parameters3.json'
        subscription: 'subscriptionServiceConnectionName'
        resourceGroup: 'resourceGroupName'
        # Example when armTemplate3 dependsOn armTemplate1 and armTemplate2 succeeded
        dependsOn:
          - armTemplate1
          - armTemplate2



```
