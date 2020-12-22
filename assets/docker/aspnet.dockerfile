ARG registry=harbor.pks.tm.dev1.premera.cloud
ARG repository=baseimages/dotnet/core/aspnet
ARG tag=3.1-bionic
ARG componentName=default
FROM ${registry}/${repository}:${tag}
ENV copyPath=/Publish/$componentName
ENV entrypointPath=$componentName.dll
EXPOSE 80
EXPOSE 443
USER 9000
WORKDIR /app
COPY $copyPath .
ENTRYPOINT ["dotnet", $entrypointPath]