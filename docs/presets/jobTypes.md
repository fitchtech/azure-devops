# Azure Pipeline Templates

- [Azure Pipeline Templates](#azure-pipeline-templates)
  - [Preset Use Case](#preset-use-case)
  - [Template Resource](#template-resource)
  - [Stages Template](#stages-template)
  - [Template Schema](#template-schema)
  - [Job Type Parameters](#job-type-parameters)
    - [Code: dotNetTests](#code-dotnettests)
    - [Code: sonarQubeAnalyses](#code-sonarqubeanalyses)
    - [Build: dockerBuilds](#build-dockerbuilds)
    - [Build: dotNetBuilds](#build-dotnetbuilds)
    - [Deploy: armDeployments](#deploy-armdeployments)
    - [Deploy: kubeDeployments](#deploy-kubedeployments)

## Preset Use Case

This preset uses parameters based on a job type that conditionally inserts, for each item in the list, predefined jobs and steps templates into the jobList parameter for a stage in the [stages](../stages.md) template. For example, each item in the 'dockerBuilds' parameter inserts a job into the build jobList parameter of the stages.yaml template. This allows you to provide a list of 'dockerBuilds' that creates a job for each 'dockerFile' in the build stage that can run in parallel or with dependencies.

This is a prescriptive and opinionated preset template. In that, it abstracts the stages, jobs, and steps templates using a predefined pattern that is common for building and deploying infrastructure and applications. Pipelines that use this preset provide a simple parameter list of items for 'dotNetTests', 'sonarQubeAnalyses', 'dockerBuilds', 'armDeployments', 'kubeDeployments', etc.

## Template Resource

To use the pipeline templates in this repository it must be listed as a resource in your pipeline YAML file. This allows you to reference paths in another repository by using the resource identifier.

```yaml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

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
```

## Stages Template

This preset uses the [stages](../stages.md) template to insert jobs into a jobsList for predefined stages. It inherrits the default stages in the stageList of the stages template. The defaults as shown in the example below. To override those defaults use the stages parameter, however the entire list object needs defined and stage names exactly as shown. If a stage is omitted then the stage and its jobs are not inserted. You do not need to set the stages parameter if the defaults are acceptable.

This example shows nesting a stages parameter into the preset template with default stages. This is useful if you want to modify any of the dependsOn or condition of a stage. You could also add variables scoped to a stage and additional stages and jobs.

```yaml
parameters:
- name: stages # Inserts each stage into stages
  type: stageList
  default:
  - stage: code # code jobList param inserted to this stage
    dependsOn: []
    condition: and(succeeded(), eq(variables['build.reason'], 'PullRequest', 'Manual'))
  - stage: build # build jobList param inserted to this stage
    dependsOn: code
    condition: and(succeeded(), in(variables['build.reason'], 'IndividualCI', 'BatchedCI', 'ResourceTrigger', 'Manual'))
  - stage: deploy # deploy jobList param inserted to this stage
    dependsOn: build
    condition: and(succeeded(), in(variables['build.reason'], 'IndividualCI', 'BatchedCI', 'ResourceTrigger', 'Manual'))
  - stage: test # test jobList param inserted to this stage
    dependsOn:
      - build
      - deploy
    condition: succeeded()
  - stage: promote # promote jobList param inserted to this stage
    dependsOn:
      - deploy
      - test
    condition: and(succeeded(), in(variables['build.reason'], 'IndividualCI', 'BatchedCI', 'ResourceTrigger', 'Manual'))
  - stage: reject
    dependsOn:
      - deploy
      - test
      - promote
    condition: failed()
- name: stagesSuffix # Optional stage name suffix. e.g. Dev would make buildDev, deployDev, etc.
  type: string
  default: ''
- name: stagesPrefix # Optional stage name prefix. e.g. dev- would make dev-build, dev-deploy, etc.
  type: string
  default: ''
- name: stagesCondition # Optional param to override the condition of all stages
  type: string
  default: ''

extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
    stages: ${{ parameters.stages }}
    stagesPrefix: ${{ parameters.stagesPrefix }}
    stagesSuffix: ${{ parameters.stagesSuffix }}
    stagesCondition: ${{ parameters.stagesCondition }}
```

## Template Schema

The parameters [dotNetTests](#code-dotnettests), [sonarQubeAnalyses](#code-sonarqubeanalyses), [dockerBuilds](#build-dockerbuilds), [dotNetBuilds](#build-dotnetbuilds), [armDeployments](#deploy-armdeployments), and [kubernetesDeployments](#deploy-kubedeployments) are list objects that allows you to set all the job properties and all the parameters for the steps template it uses. Not all the parameters for each job type are shown below. Reference the parameters listed in the corresponding steps template file for a complete list.

```yaml
extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
    stages: '' # stageList | optional override default stages
    stagesPrefix: '' # string | optionally add prefix to stage names
    stagesSuffix: '' # string | optionally add suffix to stage names
    stagesCondition: true # string | optional override condition of all stages
  # dotNetTests: list of jobs for steps/code/dotNetTests.yaml with all params for each job
    dotNetTests:
      - job: test1
        projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # file match pattern
        arguments: '--collect "Code Coverage"'
    dotNetTestProjects: '' # string | alternative to parameters.dotNetTests when you have a single test job
    dotNetTestArguments: '' # string | default dotNet test arguments for all jobs
  # sonarQubeAnalyses: list of jobs for steps/code/sonarQube.yaml with all params for each job
    sonarQubeAnalyses:
      - job: sonarQube1 # Job name must be unique in code stage
        sonarQube: serviceConnectionName # Use either sonarQube or sonarCloud parameter, not both.
      # sonarCloud: serviceConnectionName
        projectKey: projectKey # The SonarQube project unique key, i.e. 'sonar.projectKey'
        projectName: projectName # The SonarQube project name, i.e. 'sonar.projectName'
        projectVersion: $(Build.BuildNumber)
        dotNetProjects: '$(Build.Repository.LocalPath)/project1.csproj'
    codePool:
      vmImage: 'windows-latest' # This is the default pool for all code stage jobs. Use param to override default
    containerRegistry: '' # string | default registry service connection for all docker build jobs
    containerRepository: '' # string | default repository within registry for all docker build jobs
    dockerTags: $(Build.SourceBranchName) # list object of docker tags for image
    dockerArgs: '' # string | default docker build arguments for all docker build jobs
    dockerContext: $(Build.Repository.LocalPath) # this is the default context. Use param to override
    dockerFile: '' # string | Use when you have a single docker file and single build job.
  # dockerBuilds: list of jobs for steps/build/containerImage.yaml with all params for each job
    dockerBuilds:
      - job: containerImage
        dependsOn: dotNetPublish # add dependsOn for other jobs in deploy stage
        dockerFile: Dockerfile
        containerRegistry: DockerHub # Optional override of containerRegistry parameter. Container registry service connection name
        containerRepository: repoName # Optional path within registry that overrides containerRepository param. registry/repository/name:tag
        dockerArgs: '--build-arg repository=dotnet/aspnet' # Optional docker build arguments
        dockerTags: '$(Build.DefinitionName)' # Optional list of image tags
  # dotNetBuilds: list of jobs for steps/build/dotNetCore.yaml with all params for each job
    dotNetBuilds:
      - job: nuGetPackage
        searchPatternPack: '$(Build.Repository.LocalPath)/client.csproj'
        includeSymbols: true # Enable dotNet pack includeSymbols
        publishSymbols: true # Enable Publish Symbols task after dotNet pack
        feedPublish: feedName # dotNet push feed to publish of dotNet pack output NuGet package
      - job: dotNetPublish
        dependsOn: nuGetPackage
        projects: '$(Build.Repository.LocalPath)/server.csproj'
        command: publish # Overrides the default parameters.dotNetCommand: build
    dotNetProjects: '' # string | Use when you have a single dotNet projects file pattern and single build job.
    dotNetCommand: publish # build (default) or publish | default command for all dotNet build jobs 
    buildPool:
      vmImage: 'Ubuntu-16.04' # This is the default pool for all build stage jobs. Use param to override default
    buildCheckout: self # default repository resource to checkout for all build jobs
    armSubscription: serviceConnectionName # Default service connection for all ARM template deployment jobs
    armResourceGroup: 'resourceGroupName' # string | default resource group for all ARM deployment jobs
  # armDeployments: list of jobs for steps/deploy/armTemplate.yaml with all params for each job
    armDeployments:
      - deployment: armTemplate1 # Required: deployment name must be unique
        template: 'deployment1.json' # Required: ARM template file name
        parameters: 'parameters1.json' # Optional: ARM parameters file name
    kubernetesServiceConnection: serviceConnectionName # Default service connection for all kubernetes deployment jobs
  # kubernetesDeployments: list of jobs for steps/deploy/kubeManifest.yaml with all params for each job
    kubernetesDeployments:
      - deployment: kubeDeploy
        kubeServiceConnection: 'serviceConnectionName'
        manifests: '$(Build.Repository.LocalPath)/deployment.yaml'
        action: deploy
        strategy: canary
    kubernetesCanaryIncrements: 10 # default increments when using strategy: canary
    kubernetesNamespace: namespace # default kubernetes namespace for all kubernetes deployments
    kubernetesCanaryPromote: true # default when using kubernetes canary deployment strategy inserts promote job. Set false to disable job
    kubernetesCanaryReject: true # default when using kubernetes canary deployment strategy inserts reject job. Set false to disable job
    deployPool:
      vmImage: 'ubuntu-18.04' # This is the default pool for all deploy, promote, and reject stage jobs. Use param to override default
    deployCheckout: self # default repository resource to checkout for all deployment jobs
    vsTests:
      - job: vsTest
        testPlan: 123456
        testSuite: 123456
        testConfiguration: 523
        strategy:
          parallel: 10
    testPlan:
    testSuite:
    testConfiguration:
    testPool:

```

## Job Type Parameters

### Code: dotNetTests

The 'dotNetTests' parameter within this preset template provides a few patterns for defining tests. Depending on if you require a single job with a single test task and dotNet projects pattern, a single job with multiple test tasks run sequentially, or multiple jobs with one or more dotNet projects each.

This example is of a single job with a single dotNet test task for a projects file match pattern.

```yaml
extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
# code: these parameters insert jobs into this stage in the stages.yaml template
  # dotNetTests: list of projects for dotNet test task of each item
    dotNetTests:
    - job: test1
      displayName: 'dotNet Unit Tests'
      version: '3.1.x' # Inserts use dotNet 3.1.x task
      projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # Pattern search for unit test projects
      arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
```

This example is of a single job with multiple test tasks run serially.

```yaml
extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
# code: these parameters insert jobs into this stage in the stages.yaml template
  # dotNetTests: list of projects for dotNet test task of each item
    dotNetTests:
    - job: test1
      displayName: 'dotNet Test Job'
      tests:
      - projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # Pattern search for unit test projects
        arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
        displayName: 'dotNet Unit Tests Task'
      - projects: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj' # Pattern search for cli test projects
        arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
        displayName: 'dotNet CLI Tests Task'
```

This example is of multiple jobs with a single test task.

```yaml
extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
# code: these parameters insert jobs into this stage in the stages.yaml template
  # dotNetTests: list of projects for dotNet test task of each item
    dotNetTests:
    - job: test1
      displayName: 'dotNet Unit Tests'
      projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # Pattern search for unit test projects
      arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
    - job: test2
      displayName: 'dotNet CLI Tests'
      projects: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj' # Pattern search for cli test projects
      arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
```

### Code: sonarQubeAnalyses

The 'sonarQubeAnalyses' parameter within this preset template is a list of SonarQube or SonarCloud jobs inserted into the code stage. Prepares SonarQube with service connection, build dotNet projects, then analyize those dotNet builds. The report is published to the service connection.

This example is of a single job with a single dotNet test task for a projects file match pattern.

```yaml
extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
# code: these parameters insert jobs into this stage in the stages.yaml template
  # sonarQubeAnalyses: list of jobs for SonarQube or SonarCloud analysis of dotNet build projects
    sonarQubeAnalyses:
      - job: sonarQube1 # Job name must be unique in code stage
        sonarQube: serviceConnectionName # Use either sonarQube or sonarCloud parameter, not both. Depending on if you're using SonarCloud or self-hosted SonarQube service connection
      # sonarCloud: serviceConnectionName
        projectKey: projectKey # The SonarQube project unique key, i.e. 'sonar.projectKey'
        projectName: projectName # The SonarQube project name, i.e. 'sonar.projectName'
        projectVersion: $(Build.BuildNumber)
        dotNetProjects: '$(Build.Repository.LocalPath)/project1.csproj'
      - job: sonarQube2
        sonarQube: serviceConnectionName # Use either sonarQube or sonarCloud parameter, not both. Depending on if you're using SonarCloud or self-hosted SonarQube service connection
      # sonarCloud: serviceConnectionName
        projectKey: projectKey # The SonarQube project unique key, i.e. 'sonar.projectKey'
        projectName: projectName # The SonarQube project name, i.e. 'sonar.projectName'
        dotNetProjects: '$(Build.Repository.LocalPath)/project2.csproj'
```

### Build: dockerBuilds

```yaml
variables:
  buildVersion: $[counter(variables['Build.SourceVersion'], 1)] # Example variable used for a docker tag of image

extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
# build: these parameters insert jobs into this stage in the stages.yaml template
    containerRegistry: DockerHub # default container registry service connection for all jobs
  # dockerBuilds: list of docker build jobs. Job, dockerFile, and containerRepository required per item
    dockerBuilds:
      - job: containerImage1
        dockerFile: App1.Dockerfile
        containerRepository: 'App1' # Optional path within registry that overrides containerRepository param. registry/repository/name:tag
      - job: containerImage2
        dependsOn: containerImage1 # Omit dependsOn to run jobs in parallel
        dockerFile: App2.Dockerfile
        containerRegistry: 'ACR' # Optional override of containerRegistry parameter. Container registry service connection name
        containerRepository: 'App2' # Optional path within registry that overrides containerRepository param. registry/repository/name:tag
        dockerArgs: '--build-arg repository=dotnet/aspnet' # Optional docker build arguments
        dockerTags: '$(buildVersion)' # Optional list of image tags. Default is $(Build.BuildNumber)
```

### Build: dotNetBuilds

The 'dotNetBuilds' parameter is a list of jobs with projects to dotNet build or dotNet publish. The output files from dotNet build or publish are published as Azure Pipeline artifacts that can be downloaded by other jobs.

It can be useful to build and publish dotNet artifacts prior to Docker build jobs versus doing dotNet build command as part of a Docker multi-stage image. While Docker multi-stage build with dotNet steps can be useful for development environment it uses more resources and time for cases where your code has not changed from the prior build but need to run the docker build job again to update the images it's built from. For example, in a production environment that needs to pull updates from upstream images or run steps to update packages or dependencies. Where a scheduled or manual run of the pipeline to update the base image and the source repository code has not changed since the last run. Therefore needing to do a dotNet build each time is a waste of resources.

Instead, you could decouple the pipeline into multiple pipelines and use pipeline resources to download the latest artifact. One pipeline to do code analysis, dotNet build, and artifact publish. Another pipeline with a resource for the first pipeline. This allows you to use pipeline completion triggers and download the artifacts published by that pipeline. Which downloads the dotNet artifact to be copied into the docker build versus doing the dotNet build within the Dockerfile steps.

Alternatively you could have one pipeline where the docker build jobs depends on the dotNet publish jobs. However, if the dotNet jobs are conditional and do not execute then the dependant docker build job would not run. To work around that you could use expressions to conditionally insert the dependency. Though that can be more difficult to impliment than decoupling into multiple pipelines.

```yaml
variables:
  NugetVersion: $[counter(variables['Build.SourceVersion'], 1)] # Environment variable used for dotNet pack NuGet versioningScheme: byEnvVar

extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
# build: these parameters insert jobs into this stage in the stages.yaml template
  # dotNetBuilds: list of dotNet build/publish jobs. Job and projects are required per item
    dotNetBuilds:
      - job: dotNetPublish
        projects: '$(Build.Repository.LocalPath)/server.csproj'
        command: publish # Overrides the default parameters.dotNetCommand: build
        version: '3.1.x' # Optional, inserts use dotNet task for version
      - job: nuGetPackage
        searchPatternPack: '$(Build.Repository.LocalPath)/client.csproj'
        includeSymbols: true # Enable dotNet pack includeSymbols
        publishSymbols: true # Enable Publish Symbols task after dotNet pack
        feedPublish: feedName # dotNet push feed to publish of dotNet pack output NuGet package
        version: '3.1.x' # Optional, inserts use dotNet task for version
      # searchPatternPush: '$(Build.ArtifactStagingDirectory)/*.nupkg' # Optional param, this is the default
      # versioningScheme: byEnvVar # byEnvVar (default) | byPrereleaseNumber | byBuildNumber
      # versionEnvVar: NugetVersion # The default is NugetVersion. Use this param to set other variable name for version
```

### Deploy: armDeployments

```yaml
extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
# deploy: these parameters insert jobs into this stage in the stages.yaml template
    armDeployments:
      - deployment: armTemplate1 # Required: deployment name must be unique
        template: 'deployment1.json' # Required: ARM template file name
        parameters: 'parameters1.json' # Optional: ARM parameters file name
      - deployment: armTemplate2
        template: 'deployment2.json'
        parameters: 'parameters2.json'
      - deployment: armTemplate3 # Required: deployment name must be unique
        template: 'deployment3.json'
        parameters: 'parameters3.json'
        subscription: subscriptionServiceConnectionName
        resourceGroup: resourceGroupName
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
```

### Deploy: kubeDeployments

```yaml
extends:
  template: presets/jobTypes.yaml@templates # file path to the template at repo resource id to extend from
  parameters:
# deploy: these parameters insert jobs into this stage in the stages.yaml template
    kubeDeployments:
      - deployment: kubeDeploy
        kubeServiceConnection: 'serviceConnectionName'
        manifests: '$(Build.Repository.LocalPath)/deployment.yaml'
        action: deploy
        strategy: canary
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
# promote: automatically inserts job for each deployment in kubeDeployments if strategy: canary
  # - deployment: promotes canary to baseline if all jobs in dependant stages are successful
# reject: automatically inserts job for each deployment in kubeDeployments if strategy: canary
  # - deployment: rejects canary if any job in dependant stages failed or pods do not go into a ready state
```
