# Azure Pipeline Templates

- [Azure Pipeline Templates](#azure-pipeline-templates)
  - [Introduction](#introduction)
  - [Repository Resource](#repository-resource)
  - [Template Documentation](#template-documentation)
  - [Design Principals and Patterns](#design-principals-and-patterns)
    - [Build Verification Pipeline](#build-verification-pipeline)
    - [Continuous Integration Pipeline](#continuous-integration-pipeline)
    - [Continuous Deployment Pipeline](#continuous-deployment-pipeline)
  - [Idempotent and Immutable](#idempotent-and-immutable)
    - [Idempotent Pipelines](#idempotent-pipelines)
    - [Immutable Pipelines](#immutable-pipelines)
    - [Build Number Format](#build-number-format)
  - [Microsoft Docs](#microsoft-docs)

## Introduction

This repository stores templates to be used by azure-pipelines. It is recommended that you extend from the pipeline.yaml template.

## Repository Resource

To use the pipeline templates in this repository it must be listed as a resource in your pipeline YAML file. This allows you to reference paths in another repository by using the resource identifier.

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
    promote: [] # deploymentList inserted into promote stage in stages param
    test: [] # jobList inserted into test stage in stages param
    reject: [] # deploymentList inserted into reject stage in stages param
    # The jobList and deploymentList above are inserted into the stage in stages matching the parameter name
    # stages: [] # Optional to override default of stages stageList.
    stagesPrefix: "" # Optional stage name prefix. e.g. dev- would make dev-build, dev-deploy, etc.
    stagesSuffix: "" # Optional stage name suffix. e.g. Dev would make buildDev, deployDev, etc.
    stagesCondition: "" # Optional param to override the condition of all stages
```

## Template Documentation

| Documentation                                                                           | Type            | Description                                                                                  |
| --------------------------------------------------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------- |
| [stages](./docs/stages.md)                                                              | stageList and jobList | Multistage pipeline template. Expression driven stage creation for inserting steps templates |
| [dotNet Test Static Code Analysis](./docs/steps/code/dotNetTests.md)                    | stepList           | Run SonarQube for dotNet and run dotNet test for unit and cli tests                          |
| [SonarQube Static Code Analysis](./docs/steps/code/sonarQube.md)                        | stepList           | Run SonarQube for dotNet projects or solutions                                               |
| [Build Container Image](./docs/steps/build/containerImage.md)                           | stepList           | Build and push a docker image using an optional dotNet solution and dockerfile               |
| [Render Helm Charts and Publish Manifests Artifact](./docs/steps/build/helmTemplate.md) | stepList           | Render Helm Charts with Helm Template cmd and deploy manifests to Kubernetes                 |
| [Build dotNet Project and Publish Artifact](./docs/steps/build/dotNetCore.md)           | stepList           | Build and publish a dotNet project without any tests                                         |
| Pack and Push Nuget Artifacts                                                           | stepList           | Build and pack a dotNet project to publish Nuget packages to an artifact feed                |
| [Deploy ARM Templates](./docs/steps/deploy/armTemplate.md)                              | stepList           | Deploy an ARM template(s)                                                                    |
| [Deploy Helm Charts](./docs/steps/deploy/helmChart.md)                                  | stepList           | Use Helm charts to deploy components to Kubernetes                                           |
| [Render Helm Charts and Deploy Manifests](./docs/steps/deploy/helmManifest.md)          | stepList           | Render Helm Charts with Helm Template cmd and deploy manifests to Kubernetes                 |
| [Deploy Kubernetes Manifests](./docs/steps/deploy/kubeManifest.md)                      | stepList           | Deploy Kubernetes manifests and secrets                                                      |
| Visual Studio Tests                                                                     | stepList           | Run VS Test suites in a dotNet project                                                       |

## Design Principals and Patterns

- Templates encapsulating steps: are no longer than ~500 lines
- Templates encapsulating stages: are no longer than ~1000 lines
- Expressions no longer than ~100 char
- Parameters naming uses camelCase
- Parameter naming consistent across templates
- Nesting limited to two levels
- Only use pipeline variables for replace tokens and env vars

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
