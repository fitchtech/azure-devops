# Code Analysis Steps Template

- [Code Analysis Steps Template](#code-analysis-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Adding Steps into Pipeline Template](#adding-steps-into-pipeline-template)
  - [Direct Steps Template Usage](#direct-steps-template-usage)

## Steps Template Usage

- In the [Pipeline](../../pipeline.md) Template codeAnalysis jobList param you can add multiple jobs for static code analysis so long as the job name is unique within the stage
- The codeAnalysis steps template provides options for adding SonarQube analysis and multiple dotNet tests
- The dotNetTests param within the codeAnalysis steps template is a YAML object param that allows you to list projects and arguments
  - A dotNet test task is inserted for each item in the dotNetTests list

## Adding Steps into Pipeline Template

The following example shows how to insert the codeAnalysis steps template into the pipeline.yaml template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into pipeline.yaml template:
- name: codePool
  type: object
  default:
    vmImage: 'windows-latest' # Nested into pool param of codeAnalysis job
- name: dotNetTests
  type: object
  default:
  - displayName: 'dotNet Unit Tests'
    projects: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj' # Pattern search for unit test projects
    arguments: '--collect "Code coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
  - displayName: 'dotNet CLI Tests'
    projects: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj' # Pattern search for cli test projects
    arguments: '--no-restore --collect "Code Coverage"'

# SonarQube Analysis extension for Azure Pipelines
- name: sonarQube # Required sonarQube Service Connection name to insert steps
  type: string
  default: ''
- name: dotNetProjects # Nested into dotNetProjects param of codeAnalysis steps. Can be Visual Studio solution (*.sln) or dotNet projects (*.csproj) to build for SonarQube analysis
  type: string
  default: '*.sln'

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
  # code: jobList inserted into code stage in stages
    code:
    # - job: insert static code analysis jobs into stage
      - job: codeAnalysis # job name must be unique within stage
        displayName: 'Static Code Analysis' # job display name
        pool: ${{ parameters.codePool }} # param passed to pool of codAnalysis jobs
        dependsOn: [] # job does not depend on other jobs
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        steps:
        # - template: for code analysis steps
          - template: steps/code/analysis.yaml
          # parameters within analysis.yaml template
            parameters:
            # preSteps: 
              # - task: add preSteps into job
              dotNetTests: ${{ parameters.dotNetTests }}
              ${{ if parameters.sonarQube }}:
                sonarQube: ${{ parameters.sonarQube }}
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
# params to pass into pipeline.yaml template:
- name: unitTests # param nested
  type: string
  default: '**[Uu]nit.[Tt]est*/*[Uu]nit.[Tt]est*.csproj'
- name: cliTests # param nested
  type: string
  default: '**[Cc][Ll][Ii].[Tt]est*/*[Cc][Ll][Ii].[Tt]est*.csproj'
- name: codePool
  type: object
  default:
    vmImage: 'windows-latest' # Nested into pool param of codeAnalysis job

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
  - job: codeAnalysis # job name must be unique within stage
    displayName: 'Static Code Analysis' # job display name
    pool: ${{ parameters.codePool }} # param passed to pool of codAnalysis jobs
    dependsOn: [] # job does not depend on other jobs
    steps:
      - template: steps/code/analysis.yaml@template # resource identifier required as this is not extending from pipeline.yaml
        parameters:
        # preSteps: 
          # - task: add preSteps into job
          dotNetTests:
          - displayName: 'dotNet Unit Tests'
            projects: '${{ parametes.unitTests }}' # Pattern search for unit test projects
            arguments: '--no-restore --collect "Code Coverage"'
          - displayName: 'dotNet CLI Tests'
            projects: '${{ parametes.cliTests }}' # Pattern search for cli test projects
            arguments: '--no-restore --collect "Code Coverage"'
        # postSteps:
          # - task: add postSteps into job
# You can customize a list using this pattern

```
