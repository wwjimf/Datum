﻿Param (
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath (Join-Path $PSScriptRoot '../..' -Resolve -ErrorAction SilentlyContinue)),

    [string]
    $ProjectName = (property ProjectName (Split-Path -Leaf (Join-Path $PSScriptRoot '../..')) ),

    [string]
    $SourceFolder = $ProjectName,

    [string]
    $BuildOutput = (property BuildOutput 'C:\BuildOutput'),
    
    [string]
    $ModuleVersion = (property ModuleVersion $(
        if($ModuleVersion = Get-NextPSGalleryVersion -Name $ProjectName -ea 0) { $ModuleVersion } else { '0.0.1' }
        )),

    $MergeList = (property MergeList @('enum*','class*','priv*','pub*') ),
    
    [string]
    $LineSeparation = (property LineSeparation ('-' * 78))

)

Task CopySourceToModuleOut {
    $LineSeparation
    "`t`t`t COPY SOURCE TO BUILD OUTPUT"
    $LineSeparation

    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    $BuiltModuleFolder = [io.Path]::Combine($BuildOutput,$ProjectName)
    "Copying $ProjectPath\$SourceFolder To $BuiltModuleFolder\"
    Copy-Item -Path "$ProjectPath\$SourceFolder" -Destination "$BuiltModuleFolder\" -Recurse -Force -Exclude '*.bak'
}

Task MergeFilesToPSM1 {
    $LineSeparation
    "`t`t`t MERGE TO PSM1"
    $LineSeparation
    "`tORDER: $($MergeList.ToString())"
    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    $BuiltModuleFolder = [io.Path]::Combine($BuildOutput,$ProjectName)
    if(!$MergeList) {$MergeList = @('enum*','class*','priv*','pub*') }

    # Merge individual PS1 files into a single PSM1, and delete merged files
    $OutModulePSM1 = [io.path]::Combine($BuiltModuleFolder,"$ProjectName.psm1")
    "Merging to $OutModulePSM1"
    $MergeList | Get-MergedModule -DeleteSource -SourceFolder $BuiltModuleFolder | Out-File $OutModulePSM1 -Force
}

Task CleanOutputEmptyFolders {
    $LineSeparation
    "`t`t`t REMOVE EMPTY FOLDERS"
    $LineSeparation
    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }

    Get-ChildItem $BuildOutput -Recurse -Force | Sort-Object -Property FullName -Descending | Where-Object {
        $_.PSIsContainer -and
        $_.GetFiles().count -eq 0 -and
        $_.GetDirectories().Count -eq 0 
    } | Remove-Item
}

Task UpdateModuleManifest {
    $LineSeparation
    "`t`t`t UPDATE MODULE MANIFEST"
    $LineSeparation

    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    $BuiltModule = [io.path]::Combine($BuildOutput,$ProjectName,"$ProjectName.psd1")
    #Set-ModuleFunctions -Path $BuiltModule
    "`tBuilt Module PSD1: $BuiltModule"
    
        $ModuleFunctions = (gci "$ProjectPath\$ProjectName\Public\").BaseName
        Update-Metadata -path $BuiltModule -PropertyName FunctionsToExport  -Value $ModuleFunctions
    
    if($ModuleVersion) {
        Update-Metadata -path $BuiltModule -PropertyName ModuleVersion -Value $ModuleVersion
    }
}