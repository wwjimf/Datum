Class FileProvider {
    hidden $Path
    hidden [hashtable] $Store
    hidden [hashtable] $DatumHierarchyDefinition
    hidden [hashtable] $StoreOptions
    hidden [hashtable] $DatumHandlers
    hidden [datetime]  $CachedTimestamp
    hidden [timespan]  $TTL
    hidden [hashtable] $CachedChildren

    FileProvider ($Path,$Store,$DatumHierarchyDefinition)
    {
        $this.Store = $Store
        $this.DatumHierarchyDefinition = $DatumHierarchyDefinition
        $this.StoreOptions = $Store.StoreOptions
        $this.Path = Get-Item $Path -ErrorAction SilentlyContinue
        $this.DatumHandlers = $DatumHierarchyDefinition.DatumHandlers
        Get-ChildItem $path | ForEach-Object{
            if(!$this.CachedChildren.contains($_.BaseName)) {
                $this.CachedChildren.add(
                    $_.BaseName,
                    @{
                        Path = $_
                        CachedValue = $null
                        CacheTimeStamp = $null
                        CacheTTL = $null
                    }
                )
            }
        }
        $this.CachedChildren.keys.Foreach{
            $ScriptBlock = [scriptblock]::Create("`$this.GetValue('$_')")
            $this | Add-Member -MemberType ScriptProperty -Name $_ -Value $ScriptBlock
        }

        # $Result = Get-ChildItem $path | ForEach-Object {
        #     if($_.PSisContainer) {
        #         $val = [scriptblock]::Create("New-DatumFileProvider -Path `"$($_.FullName)`" -StoreOptions `$this.StoreOptions -DatumHierarchyDefinition `$this.DatumHierarchyDefinition")
        #         $this | Add-Member -MemberType ScriptProperty -Name $_.BaseName -Value $val
        #     }
        #     else {
        #         $val = [scriptblock]::Create("Get-FileProviderData -Path `"$($_.FullName)`" -DatumHandlers `$this.DatumHandlers")
        #         $this | Add-Member -MemberType ScriptProperty -Name $_.BaseName -Value $val
        #     }
        # }
    }

    GetValue($ItemKey)
    {
        if($this.CachedChildren) {
            
        }
        
        if(!$this.CachedValue -or ($this.CachedTimestamp + $this.TTL -lt ([datetime]::Now))) {
            $this.ChachedValue = New-DatumFileProvider -Path $this.Path -StoreOptions $this.StoreOptions -DatumHierarchyDefinition $this.DatumHierarchyDefinition
            $this.CachedTimestamp = [datetime]::Now
            $this.ChachedValue
        }
        else {
            $this.ChachedValue
        }
    }

    SetValue()
    {

    }
}