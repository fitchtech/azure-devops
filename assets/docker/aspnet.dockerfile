ARG registry=mcr.microsoft.com
ARG repository=dotnet/aspnet
ARG tag=3.1-focal
ARG copy=.
ARG entrypoint=app.dll
FROM ${registry}/${repository}:${tag}
ENV entrypoint=${entrypoint}
EXPOSE 80
EXPOSE 443
USER 9000
WORKDIR /app
COPY ${copy} .
ENTRYPOINT ["dotnet", "${entrypoint}"]