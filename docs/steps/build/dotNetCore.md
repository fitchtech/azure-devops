# doNetCore Steps Template

- [doNetCore Steps Template](#donetcore-steps-template)
  - [dotNetCore Template Nested](#dotnetcore-template-nested)
  - [Steps Template Usage](#steps-template-usage)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)
  - [Direct Steps Template Usage](#direct-steps-template-usage)

## dotNetCore Template Nested

Like all steps templates, the dotNetCore steps template can be nested in the [stages](../../stages.md) template or directly in steps lists. However, the intent of this template is that it's nested into other steps templates. To provide dotNetCore tasks in other steps templates this template is nested within them. This is so that the common list of steps is not copied from one template to another.

- The [dotNetTests](./../code/dotNetTests.md) steps template nests the dotNetCore template for dotNet restore tasks
- The [sonarQube](./../code/sonarQube.md) steps template nests the dotNetCore template for dotNet restore and build tasks
- The [containerImage](containerImage.md) steps template nests the dotNetCore template for dotNet publish tasks before the docker build tasks
- The [visualStudioTest](./../test/visualStudioTest.md) steps template nests the dotNetCore template for dotNet build tasks before the Visual Studio Test tasks

## Steps Template Usage

dotNetCommand options are build, publish, and pack:

- Build a project for code analysis or test jobs. Optional publish pipeline artifact
- Publish a project for container image build. Optional publish pipeline artifact
- Pack a project for Nuget pack and push of Nuget artifact and symbols to feed

## Insert Steps Template into Stages Template

The following example shows how to insert the dotNetCore steps template into the [stages](../../stages.md) template with the minimum required params. Build a dotNet project and publish a pipeline artifact. This is useful if you want to download the build artifact into other jobs in all stages.

Note: when using the [dotNetTests](./../code/dotNetTests.md), [sonarQube](../code/sonarQube.md), [containerImage](containerImage.md), or [visualStudioTest](./../test/visualStudioTest.md) templates, using the dotNetCore template directly as shown below would not be needed as it's nested into these templates.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:
- name: buildPool # Nested into pool param of build jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: dotNetProjects # pattern to match of projects to build, publish, or pack
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
  template: stages.yaml@templates
# parameters: within stages.yaml@templates
  parameters:
  # code: jobList inserted into code stage in stages
  # build: jobList inserted into build stage in stages
    build:
      - job: dotNetBuild # job name must be unique within stage
        displayName: 'dotNet Build Projects' # job display name
        pool: ${{ parameters.buildPool }} # param passed to pool of build jobs
        dependsOn: [] # job does not depend on other jobs
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        steps:
        # - template: for dotNetCore steps
          - template: steps/build/dotNetCore.yaml
          # parameters within dotNetCore.yaml template
            parameters:
            # preSteps: 
              # - task: add preSteps into job
            # dotNetCommand: build # default in template is build
              dotNetProjects: ${{ parameters.dotNetProjects }} # pattern to match of projects to build 
              publishEnabled: true # Set publishEnabled true to publish artifact of dotNet build or publish outputs 
            # postSteps:
              # - task: add postSteps into job

    # - job: insert additional jobs into the build stage

  # deploy: deploymentList inserted into deploy stage in stages param
  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```

## Direct Steps Template Usage

The following example shows inserting a steps template into the steps section. This is to show parameter usage in the template. See the [Insert Steps Templates into Stages Template](#insert-steps-templates-into-stages-template) section above for usinge this template in the [stages](../../stages.md) template

```yml
steps:
# template: insert dotNetCore build and publish pipeline artifact steps into job
- template: steps/build/dotNetCore.yaml
  parameters:
  # When nesting multiple steps templates into a single job add clean, checkout and download params set to false.
  # checkout: self # preSteps checkout step enabled by default to checkout the source repo
    download: false # disables preSteps download steps
    preSteps: 
     - script: echo 'add preSteps stepsList to job' # list of tasks that run before the main steps of the template. Inserted into steps after checkout/download
    dotNetCommand: build # build | publish | pack
  # dotNetType: runtime # sdk is the default, only set this to override sdk with runtime
  # dotNetVersion: '3.1.x' # UseDotNet@2 version number by default, set to null to skip step
    dotNetProjects: '**.csproj' # pattern match of projects or solution to build or publish
    publishEnabled: true # Set publishEnabled true to publish artifact of dotNet build or publish outputs 
  # dotNetFeed: '' # Azure DevOps Artifacts Feed
  # dotNetArguments: '' # Output and no-restore arguments are injected for you. This param is for inserting any additional build/publish args for the task
    postSteps:
     - script: echo 'add postSteps stepsList to job' # list of tasks that run after the main steps of the template. Inserted into steps before publish/clean

# template: insert dotNetCore pack and push Nuget artifact steps into job
- template: steps/build/dotNetCore.yaml
  parameters:
  # When nesting multiple steps templates into a single job add clean, checkout and download params set to false.
    checkout: false # disables preSteps checkout steps
    download: false # disables preSteps download steps
    preSteps: 
     - script: echo 'add preSteps stepsList to job' # list of tasks that run before the main steps of the template. Inserted into steps after checkout/download
    dotNetCommand: pack # build | publish | pack
  # dotNetType: runtime # sdk is the default, only set this to override sdk with runtime
  # dotNetVersion: '3.1.x' # UseDotNet@2 version number by default, set to null to skip step
    dotNetProjects: '**.csproj' # pattern match of projects or solution to build or publish
    dotNetPush: true # Push Nuget artifact to ADO Feed
    includeSymbols: true # Publish Symbols
    dotNetPackConfig: 'Debug' # dotNet configuration
    postSteps:
     - script: echo 'add postSteps stepsList to job' # list of tasks that run after the main steps of the template. Inserted into steps before publish/clean

```
