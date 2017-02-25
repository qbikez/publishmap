if ($null -eq $global:cache) {
    $global:cache = @{}
}


function import-publishmap {
    [cmdletbinding()]
    param([Parameter(Mandatory=$false)] $maps = $null, [alias("nocache")][switch][bool]$force)
    
    if ($force) {
            $global:cache = @{}
    }

    if ($maps -is [System.Collections.IDictionary] ) {
        return import-publishmapobject $maps
    }    
    else {
        return import-publishmapfile $maps
    }
}



function import-publishmapfile {
    [cmdletbinding()]
    param($maps)
     write-verbose "processing publishmap..."

    $global:publishmap = $null

    if ($null -ne $maps) {
        $maps = @($maps)
    }
    else {
        $maps = get-childitem . -filter "publishmap.*.config.ps1"
    }

    $publishmap = @{}

    foreach($file in $maps) {
        try {
            $fullname = $file
            if ($null -ne $fullname.FullName) { $Fullname =$Fullname.FullName }
            $cached = get-cachedobject $fullname
            if ($null -ne $cached) {
                write-verbose "loading publishmap '$fullname' from cache"
                $pmap = $cached.value
            }
            else {
                $map = & "$FullName"
        
                #$publishmap_obj = ConvertTo-Object $publishmap
                $pmap = import-publishmapobject $map
                set-cachedobject $fullname $pmap
            }
            $publishmap += $pmap
        } catch {
            write-error "failed to import map file '$file'"
            throw
        }
    }

    $global:publishmap = $publishmap
    $global:pmap = $global:publishmap 

    write-verbose "processing publishmap... DONE"

    return $publishmap
}

function import-publishmapobject {
    [cmdletbinding()]
    param($map) 
    
    $map = preporcess-publishmap $map
    $pmap = import-mapobject $map
    $pmap = postprocess-publishmap $pmap
    
    return $pmap           
}

<#
.Synopsis 
 * inherits properties from global `settings` node
 * generates `_staging` and `swap_` profiles
#>
function preporcess-publishmap($map) {
    $globalprofilesname = "global_profiles"
    foreach($groupk in get-propertynames $map) {
        if ($null -ne $map.$groupk.$globalprofilesname) {
            $settings = @{     
                profiles = $map.$groupk.$globalprofilesname 
                _strip = $true
            } 
            $null = add-property $map.$groupk -name "settings" -value $settings -merge
        }
    }
    foreach($groupk in get-propertynames $map) {
        foreach($projk in get-propertynames $map.$groupk) { 
            foreach($profk in get-propertynames $map.$groupk.$projk.profiles) { 
                $shouldcreatestaging = ($profk -notmatch "_staging") -and ($profk -notmatch "swap_") -and ($map.$groupk.$projk.profiles.$profk -is [System.Collections.IDictionary])
                
                if ($shouldcreatestaging) {
                    $stagingkey = "$($profk)_staging"    
                    $swapkey= "swap_$($profk)"
                    if ($null -eq $map.$groupk.$projk.profiles.$stagingkey) { $map.$groupk.$projk.profiles.$stagingkey = @{ 
                        "_autogenerated" = $true
                        "_inherit_from" = $profk
                        "_postfix" = "-staging"
                     } 
                    }
                    if ($null -eq $map.$groupk.$projk.profiles.$swapkey) { $map.$groupk.$projk.profiles.$swapkey = @{ 
                        "_autogenerated" = $true
                        "_inherit_from" = $profk
                     } } 
                }
            }
        }
    }
    
    return $map
}

<#
.Synopsis
* adds profile links at project level
* processes inheritance basing on `_inherit_from` properties  
#>
function postprocess-publishmap($map) {    
    foreach($groupk in get-propertynames $map) {
        # remove generated properties from top-level
        if ($groupk.startswith("_")) {
            $map.Remove($groupk)
            continue
        }
        $group = $map.$groupk
        foreach($projk in get-propertynames $group) {
            $proj = $group.$projk
            if ($null -ne $proj.profiles) {
                foreach($profk in get-propertynames $proj.profiles) {
                    $prof = $proj.profiles.$profk
                    if ($prof -is [System.Collections.IDictionary]) {
                        # set full path as if profiles were created at project level
                        $null = add-property $prof -name _fullpath -value "$groupk.$projk.$profk" -overwrite
                        $null = add-property $prof -name _name -value "$profk" -overwrite
                        # use fullpath for backward compatibility       
                        $null = add-property $prof -name fullpath -value $prof._fullpath -overwrite
                        # expose project at profile level
                        $null = add-property $prof -name project -value $proj
                    } else {
                        #remove every property that isn't a real profile
                        $proj.profiles.Remove($profk)
                    }
                    if ($null -ne $prof._inherit_from) {
                        if ($proj.profiles.$($null -eq $prof._inherit_from)) {
                            write-warning "cannot find inheritance base '$($prof._inherit_from)' for profile '$($prof._fullpath)'"
                        } else { 
                            $cur = $prof
                            $hierarchy = @()
                            while($null -ne $cur._inherit_from -and $null -eq $cur._inherited_from) {                                
                                $hierarchy += $cur
                                $base = $proj.profiles.$($cur._inherit_from)
                                $cur = $base
                            }
                            for($i = ($hierarchy.length - 1); $i -ge 0; $i--) {
                                $cur = @($hierarchy)[$i]
                                $base = $proj.profiles.$($cur._inherit_from)
                                inherit-properties -from $base -to $cur -valuesonly -exclude @("_inherit_from","_inherited_from")
                                $null = add-property $cur -name _inherited_from  -value $($cur._inherit_from)
                            }
                            
                        }
                    }
                }
                # expose profiles at project level
                $null = add-properties $proj $proj.profiles -merge -ifNotExists

                
            }
            # use fullpath for backward compatibility
            if ($proj._fullpath) {
                $null = add-property $proj -name fullpath -value $proj._fullpath -overwrite
            }
        }

        # use fullpath for backward compatibility
        if ($group._fullpath) {
            $null = add-property $group -name fullpath -value $group._fullpath -overwrite
        }
        
    }
    return $pmap
}

function get-profile($name, $map = $null) {
            $pmap = $map
            if ($null -eq $map) {
                $pmap = $global:pmap
            }

            $profName = $name
            $splits = $profName.Split('.')

            $map = $pmap
            $entry = $null
            $parent = $null
            $isGroup = $false
            for($i = 0; $i -lt $splits.length; $i++) {
                $split = $splits[$i]
                $parent = $entry
                if ($i -eq $splits.length-1) {
                    $entry = get-entry $split $map -excludeProperties @("project")             
                }
                else {
                    $entry = $map.$split
                }
                if ($null -eq $entry) {
                    break
                }
                if ($null -ne $entry -and $null -ne $entry.group) {
                    $isGroup = $true
                    break
                }
                $map = $entry
            }    
            $profile = $entry
            if ($null -eq $profile)  {
                if ($splits[1] -eq "all") {
                    $isGroup = $true
                    $profile = $parent
                    break
                }
                else {
                    #write-host "unknown profile $profName"
                    return $null
                }
            }

            return new-object -Type pscustomobject -Property @{
                Profile = $profile
                IsGroup = $isGroup
                Project = $splits[0]
                Group = $splits[1]
                TaskName = $splits[2]
            }
}



function check-profileName($proj, $profk) {
                $prof = $proj.profiles.$profk
                if ($null -eq $prof) {
                    
                    if ($proj.inherit -ne $false) {
                        $prof = @{}
                        if ($null -eq $proj.profiles) {
                            $null = add-property $proj -name "profiles" -value @{}
                        }
                        $null = add-property $proj.profiles -name $profk -value $prof
                    }
                    else {
                        continue
                    }
                }
}

<#

function __import-mapproject($proj) {
            #proj = viewer,website,drmserver,vfs, etc.
            #$proj = $group[$projk]
            
            inherit-globalsettings $proj $settings $stripsettingswrapper
            
            $profiles = @()
            if ($null -ne $proj.profiles) {
                $profiles += get-propertynames $proj.profiles
            }
            if ($null -ne $globalProffiles) {
                $profiles += get-propertynames $globalProffiles
            }
            $profiles = $profiles | select -Unique
            #write-host "$groupk.$projk"
                
            foreach($profk in $profiles) {
                  check-profileName $proj $profk            
                  $prof = $proj.profiles.$profk
                  import-mapprofile $prof -parent $proj     
                  $null = add-property $proj -name $profk -value $prof
            }
}


function __import-mapprofile($prof, $parent) {
   # make sure all profiles exist
                
                #inherit settings from project
                inherit-properties -from $parent -to $prof -exclude (@("profiles") + $profiles + @("level","fullpath"))

                #inherit global profile settings
                if ($null -ne $globalProffiles -and $null -ne $globalProffiles.$profk -and $prof.inherit -ne $false -and $parent.inherit -ne $false) {
                    # inherit project-specific settings 
                    #foreach($prop in $globalProffiles.$profk.psobject.properties | ? { $_.name -eq $projk }) {
                    #    if ($prop.name -eq $projk) {
                    $global = $globalProffiles.$profk
                    inherit-properties -from $global -to $prof
                    #    }
                    #}                    
                    # inherit generic settings
                    inherit-properties -from $settings -to $prof                   
                }
                $null = add-property $prof "_level" 3

                #fill meta properties
                $null = add-property $prof -name _parent -value $parent
                #add-property $prof -name fullpath  -value "$groupk.$projk.$profk"
                $null = add-property $prof -name _name -value "$profk"               
                
}

#>
