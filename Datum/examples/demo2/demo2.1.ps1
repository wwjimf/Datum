Import-Module $PSScriptRoot\..\..\Datum.psd1 -force

pushd $PSScriptRoot

$yml = Get-Content -raw $PSScriptRoot\datum.yml | ConvertFrom-Yaml

$datum = New-DatumStructure $yml


#Type this to see auto-completion 
$datum.Secured.secrets.MyCredentialObject