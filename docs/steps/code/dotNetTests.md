# dotNet Test Steps Template

- [dotNet Test Steps Template](#dotnet-test-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Steps Template Schema](#steps-template-schema)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)
  - [Direct Steps Template Usage](#direct-steps-template-usage)

## Steps Template Usage

- The dotNetTests param within the dotNetTests steps template is a YAML object param that allows you to list multiple dotNet tests projects and arguments
  - A dotNet test task is inserted for each item in the dotNetTests list
- In the [stages](../../stages.md) Template code jobList param you can add multiple jobs for static code analysis so long as the job name is unique within the stage

## Steps Template Schema

```yml
steps:
# - template: for code analysis steps
  - template: steps/code/dotNetTests.yaml
  # parameters: within dotNetTests.yaml template
    parameters:
    # preSteps: Optional: inserts stepList after checkout and download
      preSteps: 
        - script: echo add stepList of tasks into steps
    # dotNetTests: Required: list of dotNet test tasks that are inserted serially into steps
      dotNetTests:
      # - projects: at least one projects item required at minimum
        - projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # Required: The path to the csproj file(s) to use. You can use wildcards and file matching pattern
          arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\' # Optional: dotNet Test arguments
          displayName: 'dotNet Unit Tests' # Optional: Pipeline task display name
      # - projects: item for each dotNet test task to be inserted
        - projects: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj' # Pattern search test projects
          arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'  # Optional: dotNet Test arguments
          displayName: 'dotNet CLI Tests' # Optional: Pipeline task display name
          testRunTitle: 'CLI Test' # Optional: Provides a name for the test run
          publishTestResults: true # Optional: default is false. Enabling this option will generate a test results TRX file in $(Agent.TempDirectory) and results will be published

      dotNetProjects: '*.sln' # Optional: File matching pattern to Visual Studio solution (*.sln) or dotNet project (*.csproj) to restore. Useful when there's many tests in a solution or publish artifacts of dotNet after tests
      dotNetVersion: '3.1.x' # Optional: if param has value, use dotNet version task inserted
      dotNetFeed: '' # Optional: GUID of Azure artifact feed. Use when projects restore NuGet artifacts from a private feed
      dotNetArguments: '' # Optional: Additional arguments for dotNetProjects if dotNetCommand is build or publish. Excluding '--no-restore' and '--output' as they are predefined
      dotNetCommand: restore # restore (default) | build | publish
      publish: '' # Default: $(Common.TestResultsDirectory) | publish: '' will disable the publish task
      publishArtifact: 'artifactName' # Default: $(Build.DefinitionName)_$(System.JobName)
    # postSteps: Optional: inserts stepList before publish and clean
      postSteps: 
        - script: echo add stepList of tasks into steps

```

## Insert Steps Template into Stages Template

The following example shows how to insert the dotNetTests steps template into the stages.yaml template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:
- name: codePool
  type: object
  default:
    vmImage: 'windows-latest' # Nested into pool param of code jobs
- name: dotNetTests
  type: object
  default:
  - displayName: 'dotNet Unit Tests'
    projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # Pattern search for unit test projects
    arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
  - displayName: 'dotNet CLI Tests'
    projects: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj' # Pattern search for cli test projects
    arguments: '--no-restore --collect "Code Coverage"'
- name: dotNetProjects # Optional param, nested into dotNetProjects param of dotNetTests steps. Can be Visual Studio solution (*.sln) or dotNet projects (*.csproj) to restore for multiple tests.
  type: string
  default: ''

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
    code:
    # - job: insert static code analysis jobs into stage
      - job: dotNetTests # job name must be unique within stage
        displayName: 'dotNet Test Static Code Analysis' # job display name
        pool: ${{ parameters.codePool }} # param passed to pool of code jobs
        dependsOn: [] # job does not depend on other jobs
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        steps:
        # - template: for code analysis steps
          - template: steps/code/dotNetTests.yaml
          # parameters within dotNetTests.yaml template
            parameters:
            # preSteps: 
              # - task: add preSteps into job
              dotNetTests: ${{ parameters.dotNetTests }}
              dotNetProjects: ${{ parameters.dotNetProjects }}
            # postSteps:
              # - task: add postSteps into job

    # - job: insert additional jobs into the code stage

  # build: jobList inserted into build stage in stages param
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
# params to pass into stages.yaml template:
- name: unitTests # param nested
  type: string
  default: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj'
- name: cliTests # param nested
  type: string
  default: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj'
- name: testArgs
  type: string
  default: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
- name: codePool
  type: object
  default:
    vmImage: 'windows-latest' # Nested into pool param of code job

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
- stage: code
  dependsOn: []
  jobs:
  - job: dotNetTests # job name must be unique within stage
    displayName: 'dotNet Test Static Code Analysis' # job display name
    pool: ${{ parameters.codePool }} # param passed to pool of code jobs
    dependsOn: [] # job does not depend on other jobs
    steps:
      - template: steps/code/dotNetTests.yaml@template # resource identifier required as this is not extending from stages.yaml
        parameters:
        # preSteps: 
          # - task: add preSteps into job
          dotNetTests:
          - projects: '${{ parametes.unitTests }}' # Pattern search for unit test projects
            displayName: 'dotNet Unit Tests'
            arguments: '${{ parametes.testArgs }}'
          - projects: '${{ parametes.cliTests }}' # Pattern search for cli test projects
            displayName: 'dotNet CLI Tests'
            arguments: '${{ parametes.testArgs }}'
        # postSteps:
          # - task: add postSteps into job
# You can customize a list using this pattern

```
