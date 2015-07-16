Set-ExecutionPolicy RemoteSigned

$proxy_host = "http://10.0.2.129"
$proxy_port = 3128
$no_proxy = "<local>;127.0.0.1;localhost"
$proxy_url = $proxy_host + ":" + $proxy_port

[Environment]::SetEnvironmentVariable("http_proxy", [String]$proxy_url, "Machine")
[Environment]::SetEnvironmentVariable("https_proxy", [String]$proxy_url,"Machine")
[Environment]::SetEnvironmentVariable("no_proxy", $no_proxy, "Machine")
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /f /v ProxyEnable /t reg_dword /d 1
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /f /v ProxyServer /t reg_sz /d $proxy_url
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /f /v ProxyOverride /t reg_sz /d $no_proxy
netsh winhttp set proxy proxy-server=$proxy_url bypass-list=$no_proxy

$ie = New-Object -ComObject InternetExplorer.Application
While($ie.Busy){ [Threading.Thread]::Sleep(300) }
$ie.Quit()

iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

choco install jdk8 -y
choco install jenkins --version 1.620.0.0 -y
choco install ruby --version 2.1.6 -y
choco install git -y
choco install nuget.commandline -y

$env:Path.split(";")
