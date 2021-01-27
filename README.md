# Azure Pipeline Templates

- [Azure Pipeline Templates](#azure-pipeline-templates)
  - [Getting Started](#getting-started)
    - [Repository Resource](#repository-resource)
    - [Repository Tagging](#repository-tagging)
  - [Template Documentation](#template-documentation)
    - [Multistage Template](#multistage-template)
    - [Code Stage](#code-stage)
    - [Build Stage](#build-stage)
    - [Deploy Stage](#deploy-stage)
    - [Test Stage](#test-stage)
    - [Promote or Reject Deployments](#promote-or-reject-deployments)
      - [Kubernetes Canary Strategy](#kubernetes-canary-strategy)
      - [Blue Green Strategy](#blue-green-strategy)
    - [Template Types](#template-types)
  - [Design Principals and Patterns](#design-principals-and-patterns)
    - [Development Motivations](#development-motivations)
    - [Strategic Design](#strategic-design)
    - [Validation Methods](#validation-methods)
  - [Azure Pipeline Concepts](#azure-pipeline-concepts)
    - [Build Verification Pipeline](#build-verification-pipeline)
    - [Continuous Integration Pipeline](#continuous-integration-pipeline)
    - [Continuous Deployment Pipeline](#continuous-deployment-pipeline)
  - [Idempotent and Immutable](#idempotent-and-immutable)
    - [Idempotent Pipelines](#idempotent-pipelines)
    - [Immutable Pipelines](#immutable-pipelines)
    - [Build Number Format](#build-number-format)
  - [Microsoft Docs](#microsoft-docs)

## Getting Started

This repository stores [Azure Pipelines templates](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates) that can be used to impliment multi stage Azure Pipelines using standardized methods with validated functionality. Reducing the time and cost burden of developing your own strategy for development and managing Azure Pipelines YAML. Additionally this repository includes documentation for implimentation as well as design priciples, patterns, and concept strategies for utilizing Azure Pipelines effectively.

### Repository Resource

To use the pipeline templates in this repository it must be listed as a resource in your pipeline YAML file. This allows you to reference paths in another repository by using the resource identifier.

The example below shows using a tagged reference of the AzurePipelines repo. It's important that you always reference a tag of an Azure Pipeline templates repository. This way when your pipeline is triggered it is always referencing the tagged commit of the templates.

This also shows the repository resource using an endpoint named 'GitHub'. Create a [GitHub service connection](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml#sep-github) if you have not already done so. Alternatively, you can fork this repository to your own GitHub or Azure Repos account and reference it instead.

```yaml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)

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
    stagesPrefix: "" # Optional stage name prefix. e.g. dev- would make dev-build, dev-deploy, etc.
    stagesSuffix: "" # Optional stage name suffix. e.g. Dev would make buildDev, deployDev, etc.
    stagesCondition: "" # Optional param to override the condition of all stages
```

### Repository Tagging

- Major version: breaking change to prior major version. When existing pipelines cannot update to the new version without implimenting a change in their pipeline.
- Minor version: no breaking changes to the major version. Incrimental updates including bug fixes and new features. Changes are additive and do not remove functionality.

## Template Documentation

### Multistage Template

[Stages Template for Nesting Steps Templates](./docs/stages.md) into jobs of a stage. Provides expression driven stage creation for inserting steps templates into the jobs of a stage in stages. A stage in stages is only inserted when the stage has jobs and values for the minimum required parameters.

### Code Stage

Steps templates to insert into jobs of code stage in the [stages](./docs/stages.md)

- [dotNet Test Static Code Analysis](./docs/steps/code/dotNetTests.md): Run SonarQube for dotNet and run dotNet test for unit and cli tests
- [SonarQube Static Code Analysis](./docs/steps/code/sonarQube.md): Run SonarQube for dotNet projects or solutions

### Build Stage

Steps templates to insert into jobs of build stage in the [stages](./docs/stages.md)

- [Build and Push Container Image](./docs/steps/build/containerImage.md): Build and push a docker image using an optional dotNet solution and dockerfile
- [Build and Publish Manifests Artifact from Helm Charts](./docs/steps/build/helmTemplate.md): Render Helm Charts with Helm Template cmd and deploy manifests to Kubernetes
- [Build, Publish, or Pack dotNet Projects and Publish Artifact](./docs/steps/build/dotNetCore.md): Build and publish a dotNet project without any tests
- [Pack and Push Nuget Artifacts](./docs/steps/build/nugetPackage): Build and pack a dotNet project to publish Nuget packages to an artifact feed

### Deploy Stage

Steps templates to insert into jobs of deploy stage in the [stages](./docs/stages.md)

- [Deploy ARM Templates](./docs/steps/deploy/armTemplate.md): Deploy an ARM template(s)
- [Deploy Helm Charts](./docs/steps/deploy/helmChart.md): Use Helm charts to deploy components to Kubernetes
- [Render Helm Charts and Deploy Manifests](./docs/steps/deploy/helmManifest.md): Render Helm Charts with Helm Template cmd and deploy manifests to Kubernetes
- [Deploy Kubernetes Manifests](./docs/steps/deploy/kubeManifest.md): Deploy Kubernetes manifests and secrets

### Test Stage

Steps templates to insert into jobs of test stage in the [stages](./docs/stages.md)

- [Visual Studio Tests](./docs/steps/test/visualStudioTest.md): Run VS Test suites in a dotNet project

### Promote or Reject Deployments

The promote and reject stages are for deployment jobs to promote or reject deployments from the deploy stage. For example, when using a canary deployment strategy for Kubernetes manifests it conditionally promotes on the success of test jobs and ready state of the canary pods. If any test job fails the reject stage runs to automatically delete a deployment that is not functionig.

Additionally these stages could be used with Infrastructure as Code (IaC) for blue/green deployments. For example, in the deploy stage deploy the green stack. Test the green field stack, if they succeed, then in the promote stage swap the environments. Promoting the green environment to blue and demoting the previous stack. Using the reject stage if the green stack fails.

#### Kubernetes Canary Strategy

- Deploy: Kubernetes deployment manifest canary pods
  - Deployment lifecycle hooks stepLists
- Test: stage for functional tests of canaries. e.g. Visual Studio Tests
- Promote: Kubernetes canary deployment to baseline if test stage succeeded
- Reject: delete Kubernetes canary pods automatically if tests failed or pods not ready

#### Blue Green Strategy

- Deploy: Green IaC stack
  - Deployment lifecycle hooks stepLists with runOnce, rolling, or matrix strategies
- Test: stage for functional tests of green stack
- Promote: Swap endpoints of stacks from green to blue or promote green to blue
- Reject: delete green stack if tests failed

### Template Types

- stages template: inserts stages from stageLists for multi stage pipelines with parameterized inputs
- jobs template: inserts jobs from jobLists into a stage of stages with parameterized inputs
- steps template: inserts tasks into steps with parameterized inputs and optionally additional stepLists
- pipeline template: nests stages, jobs, and steps templates into a single template to extend from with flexible parameters

## Design Principals and Patterns

- Templates encapsulating stepLists, jobLists, and stageLists: no longer than ~500 lines
- Templates abstracting a pipeline: no longer than ~1000 lines
- Template design patterns are centralized into this repository
- Templates should be broken down into parts depending on their type
  - Steps, jobs, stages, or pipeline templates
  - Organize templates into folders based on their type
- Steps templates nest tasks for a given use case.
  - e.g. steps/build/containerImage.yaml is a stepList for build and push of a container image
- Parameter naming for templates resemble the task inputs they are mapped to
- Parameters naming uses camelCase
- Parameter naming consistent across templates
- Limit nesting templates to two levels
- Expressions no longer than ~100 char
- Only use pipeline variables for replace tokens and env vars

### Development Motivations

Azure Pipelines multistage YAML became generally available in April, 2020. With this change in Azure build and release pipelines, now known as classic build and release pipelines, came a major shift in the design patterns for creating Azure Pipelines with YAML. Implementing YAML pipelines can be simple for smaller projects or when you have a single repository. However, when implementing pipeline YAML across multiple projects or repositories it can become extremely difficult to manage without a well thought out design strategy.

Developing Azure Pipeline YAML can be very time consuming and costly without a good strategy. The motivation for this project and repository is to reduce the time and effort in implimenting Azure Pipelines. By creating a centralized repository of pipeline templates that have been tried and tested functionality. With design patterns and anti-patterns that evolved from development of pipeline templates across multiple projects, teams, and environment through to production.

### Strategic Design

It is important to use a strategy for developing that use a centralized pipeline template repository. When you have multiple repositories, projects, or teams if the pipeline YAML is created in each repository it is vary easy for configuration to vary drastically from one pipeline to another. Making it impossible to standardize the design of pipelines. Using a centralized repository for pipeline templates solves this issue. It also accelerates the pace of innovation by removing the burden of developing each pipeline and ensuring each functions correctly and consistently with limited failures.

### Validation Methods

One limitation of Azure Pipelines YAML in general is that the only way to validate the functionality of your pipeline is to run it. Linting of pipeline YAML is limited and does not cover templates and nesting. Additionally, the only way to generate the runtime YAML which compiles multiple templates and generates variables is to run it in Azure Pipelines.

There is not currently any way to validate Azure Pipelines YAML locally. This makes developing pipeline templates time consuming and costly as you make a commit, run to validate, fail, commit, run again, and again. In the development and itteration of these templates there were often hundreds of commits and many, many, pipeline executions to validate. Even then it can be challenging to verify impacts to a change across templates that consume it. By utilizing this project you can greatly reduce the difficulty in adopting Azure Pipelines.

## Azure Pipeline Concepts

### Build Verification Pipeline

A Build Verification Pipeline (BVP) is for Pull Requests (PR trigger). This includes the code stage for static code analysis including dotNet tests and SonarQube analysis jobs. Additionally the build stage runs jobs for dotNet publish artifact and container image artifact publish. A dotNet and container image artifact for each app.

### Continuous Integration Pipeline

Continuous Integration Pipelines (CIP) can be triggered on BVP completion. The build stage container image job downloads artifacts from the BVP. Optionally run white source scan of dotNet artifact and Twistlock scan of container image, then push the image to a container registry with the tag using the build number format.

Optionally you can add a CI Trigger on Feature and Release branches to run the build stage to dotNet publish the commit, build and push the container image to the registry. When the pipeline completes the CDP is triggered for the commit.

### Continuous Deployment Pipeline

Continuous Deployment Pipeline (CDP) can be triggered on CIP completion. The deploy stage deploys Azure Resource Manager (ARM) Templates, Kubernetes Manifests, Helm Charts, etc. You may choose to decouple build and deployment pipelines when you're deploying to multiple environments.

When creating a CDP for a given environment you can, for example, add triggers for release branches prefixed with dev. So that your dev environment CDP is triggered for dev releases. Whereas your production environment pipeline is triggered when merged into the prod branch.

- release/dev\*
- release/prod\*

## Idempotent and Immutable

### Idempotent Pipelines

When implementing idempotent pipeline patterns, subsequent runs are not additive if there are not changes to the code. Using dates and run count within the build number format is an anti-pattern as it’s not idempotent. Instead use the repository name, branch/tag name, and commit ID for the build number format. This provides a pattern for idempotent CI/CD Pipelines.

### Immutable Pipelines

When implementing immutable pipeline patterns, when an existing deployment image and pod spec is unchanged the current deployment is immutable. The current pod state does not mutate (i.e. terminate and deploy new pod or deploy canary).

### Build Number Format

The build number format is key to creating idempotent and immutable pipelines. The following format is recommended. By using this format the container image tag would not change if the code has not changed. Therefore subsequent runs of the CD pipeline would be immutable. Only manifest changes would be applied if the image is unchanged.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)
```

With immutable and idempotent pipelines running it without code changes would validate the current deployment state is unchanged from the code. When the current state of the object kind in the Kubernetes environment matches the manifest being applied it’s unchanged, verifying the current state to manifests in the commit.

This could also be referred to as Configuration Management of the Kubernetes resources. If the object had been changed manually, this is configuration drift. By running an immutable CDP any configuration drift in the current state of the Kubernetes objects would be reverted by applying manifests in the current commit.

## Microsoft Docs

General usage of templates is described [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops)
