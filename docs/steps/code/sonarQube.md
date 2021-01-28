# SonarQube Steps Template

- [SonarQube Steps Template](#sonarqube-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)

## Steps Template Usage

- In the [stages](../../stages.md) Template code jobList param you can add multiple jobs for static code analysis so long as the job name is unique within the stage
- The sonarQube steps template provides options for adding SonarQube analysis task in the right order before and after dotNet build of dotNetProjects

## Insert Steps Template into Stages Template

The following example shows how to insert the sonarQube steps template into the [stages](../../stages.md) template with the minimum required params.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:
- name: codePool
  type: object
  default:
    vmImage: 'windows-latest' # Nested into pool param of sonarQube job
# SonarQube Analysis extension for Azure Pipelines
- name: sonarQube # Required sonarQube Service Connection name to insert steps
  type: string
  default: ''
- name: dotNetProjects # Nested into dotNetProjects param of sonarQube steps. Can be Visual Studio solution (*.sln) or dotNet projects (*.csproj) to build for SonarQube analysis
  type: string
  default: '*.sln'

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
    code:
    # - job: insert static code analysis jobs into stage
      - job: sonarQube # job name must be unique within stage
        displayName: 'SonarQube Static Code Analysis' # job display name
        pool: ${{ parameters.codePool }} # param passed to pool of code jobs
        dependsOn: [] # job does not depend on other jobs
      # variables:
        # key: 'value' # pairs of variables scoped to this job
        steps:
        # - template: for code analysis steps
          - template: steps/code/sonarQube.yaml
          # parameters within sonarQube.yaml template
            parameters:
            # preSteps: 
              # - task: add preSteps into job
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
