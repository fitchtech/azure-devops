# nugetPackage Steps Template

- [nugetPackage Steps Template](#nugetpackage-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)

## Steps Template Usage

dotNetCommand options are build, publish, and pack:

- Pack project and push Nuget package artifact and symbols to feed
- Optionally dotNet build or publish a project prior to dotNet pack and push

## Insert Steps Template into Stages Template

The following example shows how to insert the nugetPackage steps template into the [stages](../../stages.md) template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:
- name: dotNetPackages # Required to enable pack. Pattern to search for csproj or nuspec files. Separate multiple patterns with semicolon. Exclude patterns with a ! prefix e.g. **/*.csproj;!**/*.Tests.csproj
  type: string
  default: '**.csproj'
- name: dotNetProjects # Optional file match pattern to build or publish projects
  type: string
  default: '**.csproj'
- name: buildPool # Nested into pool param of build jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'

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
    build:
      - job: dotNetPackage # job name must be unique within stage
        displayName: 'dotNet Pack Projects' # job display name
        pool: ${{ parameters.buildPool }} # param passed to pool of build jobs
        dependsOn: [] # job does not depend on other jobs
        variables:
          NugetVersion: $[counter(variables['Build.BuildNumber'], 1)] # NugetVersion is the default versionEnvVar (environment variable) used for the versioningScheme dotNet pack for NuGet packages
        steps:
        # - template: for nugetPackage steps
          - template: steps/build/nugetPackage.yaml
          # parameters within nugetPackage.yaml template
            parameters:
            # preSteps: 
              # - task: add preSteps into job
              dotNetPackages: ${{ parameters.dotNetPackages }} # Required pattern to pack and push projects for NuGet Packages
              dotNetProjects: ${{ parameters.dotNetProjects }} # Optional pattern to restore and build a project prior to dotNet pack and push 
              dotNetFeed: 'projectName/feedName' # for project-scoped feed. FeedName only for organization-scoped feed
              dotNetFeedPublish: 'projectName/feedName' # Push NuGet package to a select feed hosted in your organization. You must have Package Management installed and licensed to select a feed
            # dotNetCommand: build # build (default) or publish. This is the command used for dotNetProjects 
              publishEnabled: false # Set publishEnabled false to disable artifact publish of dotNet outputDir. It is enabled by default
            # postSteps:
              # - task: add postSteps into job

    # - job: insert additional jobs into the build stage

  # deploy: deploymentList inserted into deploy stage in stages param
  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param

```
