# Samples

## Summary

This folder contains JSON files which can be used to test out yadsi. A good way would be to spin up a virtual machine, install Windows 11 on it, create snapshots after you followed the root readme and then execute the following in an elevated Windows Terminal:

```powershell
$gitRoot="https://raw.githubusercontent.com/codingfreak/yadsi/main";$now=(Get-Date).ToString("mmss");$def = "$gitRoot/samples/definition.demo.json?$now";$src="$gitRoot/scripts/yadsi.ps1?$now";Set-ExecutionPolicy Bypass -Scope Process -Force;curl $def -o definition.json | Out-Null;curl $src -o yadsi.ps1 | Out-Null;./yadsi.ps1 -DefinitionFile definition.json
```

This is a little bit overwhelming. I will guide you through. If you would write this as a posh script in a file this would be better readable. I will also add some comments for brevity.

```powershell
# define some variables
$gitRoot="https://raw.githubusercontent.com/codingfreak/yadsi/main"
$now=(Get-Date).ToString("mmss")
$def = "$gitRoot/samples/definition.demo.json?$now"
$src="$gitRoot/scripts/yadsi.ps1?$now"
# ensure that scripts can be executed
Set-ExecutionPolicy Bypass -Scope Process -Force
# download the needed files from GitHub
curl $def -o definition.json | Out-Null
curl $src -o yadsi.ps1 | Out-Null
# Execute the posh
./yadsi.ps1 -DefinitionFile definition.json
```

Nothing really fancy is happening. The `$now`-part is only there to prevent the posh command `curl` to cache downloads and to ensure that the uncached version is loaded every time.

You can execute this command any time because it will ask you for confirmation by default.

## Samples

### definition.demo.json

This file can be used to test some basic setups. I used it as an example in my YT video.