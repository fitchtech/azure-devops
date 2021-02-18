# Azure Pipeline Templates

- [Azure Pipeline Templates](#azure-pipeline-templates)
  - [Template Parameter Schema](#template-parameter-schema)

## Template Parameter Schema

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

extends:
  # file path to template at repo resource id to extend from
  template: presets/stepLists.yaml@templates
  parameters:
# code: stage in stages
# job: codeSteps
  codeSteps:
    - script: echo insert steps into stepList for codeSteps job
# job: codeTemplate
  codeTemplate: dotNetTests # code steps template name: dotNetTests | sonarQube | false (default) | i.e. ../steps/code/${{ parameters.codeTemplate }}.yaml
  # If codeTemplate, codeParameters are the parameters for the codeTemplate
  codeParameters:
    tests:
      - projects: '***[Uu]nit.[Tt]est*.csproj' # Pattern search for unit test projects
        arguments: '--collect "Code Coverage" /p:CollectCoverage=true  /p:CoverletOutputFormat=cobertura /p:CoverletOutput=$(Common.TestResultsDirectory)\Coverage\'
        displayName: 'dotNet Unit Tests'
        testRunTitle: 'Unit Tests' # Optional, if task displayName is different than testRunTitle
  codeMatrix: ''
  codeMaxParallel: 2
  codeVariables: ''
  codeJobs: []
  codePool:
    vmImage: 'windows-latest'
# build: stage in stages
# job: buildSteps
  buildSteps: 
    - script: echo insert steps into stepList for codeSteps job
# job: buildTemplate
  buildTemplate: containerImage # build steps template name: containerImage | dotNetCore | helmTemplate | nugetPackage | false (default) | i.e. ../steps/build/${{ parameters.buildTemplate }}.yaml
  buildParameters: 
    dockerFile: $(dockerfile)
    containerRepository: $(repository)
    containerRegistry: 'serviceConnectionName'
  buildMatrix:
    containerImage1:
      dockerfile: 'app1.dockerfile'
      repository: 'app1'
    containerImage2:
      dockerfile: 'app2.dockerfile'
      repository: 'app2'
  buildMaxParallel: 2
  buildVariables: ''
  buildJobs: []
  buildPool:
    vmImage: 'ubuntu-18.04'

# deploy: stage in stages

```
