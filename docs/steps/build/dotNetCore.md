# doNetCore Steps Template

- [doNetCore Steps Template](#donetcore-steps-template)
  - [Steps Template Nesting](#steps-template-nesting)
  - [Steps Template Usage](#steps-template-usage)
  - [Adding Steps into Pipeline Template](#adding-steps-into-pipeline-template)

## Steps Template Nesting

Like all steps templates, the dotNetCore steps template can be nested in the [pipeline](../../pipeline.md) template or directly in steps lists. However, the intent of this template is that it's nested into other steps templates. To provide dotNetCore tasks in other steps templates this template is nested within them. This is so that the common list of steps is not copied from one template to another.

- The [codeAnalysis](codeAnalysis.md) steps template nests the dotNetCore template for dotNet build and test tasks
- The [containerImage](containerImage.md) steps template nests the dotNetCore template for dotNet publish tasks before the docker build tasks
- The [visualStudio](visualStudio.md) steps template nests the dotNetCore template for dotNet build tasks before the Visual Studio Test tasks

## Steps Template Usage

dotNetCommand options are build, publish, and pack:

- Build a project for code analysis or test jobs. Optional publish pipeline artifact
- Publish a project for container image build. Optional publish pipeline artifact
- Pack a project for Nuget pack and push of Nuget artifact and symbols to feed

The following example shows inserting a steps template into the steps section. This is to show parameter usage in the template. See the [Nest dotNetCore Steps into Pipeline Template](#nest-dotnetcore-steps-into-pipeline-template) section shows how this could be used in the [pipeline](../../pipeline.md) template

```yml
steps:
# template: insert dotNetCore build and publish pipeline artifact steps into job
- template: steps/build/dotNetCore.yaml
  parameters:
  # When nesting multiple steps templates into a single job add clean, checkout and download params set to false.
    clean: false # disables preSteps and postSteps clean tasks
    checkout: false # disables preSteps checkout steps
    download: false # disables preSteps download steps
    dotNetCommand: build # build | publish | pack
  # dotNetType: runtime # sdk is the default, only set this to override sdk with runtime
  # dotNetVersion: '3.1.x' # UseDotNet@2 version number by default, set to null to skip step
    dotNetProjects: '**.csproj' # pattern match of projects or solution to build or publish
    publishEnabled: true # Set publishEnabled true to publish artifact of dotNet build or publish outputs 
  # dotNetFeed: '' # Azure DevOps Artifacts Feed
  # dotNetArguments: '' # Output and no-restore arguments are injected for you. This param is for inserting any additional build/publish args for the task

# template: insert dotNetCore pack and push Nuget artifact steps into job
- template: steps/build/dotNetCore.yaml
  parameters:
  # When nesting multiple steps templates into a single job add clean, checkout and download params set to false.
    clean: false # disables preSteps and postSteps clean tasks
    checkout: false # disables preSteps checkout steps
    download: false # disables preSteps download steps
    dotNetCommand: pack # build | publish | pack
  # dotNetType: runtime # sdk is the default, only set this to override sdk with runtime
  # dotNetVersion: '3.1.x' # UseDotNet@2 version number by default, set to null to skip step
    dotNetProjects: '**.csproj' # pattern match of projects or solution to build or publish
    dotNetPush: true # Push Nuget artifact to ADO Feed
    includeSymbols: true # Publish Symbols
    dotNetPackConfig: 'Debug' # dotNet configuration

```

## Adding Steps into Pipeline Template

The following example shows how to insert the dotNetCore steps template into the [pipeline](../../pipeline.md) template with the minimum required params. Build a project and publish a pipeline artifact. This is useful if you want to download the build artifact into other jobs in all stages.

Note: when using the [codeAnalysis](codeAnalysis.md), [containerImage](containerImage.md), or [visualStudioTest](visualStudioTest.md) templates, using the dotNetCore template directly as shown below would not be needed as it's nested into these templates.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into pipeline.yaml template:
- name: buildPool # Nested into pool param of build jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: dotNetProjects # pattern to match of projects to build 
  type: string
  default: '**.csproj'

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
      - job: codeBuild # job name must be unique within stage
        displayName: 'dotNet Build Projects' # job display name
        pool: ${{ parameters.buildPool }} # param passed to pool of codAnalysis jobs
        dependsOn: [] # job does not depend on other jobs
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        steps:
        # - task: add preSteps to codeAnalysis job
        # - template: for codeAnalysis steps
          - template: steps/build/dotNetCore.yaml
          # parameters within dotNetCore.yaml template
            parameters:
            # dotNetCommand: build # default in template is build
              dotNetProjects: ${{ parameters.dotNetProjects }} # pattern to match of projects to build 
              publishEnabled: true # Set publishEnabled true to publish artifact of dotNet build or publish outputs 
        # - task: add postSteps to codeAnalysis job
    # - job: insert additional jobs into the devBuild stage
```
