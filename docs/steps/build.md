# Build Job Documentation

| Documentation                                                                | Description                                                                                                                                                      |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Build Container Image](./build/containerImage.md)                           | Build and push a docker image using an optional dotNet solution and dockerfile                                                                                   |
| [Render Helm Charts and Publish Manifests Artifact](./build/helmTemplate.md) | Render Helm Charts with Helm Template cmd and deploy manifests to Kubernetes                                                                                     |
| [Build dotNet Project and Publish Artifact](./build/dotNetCore.md)           | Build and publish a dotNet project without any tests                                                                                                             |
| [Pack and Push Nuget Package](./build/nugetPackage.md)                       | A wrapper for the [dotNetCore](./build/dotNetCore.md) steps template with parameterized defaults for pack and push of Nuget Packages to a Azure or external feed |
