# Visual Studio Test Steps Template

- [Visual Studio Test Steps Template](#visual-studio-test-steps-template)
  - [Steps Template Usage](#steps-template-usage)
  - [Steps Template Schema](#steps-template-schema)
  - [Insert Steps Template into Stages Template](#insert-steps-template-into-stages-template)

## Steps Template Usage

- This template is used to run VSTest jobs for tests such as Build Verification or Functional Tests.
- To run the test the job needs to dotNet build the test project or download an artifact of the build.
- This template has an option to replace tokens in target files with variables. This is useful when you need to use variables to replace values in files

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
      keyVaultName: keyVaultName # Get secrets from an Azure KeyVault. Usefuly for replace tokens task when you need to inject secrets into settings
      keyVaultSubscription: 'subscriptionServiceConnection' # Azure service connection to subscription of Azure KeyVault
      testSelector: testPlan # testPlan (default) | testAssemblies | testRun
      testPlan: 123456 # Required if testSelector is testPlan. The ID number of the testPlan
      testSuite: 123456 # Required if testSelector is testPlan. The ID number of the testSuite
      testConfiguration: 523 # Required if testSelector is testPlan. The ID number of the testConfiguration
      runInParallel: false # default: true | run tests serially or in parallel
      testRunTitle: 'Test Run Title'
      testDiagnosticsEnabled: false # default: true
      testCollectDumpOn: onAbortOnly # default: always | onAbortOnly | never
      rerunFailedTests: true
      rerunMaxAttempts: 2
      continueOnError: true
      distributionBatchType: basedOnExecutionTime # default: basedOnTestCases | basedOnExecutionTime | basedOnAssembly
      customBatchSizeValue: 10 # Value greater than 0 enables batchingBasedOnAgentsOption: customBatchSize
      dotNetProjects: '*.sln' # Optional: File matching pattern to Visual Studio solution (*.sln) or dotNet project (*.csproj) to restore. 
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

The following example shows how to insert the dotNetTests steps template into the [stages](../../stages.md) template with the minimum required params.

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
      testSelector: testPlan #  testPlan | testAssemblies | testRun
      testPlan: 123456
      testSuite: 123456
      testConfiguration: 523
      testRunTitle: 'Functional Test'
      rerunFailedTests: true
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
  # build: jobList inserted into build stage in stages param
  # deploy: deploymentList inserted into deploy stage in stages param
  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
    test:
      - ${{ each test in parameters.vsTests }}:
        # parameters: job, dotNetProjects, testSelector, testPlan, and testSuite are the required minimum params
        - ${{ if and(test.job, test.dotNetProjects, parameters.testPlan, parameters.testSuite) }}:
          - job: ${{ test.job }} # job name must be unique within stage
            ${{ each parameter in test }}:
              ${{ if in(parameter.key, 'displayName', 'condition', 'strategy', 'continueOnError', 'pool', 'workspace', 'container', 'timeoutInMinutes', 'cancelTimeoutInMinutes', 'services') }}:
                ${{ parameter.key }}: ${{ parameter.value }}
            ${{ if not(test.displayName) }}:
              displayName: 'Visual Studio Test Job' # If no test.displayName, use this as default
            ${{ if not(test.pool) }}:
              pool: ${{ parameters.testPool }} # If no test.pool, use default parameters.testPool
            # If test job depends on other jobs in test stage insert dependencies
            ${{ if test.dependsOn }}:
              dependsOn:
              - ${{ each dependency in test.dependsOn }}:
                - ${{ dependency }}
            ${{ if not(test.dependsOn) }}:
              dependsOn: [] # job does not depend on other jobs
            ${{ if test.variables }}:
              variables:
              ${{ each variable in test.variables }}:
                ${{ variable.key }}: ${{ variable.value }}
          # If matrix or parallel strategy for Visual Studio Test jobs
            ${{ if or(parameters.matrix, gt(parameters.parallel, 1)) }}:
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
                  ${{ if test.dotNetProjects }}:
                    dotNetProjects: ${{ test.dotNetProjects }}
                  ${{ if and(test.testPlan, test.testSuite) }}:
                    ${{ if test.testSelector }}:
                      testSelector: ${{ test.testSelector }}
                    ${{ if not(test.testSelector) }}:
                      testSelector: testPlan
                    testPlan: ${{ test.testPlan }}
                    testSuite: ${{ test.testSuite }}
                  testConfiguration: ${{ test.testConfiguration }}
                  ${{ if test.testRunTitle }}:
                    testRunTitle: ${{ test.testRunTitle }}
                  ${{ if not(test.testRunTitle) }}:
                    testRunTitle: 'Visual Studio Test'
                  ${{ if test.rerunFailedTests }}:
                    rerunFailedTests: true
                    ${{ if test.rerunMaxAttempts }}:
                      rerunMaxAttempts: ${{ test.rerunMaxAttempts }}
                    ${{ if not(test.rerunMaxAttempts) }}:
                      rerunMaxAttempts: 2
                  ${{ if test.continueOnError }}:
                    continueOnError: true
                # postSteps:
                  # - task: add postSteps into job

    # - job: insert additional jobs into the code stage

  # reject: deploymentList inserted into reject stage in stages param

```
