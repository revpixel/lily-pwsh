FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# Update base image packages + install prerequisites + Microsoft repo + PowerShell
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y wget apt-transport-https software-properties-common && \
    wget -q https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Ship the module installer inside the image. A bind mount on /mnt/repo-scripts
# (as run-pwsh.sh does) still overrides this copy with the live repo version.
COPY scripts/Install-AzureModules.ps1 /mnt/repo-scripts/Install-AzureModules.ps1

ENTRYPOINT ["pwsh"]

# -NoExit keeps this one shell open after the reminder, so `exit` leaves the container
# directly instead of first dropping back into an outer pwsh.
CMD ["-NoLogo", "-NoExit", "-Command", "Write-Host 'Reminder: Run /mnt/repo-scripts/Install-AzureModules.ps1' -ForegroundColor Yellow"]
