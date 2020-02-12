FROM microsoft/dotnet:sdk AS build-env
WORKDIR /app/LIS.API
COPY . /app
RUN dotnet restore
RUN dotnet publish -c Release -o out

FROM microsoft/dotnet:aspnetcore-runtime
RUN apt-get update \
        && apt-get install -y --allow-unauthenticated \
        libc6-dev \
        libgdiplus \
        libx11-dev \
        && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build-env /app/LIS.API/out .
ENV ASPNETCORE_URLS=http://+:63195
ENTRYPOINT ["dotnet", "LIS.API.dll"]