FROM mcr.microsoft.com/dotnet/sdk:9.0
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . ./
EXPOSE 80
ENV ASPNETCORE_ENVIRONMENT=Development
ENV ASPNETCORE_URLS=http://+:80
CMD ["dotnet", "watch", "run"]
