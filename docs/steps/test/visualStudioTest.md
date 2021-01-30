# Visual Studio Test Steps Template

- [Visual Studio Test Steps Template](#visual-studio-test-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Steps Template Schema](#steps-template-schema)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)

## Steps Template Usage

- This template is used to run VSTest jobs for tests such as Build Verification or Functional Tests
- To run the test the job needs to dotNet build the test project or download an artifact of the build.
- This template has an option to replace tokens in target files with variables. This is useful when you need to use variables to replace values in files
- You can define the test plan and suite for a vsTest. This requires you [create a test plan](https://docs.microsoft.com/en-us/azure/devops/test/create-a-test-plan?view=azure-devops) in Azure DevOps

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
      replaceTokens: true # Enable replace tokens task for variable replacement
      replaceTokensTargets: '**appsettings.*.json' # Target file match pattern for replace tokens task
      keyVaultName: keyVaultName # Get secrets from an Azure KeyVault. Useful with replace tokens task when you need to inject secrets into settings
      keyVaultSubscription: 'subscriptionServiceConnection' # Azure service connection to subscription of Azure KeyVault
      testPlan: 123456 # Required if testSelector is testPlan. The ID number of the testPlan
      testSuite: 123456 # Required if testSelector is testPlan. The ID number of the testSuite
      testConfiguration: 523 # Required if testSelector is testPlan. The ID number of the testConfiguration
      testRunTitle: 'Test Run Title'
      testDiagnosticsEnabled: false # Default: true
      testCollectDumpOn: always # Default: onAbortOnly | always | never
      runInParallel: false # Default: true | run tests serially or in parallel
      rerunMaxAttempts: 2
      continueOnError: true
      distributionBatchType: basedOnExecutionTime # default: basedOnTestCases | basedOnExecutionTime | basedOnAssembly
      customBatchSizeValue: 10 # Optional when distributionBatchType is basedOnExecutionTime. Value greater than 0 enables batchingBasedOnAgentsOption: customBatchSize
      customRunTimePerBatchValue: 10 # Optional when distributionBatchType is BasedOnExecutionTime
      dotNetProjects: '*.sln' # Optional: File matching pattern to Visual Studio solution (*.sln) or dotNet project (*.csproj) to restore. 
      dotNetVersion: '3.1.x' # Optional: if param has value, use dotNet version task inserted
      dotNetFeed: '' # Optional: GUID of Azure artifact feed. Use when projects restore NuGet artifacts from a private feed
      dotNetArguments: '' # Optional: Additional arguments for dotNetProjects if dotNetCommand is build or publish. Excluding '--no-restore' and '--output' as they are predefined
      publishEnabled: false # Disable the publish task, default true. Publishes the testResultsFolder
      publishArtifact: 'artifactName' # Default: $(Build.DefinitionName)_$(System.JobName)
    # postSteps: Optional: inserts stepList before publish and clean
      postSteps: 
        - script: echo add stepList of tasks into steps

```

## Insert Steps Template into Stages Template

The following example shows how to insert the dotNetTests steps template into the [stages](../../stages.md) template.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

parameters:
# params to pass into stages.yaml template:
- name: testPool
  type: object
  default:
    vmImage: 'windows-latest' # Nested into pool param of test jobs
- name: vsTests
  type: object
  default:
    - job: vsTest
      dependsOn: []
      dotNetProjects: '*.csproj'
      testPlan: 123456
      testSuite: 123456
      testConfiguration: 523
      testRunTitle: 'Functional Test'
      rerunMaxAttempts: 2
      continueOnError: false

- name: matrix
  type: object
  default: ''
- name: parallel
  type: number
  default: 1

- name: dotNetProjects # Optional param, nested into dotNetProjects param of dotNetTests steps. Can be Visual Studio solution (*.sln) or dotNet projects (*.csproj) to restore for multiple tests.
  type: string
  default: ''

# parameter defaults in the above section can be set on the manual run of a pipeline to override

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
  # build: jobList inserted into build stage in stages param
  # deploy: deploymentList inserted into deploy stage in stages param
  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
    test:
      - ${{ each test in parameters.vsTests }}:
        - ${{ if and(test.job, test.dotNetProjects, parameters.testPlan, parameters.testSuite) }}:
        # - job: name must be unique within stage
          - job: ${{ test.job }}
          # for each job param of test item in vsTests, insert param
            ${{ each parameter in test }}:
              ${{ if in(parameter.key, 'displayName', 'condition', 'continueOnError', 'pool', 'workspace', 'container', 'timeoutInMinutes', 'cancelTimeoutInMinutes', 'services') }}:
                ${{ parameter.key }}: ${{ parameter.value }}
            # If test job depends on other jobs in test stage insert dependencies
            ${{ if test.dependsOn }}:
              dependsOn:
              - ${{ each dependency in test.dependsOn }}:
                - ${{ dependency }}
            # If no test.dependsOn job does not depend on others
            ${{ if not(test.dependsOn) }}:
              dependsOn: []
            # If variables defined add key value pairs
            ${{ if test.variables }}:
              variables:
              ${{ each variable in test.variables }}:
                ${{ variable.key }}: ${{ variable.value }}
            # If no test.displayName use default
            ${{ if not(test.displayName) }}:
              displayName: 'Visual Studio Test Job'
            # If no test.pool use parameters.testPool value
            ${{ if not(test.pool) }}:
              pool: ${{ parameters.testPool }}
            # If test.matrix or test.parallel strategy for Visual Studio Test jobs
            ${{ if or(test.matrix, gt(test.parallel, 1)) }}:
              strategy:
                ${{ if test.matrix }}:
                  matrix: ${{ test.matrix }}
                ${{ if not(test.matrix) }}:
                  parallel: ${{ test.parallel }}
            # If the test has no test.matrix or test.parallel values then use parameters.matrix and parameters.parallel as default
            ${{ if and(or(parameters.matrix, gt(parameters.parallel, 1)), or(not(test.matrix), le(test.parallel, 1), not(test.parallel))) }}:
              strategy:
                ${{ if parameters.matrix }}:
                  matrix: ${{ parameters.matrix }}
                ${{ if not(parameters.matrix) }}:
                  parallel: ${{ parameters.parallel }}
            steps:
            # - template: insert visualStudioTest template
              - template: steps/test/visualStudioTest.yaml
              # parameters within visualStudioTest.yaml template
                parameters:
                # preSteps: 
                  # - task: add preSteps into job
                # for each parameter in test that is not a job parameter, these are the parameters for the steps
                  ${{ each parameter in test }}:
                    ${{ if notIn(parameter.key, 'job', 'displayName', 'dependsOn', 'condition', 'strategy', 'continueOnError', 'pool', 'workspace', 'container', 'timeoutInMinutes', 'cancelTimeoutInMinutes', 'variables', 'steps', 'services') }}:
                      ${{ parameter.key }}: ${{ parameter.value }}
                  # If testPlan and testSuite has values testSelector is testPlan
                  ${{ if and(test.testPlan, test.testSuite, not(test.testSelector)) }}:
                    testSelector: testPlan
                  ${{ if not(test.testRunTitle) }}:
                    testRunTitle: 'Visual Studio Test'
                # postSteps:
                  # - task: add postSteps into job

    # - job: insert additional jobs into the code stage

  # reject: deploymentList inserted into reject stage in stages param

```
