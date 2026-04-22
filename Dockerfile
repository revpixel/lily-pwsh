FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites + Microsoft repo + PowerShell
RUN apt-get update && \
    apt-get install -y wget apt-transport-https software-properties-common && \
    wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["pwsh"]

CMD ["-NoLogo", "-Command", "Write-Host 'Reminder: Run ./mnt/data/bootstrap/Install-AdminModules.ps1' -ForegroundColor Yellow; pwsh"]
