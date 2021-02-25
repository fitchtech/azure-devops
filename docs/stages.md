# Azure Pipeline Multistage Template

- [Azure Pipeline Multistage Template](#azure-pipeline-multistage-template)
  - [Stages Template Usage](#stages-template-usage)
  - [Stages Template Parameters](#stages-template-parameters)
  - [Stages Template Syntax](#stages-template-syntax)

## Stages Template Usage

The [stages](../stages.yaml) template encapsulates stages for a multistage pipeline that uses expressions to conditionally insert each stage and dependency if the stage has jobs listed. This template abstracts the stages and jobs within each stage.

- Validates the syntax of jobs and deployments in each stage
- Inserts each stage defined in the 'stages' parameters into the stages: section only if the stage has jobs
- Dependencies for each stage in stages are only inserted when the dependent stage has jobs
- Predefines all the common stages, their dependencies, and conditions, in a multistage pipeline
- Allows you to insert steps template into the job of a stage
- Orders the stages section according to how they are listed in the stages parameter

## Stages Template Parameters

Insert jobs into a stage by using the jobList or deploymentList parameter with the same name as the stage in the stages parameter

- **code:** jobList of static code analysis jobs. Conditionally run when triggered by Pull Request (PR) or manual execution
- **build:** jobList of build jobs. For example, dotNet build, docker build, etc.
- **deploy:** deploymentList of deployment jobs. For example, deploy ARM Template, deploy Kubernetes manifest, etc.
- **test:** jobList of test jobs to run after deploy stage. For example, after deploying canary run Visual Studio Test job for functional test of the deployment
- **promote:** deploymentList of deployment jobs, dependent on deploy and test stages, to promote the deployment in or to an environment. For example, with a canary strategy, promote the canary in deploy stage to baseline if successfully running
- **reject:** deploymentList of deployment jobs, dependent on deploy, test, and promote if the stage has jobs and a stage failed. Jobs to reject a failed deployment, to automatically deleted resources that are not functioning

To use the jobList and deploymentList parameters above the stage name in the stages parameter must match the jobList or deploymentList parameter name. The stages parameter can be used to modify the order or stages, their dependencies, conditions, add or delete stages.

- **stages:** default: code, build, deploy, test, promote, and reject stages
  - Optional parameter to override the stageList default to add stages or update the dependencies or conditions of predefined stages
- **stagesPrefix:** or **stagesSuffix:** parameters to optionally add a prefix or suffix respectively to the name of all stages
  - stagesSuffix: Dev would make stages named buildDev, deployDev, etc.
  - stagesPrefix: 'dev-' would make stages named dev-build, dev-deploy, etc.
- **stagesCondition:** parameter to optionally override the condition of all stages within the stages stageList

## Stages Template Syntax

To use the [stages](../stages.yaml) template in this repository the pipeline YAML file in your repository must include a resource named templates referencing this AzurePipelines repository. This allows you to reference paths in the repository resource by using the resource identifier.

The following shows extending from the stages template directly with its parameters.

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
  template: stages.yaml@templates
  parameters:
    code: [] # jobList inserted into code stage in stages param
    build: [] # jobList inserted into build stage in stages param
    deploy: [] # deploymentList inserted into deploy stage in stages param
    test: [] # jobList inserted into test stage in stages param
    promote: [] # deploymentList inserted into promote stage in stages param
    reject: [] # deploymentList inserted into reject stage in stages param
  # The jobList and deploymentList above are inserted into the stage in stages matching the parameter name 
  # stages: [] # Optional to override default of stages stageList. 
    stagesPrefix: '' # Optional stage name prefix. e.g. dev- would make dev-build, dev-deploy, etc.
    stagesSuffix: '' # Optional stage name suffix. e.g. Dev would make buildDev, deployDev, etc.
    stagesCondition: '' # Optional param to override the condition of all stages
```

When creating a pipeline template that nests the stages template it is inserted into the stages: section instead of extending from it.

```yaml
parameters:
# code: stage
- name: codeSteps # stepList inserted into code stage in stages
  type: stepList
  default: []
- name: codePool # Nested into pool param of code jobs
  type: object
  default:
    vmImage: 'windows-latest'
# build: stage
- name: buildSteps # stepList inserted into build job
  type: stepList
  default: []
- name: buildPool # Nested into pool param of build jobs
  type: object
  default: 
    vmImage: 'Ubuntu-16.04'
# deploy: stage
- name: preDeploySteps # Deployment job preDeploy lifecycle hook
  type: stepList
  default: []
- name: deploySteps # stepList inserted into deploy job
  type: stepList
  default: []
- name: routeTrafficSteps # Deployment job routeTraffic lifecycle hook
  type: stepList
  default: []
- name: postRouteTrafficSteps # Deployment job postRouteTraffic lifecycle hook
  type: stepList
  default: []
- name: onFailureSteps # Deployment job on: failure: lifecycle hook
  type: stepList
  default: []
- name: onSuccessSteps # Deployment job on: success: lifecycle hook
  type: stepList
  default: []
- name: deployPool # Nested into pool param of deploy, promote, and reject jobs
  type: object
  default:
    vmImage: 'ubuntu-18.04'
- name: strategy
  type: string
  default: runOnce
  values:
  - runOnce
  - canary
  - rolling
# test: stage
- name: testSteps # stepList inserted into test job
  type: stepList
  default: []
- name: testPool # Nested into pool param of test jobs
  type: object
  default:
    vmImage: 'windows-latest'
# promote: stage
- name: promoteSteps # stepList inserted into promote job
  type: stepList
  default: []
# reject: stage
- name: rejectSteps # stepList inserted into reject job
  type: stepList
  default: []
# overrides
- name: stages # Optional to override the default value of stages stageList in the stages.yaml template
  type: stageList
  default: ''
- name: stagesSuffix # Optional stage name suffix. e.g. Dev would make buildDev, deployDev, etc.
  type: string
  default: ''
- name: stagesPrefix # Optional stage name prefix. e.g. dev- would make dev-build, dev-deploy, etc.
  type: string
  default: ''
- name: stagesCondition # Optional param to override the condition of all stages
  type: string
  default: ''

stages:
  - template: stages.yaml
  # parameters: within stages.yaml
    parameters:
      # if steps in codeSteps, insert the code job
      ${{ if gt(length(parameters.codeSteps), 0) }}:
        code:
          - job: code1 # job name must be unique within stage
            displayName: 'Code Job' # job display name
            pool: ${{ parameters.codePool }} # param passed to pool of code jobs
            steps:
              - ${{ parameters.codeSteps }}
      # if steps in buildSteps, insert the build job
      ${{ if gt(length(parameters.buildSteps), 0) }}:
        build:
          - job: build1 # job name must be unique within stage
            displayName: 'Build Job' # job display name
            pool: ${{ parameters.buildPool }} # param passed to pool of build jobs
            steps:
              - ${{ parameters.buildSteps }}
      # if steps in deploySteps, insert the deploy job
      ${{ if gt(length(parameters.deploySteps), 0) }}:
        deploy:
          - deployment: deploy1 # deployment name unique to stage
            displayName: 'Deployment Job'
            pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
            condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
            strategy:
              ${{ parameters.strategy }}:
                # Insert preDeploy lifecycle hook stepList
                ${{ if gt(length(parameters.preDeploy), 0) }}:
                  preDeploy:
                    pool: ${{ parameters.deployPool }}
                    steps:
                      - ${{ parameters.preDeploy }}
                # Insert deploySteps stepList
                deploy:
                  steps:
                    - ${{ parameters.deploySteps }}
                # routeTraffic lifecycle hook
                ${{ if gt(length(parameters.routeTrafficSteps), 0) }}:
                  routeTraffic:
                    pool: ${{ parameters.deployPool }}
                    steps:
                      - ${{ parameters.routeTrafficSteps }}
                # postRouteTraffic lifecycle hook
                ${{ if gt(length(parameters.postRouteTrafficSteps), 0) }}:
                  postRouteTraffic:
                    pool: ${{ parameters.deployPool }}
                    steps:
                      - ${{ parameters.postRouteTraffic }}
                # on: failure: and success: lifecycle hooks
                ${{ if or(gt(length(parameters.onFailureSteps), 0), gt(length(parameters.onSuccessSteps), 0)) }}:
                  on:
                    ${{ if gt(length(parameters.onSuccessSteps), 0) }}:
                    # Insert onSuccess stepList
                      success:
                        pool: ${{ parameters.deployPool }}
                        steps:
                          - ${{ parameters.parameters.onSuccessSteps }}
                    # Insert onFailure stepList
                    ${{ if gt(length(parameters.onFailureSteps), 0) }}:
                      failure:
                        pool: ${{ parameters.deployPool }}
                        steps:
                          - ${{ parameters.onFailureSteps }}
      # if steps in testSteps, insert the test job
      ${{ if gt(length(parameters.testSteps), 0) }}:
        test:
          - job: test1 # job name must be unique within stage
            displayName: 'Test Job' # job display name
            pool: ${{ parameters.testPool }} # param passed to pool of test jobs
            steps:
              - ${{ parameters.testSteps }}
      # if steps in promoteSteps, insert the promote job
      ${{ if gt(length(parameters.promoteSteps), 0) }}:
        promote:
          - deployment: promote1 # deployment name unique to stage
            displayName: 'Promote Deployment Job'
            pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
            condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
            strategy:
              runOnce:
                deploy:
                  steps:
                    - ${{ parameters.promoteSteps }}
      # if steps in rejectSteps, insert the reject job
      ${{ if gt(length(parameters.rejectSteps), 0) }}:
        reject:
          - deployment: reject1 # deployment name unique to stage
            displayName: 'Reject Deployment Job'
            pool: ${{ parameters.deployPool }} # param passed to pool of deployment jobs
            condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
            strategy:
              runOnce:
                deploy:
                  steps:
                    - ${{ parameters.rejectSteps }}
      ${{ if gt(length(parameters.stages), 0) }}:
      # If stages stageList param has value then override default stages value in stages.yaml template
        stages: ${{ parameters.stages }}
      # These parameters are nested from the parameters section above
      stagesSuffix: ${{ parameters.stagesSuffix }}
      stagesPrefix: ${{ parameters.stagesPrefix }}
      stagesCondition: ${{ parameters.stagesCondition }}
```
