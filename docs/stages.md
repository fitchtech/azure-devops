# Azure Pipeline Multistage Template

- [Azure Pipeline Multistage Template](#azure-pipeline-multistage-template)
  - [Stages Template Usage](#stages-template-usage)
  - [Templates Repository Resource](#templates-repository-resource)

## Stages Template Usage

- The [stages](../stages.yaml) template encapsulates stages for a multistage pipeline that uses expressions to conditionally insert each stage and dependency if the stage has jobs listed
- Insert jobs into a stage by using the jobList or deploymentList parameter with the same name as the stage in stages parameter
- **code:** jobList of static code analysis jobs. Conditionally run when triggered by Pull Request (PR) or manual execution
- **build:** jobList of build jobs. For example, dotNet build, docker build, etc.
- **deploy:** deploymentList of deployment jobs. For example, deploy ARM Template, deploy Kubernetes manifest, etc.
- **test:** jobList of test jobs to run after deploy stage. For example, after deploying canary run Visual Studio Test job for functional test of the deployment
- **promote:** dependent on deploy and test job success, promote the deployment in or to an environment. For example, with a canary strategy, promote the canary in deploy stage to baseline if successfully running
- **reject:** dependent on deploy, test, and promote if the stage has jobs and the stage failed. Jobs to reject a failed deployment, so that a deployment that is not functioning is automatically deleted
- **stages:** default: code, build, deploy, test, promote, and reject stages
  - Optional parameter to override the stageList default to add stages or update the dependencies or conditions of predefined stages
- **stagesPrefix:** or **stagesSuffix:** parameters to optionally add a prefix or suffix respectively to the name of all stages
  - stagesSuffix: Dev would make stages named buildDev, deployDev, etc.
  - stagesPrefix: 'dev-' would make stages named dev-build, dev-deploy, etc.
- **stagesCondition:** parameter to optionally override the condition of all stages within the stages stageList

## Templates Repository Resource

To use the [stages](../stages.yaml) template in this repository the pipeline YAML file in your repository must include a resource named templates referencing this AzurePipelines repository. This allows you to reference paths in the repository resource by using the resource identifier.

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
    stagesPrefix: '' # Optional stage name prefix. e.g. dev- would make dev-build, dev-deploy, etc.
    stagesSuffix: '' # Optional stage name suffix. e.g. Dev would make buildDev, deployDev, etc.
    stagesCondition: '' # Optional param to override the condition of all stages
```
