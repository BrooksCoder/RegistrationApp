# Dockerfile for .NET Core Backend

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file
COPY ["RegistrationApi.csproj", "."]

# Restore dependencies
RUN dotnet restore "RegistrationApi.csproj"

# Copy source code
COPY . .

# Build
RUN dotnet build "RegistrationApi.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
WORKDIR /src
RUN dotnet publish "RegistrationApi.csproj" -c Release -o /app/publish

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Install netcat for wait-for-db script
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

COPY --from=publish /app/publish .
COPY wait-for-db.sh /app/wait-for-db.sh
RUN chmod +x /app/wait-for-db.sh

EXPOSE 80

ENTRYPOINT ["/app/wait-for-db.sh", "sqlserver", "1433", "dotnet", "RegistrationApi.dll"]
