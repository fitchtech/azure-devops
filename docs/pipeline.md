# Azure Pipeline Templates

- [Azure Pipeline Templates](#azure-pipeline-templates)
  - [Introduction](#introduction)
  - [Repository Resource](#repository-resource)
  - [Read The Docs](#read-the-docs)
  - [Design Principals and Patterns](#design-principals-and-patterns)
    - [Build Verification Pipeline](#build-verification-pipeline)
    - [Continuous Integration Pipeline](#continuous-integration-pipeline)
    - [Continuous Deployment Pipeline](#continuous-deployment-pipeline)
  - [Idempotent and Immutable](#idempotent-and-immutable)
    - [Idempotent Pipelines](#idempotent-pipelines)
    - [Immutable Pipelines](#immutable-pipelines)
    - [Build Number Format](#build-number-format)

## Introduction

This repository stores templates to be used by azure-pipelines. It is recomended that you extend from the pipeline.yaml template.

## Repository Resource

To use the pipeline templates in this repository it must be listed as a resource in your pipeline YAML file. This allows you to reference paths in another repositoring by using the resource identifier.

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
  template: pipeline.yaml@templates
  parameters:
  # codeStages: stageList param to overrides default stages
  # - stage: codeAnalysis
  # codeAnalysis: jobList inserted into codeAnalysis stage in codeStages

  # devStages: stageList param to overrides default stages
  # - stage: devBuild | devDeploy | devPromote | devTests
  # devBuild: jobList inserted into devBuild stage in devStages
  # devDeploy: deploymentList inserted into devDeploy stage in devStages
  # devPromote: deploymentList inserted into devPromote stage in devStages
  # devTests: jobList inserted into devTests stage in devStages

  # dintStages: stageList param to override default stages
  # - stage: dintDeploy | dintPromote | dintTests
  # dintDeploy: deploymentList inserted into dintDeploy stage in dintStages
  # dintPromote: deploymentList inserted into dintPromote stage in dintStages
  # dintTests: jobList inserted into dintTests stage in dintStages

  # acptStages: stageList param to override default stages
  # - stage: acptBuild | acptDeploy | acptPromote | acptTests
  # acptBuild: jobList inserted into acptBuild stage in acptStages
  # acptDeploy: deploymentList inserted into acptDeploy stage in acptStages
  # acptPromote: deploymentList inserted into acptPromote stage in acptStages
  # acptTests: jobList inserted into acptTests stage in acptStages

  # prodStages: stageList param to override default stages
  # - stage: prodBuild | prodDeploy | prodPromote | prodTests
  # prodBuild: jobList inserted into prodBuild stage in prodStages
  # prodDeploy: deploymentList inserted into prodDeploy stage in prodStages
  # prodPromote: deploymentList inserted into prodPromote stage in prodStages
  # prodTests: jobList inserted into prodTests stage in prodStages
```

## Read The Docs

| Documentation                                                                    | Description                                                                    |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| [Static Code Analysis](steps/build/codeAnalysis.md)                              | Run SonarQube for dotNet and run dotNet test for unit and cli tests            |
| [Build Container Image](steps/build/containerImage.md)                           | Build and push a docker image using an optional dotnet solution and dockerfile |
| [Render Helm Charts and Publish Manifests Artifact](steps/build/helmTemplate.md) | Render Helm Charts with Helm Template cmd and deploy manifests to Kubernetes   |
| [Build dotNet Project and Publish Artifact](steps/build/dotNetCore.md)           | Build and publish a dotnet project without any tests                           |
| Pack and Push Nuget Artifacts                                                    | Build and pack a dotnet project to publish Nuget packages to a artifact feed   |
| [Deploy ARM Templates](steps/deploy/armTemplate.md)                              | Deploy an ARM template(s)                                                      |
| [Deploy Helm Charts](steps/deploy/helmChart.md)                                  | Use Helm charts to deploy components to Kubernetes                             |
| [Render Helm Charts and Deploy Manifests](steps/deploy/helmManifest.md)          | Render Helm Charts with Helm Template cmd and deploy manifests to Kubernetes   |
| [Deploy Kubernetes Manifests](steps/deploy/kubeManifest.md)                      | Deploy Kubernetes manifests and secrets                                        |
| Visual Studio Tests                                                              | Run VS Test suites in a dotNet project                                         |

## Design Principals and Patterns

- Pipeline templates no longer than ~300 lines
- Expressions no longer than ~100 char
- Parameters naming uses camelCase
- Parameter naming consistent across templates
- Nesting limited to two levels
- Only use pipeline variables for replace tokens and env vars

### Build Verification Pipeline

A Build Verification Pipeline (BVP) is for Pull Requests (PR trigger). This includes codeAnalysis stage for running dotNet tests and SonarQube static analysis job. Additionally the devBuild stage runs jobs for dotNet publish artifact and container image artifact publish. A dotNet and container image artifact for each app.

### Continuous Integration Pipeline

Continuous Integration Pipelines (CIP) can be triggered on BVP completion. The devBuild stage containerImage job downloads artifacts from the BVP. Runs white source scan of dotNet artifact and twistlock scan of image artifact then pushes image to Harbor container registry with the tag using the build number format.

Optionally you can add a CI Trigger on Feature and Release branches to run devBuild stage to dotNet publish the commit, build and push the container image to the registry. When the pipeline completes the CDP is triggered for the commit.

### Continuous Deployment Pipeline

Continuous Deployment Pipeline (CDP) can be triggered on CIP completion. The devDeploy stage deploys Azure Resource Manager (ARM) Templates, Kubernetes Manifests, and/or Helm Charts.

Optionally you can use conditions to deploy stages per environment based on the branch prefex of the triggering repository.

For release branches prefixed with dev, only devDeploy stage is run; when prefixed with dint, devDeploy and dintDeploy runs.

- release/dev\*
- release/dint\*
- release/acpt\*
- release/prod\*

## Idempotent and Immutable

### Idempotent Pipelines

When implementing idempotent pipelines patterns, subsequent runs are not additive if there are not changes to the code. Using dates and run count within the build number format is an anti-pattern as it’s not idempotent. Instead use the repository name, branch/tag name, and commit ID for the build number format. This provides a pattern for idempotent CI/CD Pipelines.

### Immutable Pipelines

When implementing immutable pipeline patterns, when an existing deployment image and pod spec is unchanged the current deployment is immutable. The current pod state does not mutate (i.e. terminate and deploy new pod or deploy canary).

### Build Number Format

The build number format is key to creating idempotent and immutable pipelines. The following format is recommended. By using this format the container image tag would not change if the code has not changed. Therefore subsequent runs of the CD pipeline would be immutable. Only manifest changes would be applied if the image is unchanged.

```yml
name: $(Build.Repository.Name)_$(Build.SourceVersion)_$(Build.SourceBranchName) # name is the format for $(Build.BuildNumber)
```

With immutable and idempotent pipelines running it without code changes would validate the current deployment state is unchanged from the code. When the current state of the object kind in the Kubernetes environment matches the manifest being applied it’s unchanged, verifying the current state to manifests in the commit.

This could also be referred to as Configuration Management of the Kubernetes resources. If the object had been changed manually, this is configuration drift. By running an immutable CDP any configuration drift in the current state of the Kubernetes objects would be reverted by applying manifests in the current commit.
