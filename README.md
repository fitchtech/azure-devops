# Azure Automations as Code

- [Azure Automations as Code](#azure-automations-as-code)
  - [Introduction](#introduction)
  - [Getting Started](#getting-started)
    - [Repository Resource](#repository-resource)
    - [Repository Tagging](#repository-tagging)
  - [Template Documentation](#template-documentation)
    - [Template Types](#template-types)
    - [Stages Template](#stages-template)
    - [Preset Templates](#preset-templates)
    - [Code Stage](#code-stage)
    - [Build Stage](#build-stage)
    - [Deploy Stage](#deploy-stage)
    - [Test Stage](#test-stage)
    - [Promote or Reject Deployments](#promote-or-reject-deployments)
      - [Kubernetes Canary Strategy](#kubernetes-canary-strategy)
      - [Blue Green Strategy](#blue-green-strategy)
  - [Design Principals and Patterns](#design-principals-and-patterns)
    - [Development Motivations](#development-motivations)
    - [Strategic Design](#strategic-design)
    - [Validation Methods](#validation-methods)
    - [Immutable Pipelines](#immutable-pipelines)
    - [Idempotent Pipelines](#idempotent-pipelines)
    - [Build Number Format](#build-number-format)
  - [Azure Pipeline Concepts](#azure-pipeline-concepts)
    - [Build Verification Pipeline](#build-verification-pipeline)
    - [Continuous Integration Pipeline](#continuous-integration-pipeline)
    - [Continuous Deployment Pipeline](#continuous-deployment-pipeline)
    - [Multistage Pipelines](#multistage-pipelines)
    - [Automations Pipeline](#automations-pipeline)
  - [Contributions](#contributions)
    - [Branch Naming](#branch-naming)
    - [Commit Naming](#commit-naming)
    - [Existing Templates](#existing-templates)
    - [Steps Template Creation](#steps-template-creation)
    - [Preset Template Creation](#preset-template-creation)
    - [Test Pipelines](#test-pipelines)
  - [Microsoft Docs](#microsoft-docs)

## Introduction

Managing Azure Automation as Code is the final piece to managing the entire lifecycle of your Azure cloud resources. Azure Pipeline templates in a centralized repository resource provide developers a method to quickly create multistage pipelines with flexible parameters for standardizing the steps of jobs in each stage. Predefining automation tasks for code analysis, build, deployment, and testing of Azure resources with gated or automatic releases.

Traditionally, managing Azure classic build and release pipelines throughout an organization was difficult and easy for configuration to vary across projects with many snowflake pipelines. Putting the burden on developers and engineers to manage their pipelines manually. Taking the time away from experimentation and innovation. While Azure Pipeline YAML allows you to create multistage pipelines as code, defining the tasks inside of each repository is challenging. Often leading to inefficient steps and increased failure rate of builds and deployments.

## Getting Started

This repository stores [Azure Pipelines templates](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates) used to implement multistage Azure Pipelines using standardized methods with validated functionality. This reduces the time and cost of developing a strategy for developing and managing Azure Pipelines with YAML. Additionally, this repository includes documentation for implementation. Using design principles, patterns, and strategies for implementing Azure Pipelines.

### Repository Resource

To use the pipeline templates in this repository it must be listed as a resource in your pipeline YAML file. This allows you to reference paths in another repository by using the resource identifier.

The example below shows using a tagged reference of the AzurePipelines repo. Always reference a tag of an Azure Pipeline templates repository. Pipelines that reference a tag will always use that specific commit of the templates.

This also shows the repository resource using an endpoint named GitHub. Create a [GitHub service connection](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml#sep-github) if you have not already done so. Alternatively, you can fork this repository to your own GitHub or Azure Repos account and reference it instead.

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
  # file path to the template at the repository resource id to extend from
  template: stages.yaml@templates
  parameters:
    code: [] # jobList inserted into code stage in stages param
    build: [] # jobList inserted into build stage in stages param
    deploy: [] # deploymentList inserted into deploy stage in stages param
    test: [] # jobList inserted into test stage in stages param
    promote: [] # deploymentList inserted into promote stage in stages param
    reject: [] # deploymentList inserted into reject stage in stages param
    # The jobList and deploymentList above are inserted into the stage in stages matching the parameter name

  # stages: [] # Optional to override default of stages stageList
    stagesPrefix: '' # Optional stage name prefix. e.g. dev- would make dev-build, dev-deploy, etc.
    stagesSuffix: '' # Optional stage name suffix. e.g. Dev would make buildDev, deployDev, etc.
    stagesCondition: '' # Optional param to override the condition of all stages
```

### Repository Tagging

- **Major version**: breaking change to prior major version. Breaks when existing pipelines cannot update to the new version without implementing changes in existing pipelines.
- **Minor version**: no breaking changes to the major version. Incremental updates, including bug fixes and new features. Changes are additive and do not remove functionality.
- **Bug fix**: the latest release version tag of this repository may be deleted and recreated to fix an issue. So long as that does not break or change functionality. This is so that pipelines referencing this tag inherit that fix automatically without needing to change the tag reference in their code.

## Template Documentation

### Template Types

- **steps**: inserts tasks into steps with parameterized inputs and optionally additional stepLists
- **jobs**: inserts jobs from jobLists into a stage of stages with parameterized inputs
- **stages**: inserts stages from stageLists for multistage pipelines with parameterized inputs
- **pipeline**: nests stages, jobs, and steps templates into a single template to extend from with flexible parameters

### Stages Template

[Stages Template for Nesting Steps Templates](./docs/stages.md) into jobs of a stage. Provides an expression-driven stage creation for inserting steps templates into the jobs of a stage in stages. A stage is inserted into stages only when the stage has jobs and values for the minimum required parameters in the steps.

### Preset Templates

Preset templates abstract steps, jobs, and stages in a prescribed pattern that makes them easier to use. They provide parameters for flexiblity in variety of use cases as defined in it's description. Preset templates use the [stages](docs/stages.md) template combined with steps templates, listed in the stage sections below, in a prescribed pattern. However, those prescriptive patterns inherently limit flexibility to a degree which may make it unsuitable for some cases.

The key to pipeline templates is reusability.

- **steps template**: is a collection of common steps that can be used in other templates or directly
  - These are in the steps folder. Within subfolders, of the stage, they're intended for
- **stages template**: is a collection of stages and jobs within each stage, it does not limit what stages and jobs can be inserted
  - These are at the root of this repository
- **preset template**: uses steps and/or stage templates for a given use case
  - These are in the presets folder. Named in a way that represents their function and/or what templates they use

These preset templates use the [stages](./docs/stages.md) template and provide parameters to insert jobs, step templates, and/or step lists conditionally on the value of the preset template parameters.

- [Step Lists and Templates in Stages](./docs/presets/stepLists.md): Define Custom Steps or use Steps Templates for a single job in each stage
  - Advantage: flexible custom step lists and any single steps template per stage
  - Disadvantage: limited to a single job type or step list per stage but can use parallel strategies for that type of job
- [Predefined Template Jobs in Stages](./docs/presets/jobTypes.md): Parameters for inserting a list of jobs with predefined steps templates
  - Advantage: multiple jobs and multiple job types per stage. Predefined jobs with steps templates that are fully customizable
  - Disadvantage: limited to templates that have parameters to insert those jobs. e.g. parameters.dockerBuilds, dotNetBuilds, armDeployments, kubernetesDeployments, etc

### Code Stage

Steps templates to use within jobs in the code stage of the [stages](./docs/stages.md)

- [dotNet Test Static Code Analysis](./docs/steps/code/dotNetTests.md): Run dotNet test projects sequentially with tests parameter
- [SonarQube Static Code Analysis](./docs/steps/code/sonarQube.md): Run SonarQube for dotNet projects or solutions

### Build Stage

Steps templates to use within jobs in the build stage of the [stages](./docs/stages.md)

- [Build and Push Container Image](./docs/steps/build/containerImage.md): Build and push a docker image using an optional dotNet solution and dockerfile
- [Build and Publish Manifests Artifact from Helm Charts](./docs/steps/build/helmTemplate.md): Render Helm Charts with Helm Template cmd and deploy manifests to Kubernetes
- [Build, Publish, or Pack dotNet Projects and Publish Artifact](./docs/steps/build/dotNetCore.md): Build and publish a dotNet project without any tests
- [Pack and Push Nuget Artifacts](./docs/steps/build/nugetPackage.md): Build and pack a dotNet project to publish Nuget packages to an artifact feed

### Deploy Stage

Steps templates to use within jobs in the deploy stage of the [stages](./docs/stages.md)

- [Deploy ARM Templates](./docs/steps/deploy/armTemplate.md): Deploy an ARM template(s)
- [Deploy Helm Charts](./docs/steps/deploy/helmChart.md): Use Helm charts to deploy components to Kubernetes
- [Render Helm Charts and Deploy Manifests](./docs/steps/deploy/helmManifest.md): Render Helm Charts with Helm Template command and deploy manifests to Kubernetes
- [Deploy Kubernetes Manifests](./docs/steps/deploy/kubeManifest.md): Deploy Kubernetes manifests and secrets
- [Deploy Terraform Templates](docs/steps/deploy/terraformTemplate.md): run terraform steps -init, -plan, -validate, -apply, and -destroy with optional command options

### Test Stage

Steps templates to use within jobs in the test stage of the [stages](./docs/stages.md)

- [Visual Studio Tests](./docs/steps/test/visualStudioTest.md): Run VS Test suites in a dotNet project

### Promote or Reject Deployments

With several deployment strategies in the deploy stage, deployments can be promoted on success or rejected on failure. For example, when using a canary deployment strategy for Kubernetes manifests. It can conditionally promote the canary pods on the success of test jobs and the ready state of canary pods. If the test jobs have failures then deployment jobs in the reject stage automatically delete the deployments that are not functioning.

Additionally, these stages could use Infrastructure as Code (IaC) for blue/green deployments. For example, in the deploy stage, the green environment is deployed. Test the deployment and if they succeed swap the environments in the 'promote' stage. Promoting the green environment to blue and demoting the previous stack. Using the reject stage if the green stack fails.

#### Kubernetes Canary Strategy

- Deploy: Kubernetes deployment manifest canary pods
  - Deployment lifecycle hooks stepLists
- Test: the stage for functional tests of canaries. e.g. Visual Studio Tests
- Promote: Kubernetes canary deployment to baseline if test stage succeeded and the pods are in a ready state
- Reject: delete Kubernetes canary pods automatically if tests failed or pods not ready

#### Blue Green Strategy

- Deploy: Green IaC stack
  - Deployment lifecycle hooks stepLists with runOnce, rolling, or matrix strategies
- Test: the stage for functional tests of the green environment
- Promote: Swap endpoints of environments from green to blue and optionally delete the previous deployment
- Reject: delete green environment if tests failed

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
- Parameter names in steps templates should be the same as the task input name
  - Except when there are duplicates that should be prefixed with the task name
- Limit nesting templates to two levels
- Expressions no longer than ~100 char
- Only use pipeline variables for the replace tokens task or env vars in scripts

### Development Motivations

Azure Pipelines multistage YAML became generally available in April 2020. With this change in Azure build and release pipelines, now known as classic build and release pipelines, came a major shift in the design patterns for creating Azure Pipelines with YAML. Implementing YAML pipelines can be simple for smaller projects or when you have a single repository. However, when implementing pipeline YAML across multiple projects or repositories it can become extremely difficult to manage without a well-thought-out design strategy.

Developing Azure Pipeline YAML can be very time-consuming and costly without a good strategy. The motivation for this project and repository is to reduce the time and effort in implementing Azure Pipelines. By creating a centralized repository of pipeline templates that have been tried and tested functionality. With design patterns and anti-patterns that evolved from the development of pipeline templates across multiple projects, teams, and environments through to production.

### Strategic Design

It is important to use a strategy for developing that use a centralized pipeline template repository. When you have multiple repositories, projects, or teams if the pipeline YAML is created in each repository it is likely configurations will vary drastically from one pipeline to another. Making it impossible to standardize the design of pipelines. Using a centralized repository for pipeline templates solves this issue. It also accelerates the pace of innovation by removing the burden of developing each pipeline and ensuring each functional with limited failures.

### Validation Methods

One limitation of Azure Pipelines YAML, in general, is that the only way to validate the functionality of your pipeline is to run it. Linting of pipeline YAML is limited and does not cover templates and nesting. Additionally, the only way to generate the runtime YAML which compiles multiple templates and generates variables is to run it in Azure Pipelines.

There is not currently any way to validate Azure Pipelines YAML locally. This makes developing pipeline templates time-consuming and costly as you make a commit, run to validate, fail, commit, run again, and again. In the iterative development of these templates, there were often hundreds of commits and many, many, pipeline executions to validate. Even then it can be challenging to verify impacts to a change across templates that consume it. By utilizing this project you can greatly reduce the difficulty in adopting Azure Pipelines.

### Immutable Pipelines

When implementing immutable pipeline patterns, the current existing deployment image and configuration are unchanged when the pipeline is immutable. The current state does not mutate, i.e. immutable.

Using immutable automation patterns when an existing deployment’s state matches the code nothing is changed or mutated, it is immutable. Only changes are applied. Subsequent runs of idempotent and immutable automation would validate the state of a previously deployed resource against the commit invoking the automation.

For example with Kubernetes, terminate and deploy new pods or alter the deployment specifications. When you run a deployment pipeline manually from the same commit as the current deployment it would not change. However, it would validate the current running state matches the code commit.

### Idempotent Pipelines

When implementing idempotent automation patterns, subsequent runs are none additive and only changes to the code are built and deployed. Using dates and run count within the build number format is an anti-pattern as it’s not idempotent. Instead, use the repository name, branch/tag name, and commit ID for the build number format. This provides a pattern for idempotent CICD Pipelines.

### Build Number Format

The build number format is key to creating idempotent and immutable pipelines. The following format is recommended. By using this format the container image tag would not change if the code has not changed. Therefore subsequent runs of the CD pipeline would be immutable. Only manifest changes would be applied if the image is unchanged.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)
```

With immutable and idempotent pipelines running it without code changes would validate the current deployment state is unchanged from the code. When the current state of the object kind in the Kubernetes environment matches the manifest being applied it’s unchanged, verifying the current state to manifests in the commit.

This could also be referred to as Configuration Management or Resource Management with code. When a resource is modified outside of your code lifecycle this reflects configuration drift. Running the pipeline from a given release commit any configuration drift in the resource would be reverted. These methods provide a GitOps strategy to your Azure Pipelines.

## Azure Pipeline Concepts

### Build Verification Pipeline

A Build Verification Pipeline (BVP) is for Pull Requests (PR trigger). The code stage contains jobs for running static code analysis tasks including dotNet tests and SonarQube analysis. This stage is first and the build stage depends on it. The build stage contains jobs with tasks to dotNet build or publish artifacts. This could be a single pipeline for multiple repositories by adding repository resource triggers for each repository the pipeline needs to run for. By using a file naming convention you could use a file matching pattern in the dotNet project parameters to simplify the creation of a job for each repository you need to build project artifacts for.

### Continuous Integration Pipeline

Continuous Integration Pipelines (CIP) can be a CI trigger on the protected branch which your PR merges into. In the build stage container image job, the latest artifacts for the branch are downloaded. Alternatively, you could do the dotNet publish task before Docker build instead of as separate jobs. Docker builds the image then pushes it to a container registry with the tag using the build number format.

You could also use a CI Trigger on Feature and Release branches to run the build stage to dotNet publish the commit, build and push the container image to the registry. When the pipeline completes the CDP is triggered for the commit.

### Continuous Deployment Pipeline

Continuous Deployment Pipeline (CDP) can be triggered on CIP completion. The deploy stage deploys Azure Resource Manager (ARM) Templates, Kubernetes Manifests, Helm Charts, etc. Deployments can use a runOnce, canary, or rolling strategy lifecycle hooks.

You may choose to decouple build and deployment pipelines when you're deploying to multiple environments. When creating a CDP for a given environment you can, for example, add triggers for release branches prefixed with dev. So that your dev environment CDP is triggered for dev releases. Whereas your production environment pipeline is triggered when merged into the prod branch.

- release/dev\*
- release/prod\*

### Multistage Pipelines

Multistage pipeline templates can include stages for BVP, CIP, and CDP, into one template. When extending from that template it should insert the stages and jobs required conditionally if the parameters needed have values. Based on the requirements of your project you could create one CICD Pipeline that includes stages for build verification, integration, and deployment. Or you could create multiple pipelines decoupling build and deploy using pipeline completion triggers as discussed previously.

Typically, when deploying to one environment there would be one CICD pipeline. Whereas if you have multiple environments, it's best to create one pipeline for build and another for deployment to each environment. If you're using a deployment strategy such as canary or blue/green then this would be a single pipeline. Even though blue/green deployments are to multiple environments this is deployed with the lifecycle hooks in a single CDP.

When you have multiple environments for different projects, teams, or phases within a project then decouple your CI and CD pipelines. For example, a project where you deploy to a development environment, then integration testing environment, then finally to the production environment. With multiple CD pipelines, you could trigger them on completion of the CIP serially or in parallel depending on your needs.

### Automations Pipeline

Interestingly, Azure Pipelines can be used for more than just DevOps CICD needs. Essentially Azure Pipeline YAML defines event-triggered or scheduled jobs, the applications, and scripts, to run on agents in a pool of Virtual Machines or containers in a particular order and with runtime conditions, etc, etc. Therefore it could be leveraged for a variety of use cases. Such as Extract Transform Load (ETL) jobs that are a scheduled execution of an Azure Pipeline that runs jobs to extract data from a source, perform transformations on the data, and load it into a destination data lake or warehouse.

## Contributions

In working with pipelines there may be common steps that are not currently within this solution. While you can insert custom steps into jobs if they are needed for multiple pipelines it can be very beneficial to create reusable steps templates in this repository. The following sections cover general guidelines for contributing to this project.

### Branch Naming

Create a branch name based on what you'll be working on using the following naming convention

[ feat, fix ] / [ steps, presets, pipelines, docs, or assets ] / path / file

These are some example patterns for branch naming

- Feature in existing or new steps template
  - feat/steps/code/templateName
  - feat/steps/build/templateName
  - feat/steps/deploy/templateName
  - feat/steps/test/templateName
- Fix bugs in the existing steps template
  - fix/steps/path/templateName
- Fix errors in existing documentation
  - fix/docs/path/fileName
- Add content to existing documentation
  - feat/docs/path/fileName

### Commit Naming

Similarly commits should use the following naming convention

[ feat, fix ] ( steps, presets, docs, assets, ci, cd, cicd ) : description

- feat(steps): a new template for tasks
- feat(steps): added steps and params
- fix(steps): syntax error in expression
- fix(steps): updated parameter default
- feat(preset): added parameters and jobs for templates
- feat(preset): created a new template for stages and jobs
- fix(preset): corrected syntax error for expression
- feat(assets): new dockerfile for docker build tasks
- feat(assets): new kubernetes manifests for deployment jobs
- fix(assets): updated docker build arguments
- feat(docs): instructions for new template
- feat(docs): added section to readme
- fix(docs): corrected typos and grammar
- feat(ci): a pipeline to test code and build steps
- feat(cd): a pipeline to test deploy and test steps
- feat(cicd): a multistage pipeline to test jobs and steps

### Existing Templates

When working with existing templates it's important to maintain backward compatibility. For example, changing the name of an existing parameter would break functionality without needing to update the parameter name in other files. Steps and parameters should not be removed whenever possible. Instead, it may be acceptable to use parameters to conditionally insert those steps to provide an override.

### Steps Template Creation

When creating new steps templates it should be added to the appropriate folder of the stage the steps are typically used in. File names in camelCase that best represent the function of the steps. Follow the [design principles and patterns](#design-principals-and-patterns) discussed above.

### Preset Template Creation

Preset templates use other templates to create multistage pipelines utilizing parameters and conditional expressions.

### Test Pipelines

When implementing features or fixes for existing templates or creating new ones, a pipeline should be created to validate the syntax and functionality of the templates. These go in the pipelines folder of this repository.

## Microsoft Docs

General usage of templates is described [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops)
