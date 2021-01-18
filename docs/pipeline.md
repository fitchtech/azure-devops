# Azure Pipeline Templates

- [Azure Pipeline Templates](#azure-pipeline-templates)
  - [Pipeline Template](#pipeline-template)

## Pipeline Template

This repository stores templates to be used by azure-pipelines. It is recommended that you extend from the pipeline.yaml template.

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
  template: pipeline.yaml@templates
  parameters:
  # code: jobList inserted into code stage in stages param
  # build: jobList inserted into build stage in stages param
  # deploy: deploymentList inserted into deploy stage in stages param
  # promote: deploymentList inserted into promote stage in stages param
  # test: jobList inserted into test stage in stages param
  # reject: deploymentList inserted into reject stage in stages param
  # stages: stageList of stages. jobList or deploymentList inserted into stage with matching name
  # stagesPrefix # Optional stage name prefix. e.g. dev- would make dev-build, dev-deploy, etc.
  # stagesSuffix # Optional stage name suffix. e.g. Dev would make buildDev, deployDev, etc.
  # stagesCondition # Optional param to override the condition of all stages

```
