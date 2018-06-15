FROM microsoft/bcsandbox:us AS full
ENV ACCEPT_EULA Y
ENV username=autobuild \
    password=autopassword

ARG bc_release
    
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
COPY scripts c:/run/my
RUN .\Run\start.ps1

FROM microsoft/windowsservercore
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN mkdir c:\build
RUN mkdir c:\build\32
RUN mkdir c:\build\64
COPY --from=full c:/ForBuildStage/ c:/build
RUN Expand-Archive -Path (Get-ChildItem -Path c:\build\vsix -Filter "al*.zip")[0].FullName -DestinationPath c:\build\vsix
RUN Invoke-RestMethod -Uri https://tools.axians-infoma.de/signtool.exe -OutFile c:\build\signtool.exe
RUN Invoke-RestMethod -Uri 'https://tools.axians-infoma.de/Axians Infoma Code Signing.p12' -OutFile c:\build\signcert.p12
COPY --from=full C:/Windows/System32/NavSip.dll C:/build/32/
COPY --from=full C:/Windows/SysWoW64/NavSip.dll C:/build/64/
COPY --from=full C:/Windows/System32/msvcr120.dll C:/Windows/System32/
