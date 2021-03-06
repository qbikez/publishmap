. $PSScriptRoot\includes.ps1

import-module Pester
#import-module PublishMap

Describe "parse map object with variables" {
  
  
     Context "when map references properties" {
      $m = @{
          test1 = @{
              settings = @{
                abc = "inherited"               
              }
              global_profiles = @{
                      parent_property = "this_is_from_parent"
                      prod_XX_ = @{
                          name = "prod{XX}"
                      }
                      prod = @{  
                          what = "something"
                          test = "v{what}v"   
                          from_parent = "v{parent_property}v"               
                      }
                  }
              default_with_stub = @{             
                  profiles = @{
                      prod_XX_ = @{
                          url2 = "http://test:{XX}443/something"
                          url1 = "http://test:{vars.XX}443/something"    
                          urls = @(
                              "http://test:{XX}443/something"
                              "http://test:{vars.XX}443/something"  
                          )                                               
                      }
                  }                       
              }
              override_parent = @{
                  parent_property = "voverridenv"
              }
              override_parent_with_stub = @{
                  parent_property = "overriden"         
                  profiles = @{
                  }          
              }
              default = @{     
              }
              override = @{
                  parent_property = "overriden"         
              }
              
            }
        }
        
        $map = import-publishmap $m

        It "Should replace generic profile" {
            $id = 11
            $e = get-entry "prod$id" $map.test1.default_with_stub
            $e.name | Should Be "prod$id"
            $e.url1 | Should Be "http://test:$($id)443/something"
            $e.url2 | Should Be "http://test:$($id)443/something"
            $e.urls[0] | Should Be "http://test:$($id)443/something"
            $e.urls[1] | Should Be "http://test:$($id)443/something"           
        }
        
          It "replace Should not leave artifacts in source map" {
            $id = 13
            $e = get-entry "prod$id" $map.test1.default_with_stub
            $e.name | Should Be "prod$id"
            $e.url1 | Should Be "http://test:$($id)443/something"
            $e.url2 | Should Be "http://test:$($id)443/something"
            $e.urls[0] | Should Be "http://test:$($id)443/something"
            $e.urls[1] | Should Be "http://test:$($id)443/something"   

            $id = 14
            $e = get-entry "prod$id" $map.test1.default_with_stub
            $e.name | Should Be "prod$id"
            $e.url1 | Should Be "http://test:$($id)443/something"
            $e.url2 | Should Be "http://test:$($id)443/something"
            $e.urls[0] | Should Be "http://test:$($id)443/something"
            $e.urls[1] | Should Be "http://test:$($id)443/something"   
        }
        
        It "Should get standard properties with stubs" {
            try {
            $e = get-entry "prod" $map.test1.default_with_stub
            $e | Should Not BeNullOrEmpty
            $e.what | Should Be "something"
            } catch {
                throw
            }
        }
        
        It "Should replace property variables with stubs" {
            $e = get-entry "prod" $map.test1.default_with_stub
            $e | Should Not BeNullOrEmpty
            $e.test | Should Be "v$($e.what)v"
            #$e.from_parent | Should Be "v$($map.test1.global_profiles.parent_property)v"
            $e.from_parent | Should Be "vthis_is_from_parentv"
        }
        
         It "Should replace overriden property variables with stubs" {
            $e = get-entry "prod" $map.test1.override_parent_with_stub
            $e | Should Not BeNullOrEmpty
            $e.test | Should Be "v$($e.what)v"
            #$e.from_parent | Should Be "v$($map.test1.global_profiles.)v"
            $e.from_parent | Should Be "voverridenv"
        }
        
        It "Should get standard properties without stubs" {
            $e = get-entry "prod" $map.test1.default
            $e | Should Not BeNullOrEmpty
            $e.what | Should Be "something"
        }
        
        It "Should replace property variables without stubs" {
            $e = get-entry "prod" $map.test1.default
            $e | Should Not BeNullOrEmpty
            $e.test | Should Be "v$($e.what)v"
        }
        
        It "Should replace parent property variables without stubs" {
            $e = get-entry "prod" $map.test1.default

            Set-TestInconclusive "this is a feature request"
            <#
            $e | Should Not BeNullOrEmpty
            # cannot replace when a property does not exist, right?
            $e.parent_property | Should Not BeNullOrEmpty
            #$e.from_parent | Should Be "v$($map.test1.global_profiles.parent_property)v"
            $e.from_parent | Should Be "vthis_is_from_parentv"
            #>
        }
        
        It "Should replace overriden property variables without stubs" {
            Set-TestInconclusive "this is a feature request"
            <#
        
            $e = get-entry "prod" $map.test1.override_parent
            $e | Should Not BeNullOrEmpty

            # cannot replace when a property does not exist, right?
            $e.parent_property | Should Not BeNullOrEmpty
            $e.test | Should Be "v$($e.what)v"
            #$e.from_parent | Should Be "v$($map.test1.global_profiles.parent_property)v"
            $e.from_parent | Should Be "voverridenv"
            #>
        }
        
    }
  
  Context "when map references variables only" {
      $m = @{
          test = @{
              settings = @{
                abc = "inherited"               
              }
              global_profiles = @{
                      parent_property = "parent_property"
                      prod_XX_ = @{  
                          what = "what-prod{XX}"
                      }
                  }
              default_with_stub = @{    
                   profiles = @{
                      prod_XX_ = @{
                          
                      }
                  }                                
              }
              override_parent_with_stub = @{
                  parent_property = "overriden"
                  profiles = @{
                      prod_XX_ = @{
                          
                      }
                  }
              }
               default = @{    
              }
              override_parent = @{
                  parent_property = "overriden"
              }
              vars_from_pros = @{
                  path1 = "svc"
                  path2 = "test"
                  url_single_var = "http://{path1}"
                  url_multi_var = "http://{path1}/{path2}"
                  url_default_val = "http://{path1}/{?path2}/{?path_optional}"
                  url_missing_val = "http://{path1}/{path2}/{path_required}"
              }
              
            }
        }

        $map = import-publishmap $m
        
        It "Should Replace property variables with stub" {
            $e = get-entry "prod13" $map.test.default_with_stub
            $e | Should Not BeNullOrEmpty
            $e.what | Should Be "what-prod13"
            $e.parent_property | Should Be "parent_property"
        }
        It "Should override parent variables with stub" {
            $e = get-entry "prod13" $map.test.override_parent_with_stub
            $e | Should Not BeNullOrEmpty
            $e.what | Should Be "what-prod13"
            $e.parent_property | Should Be "overriden"
        }
        It "Should Replace property variables without stub" {
            $e = get-entry "prod13" $map.test.default
            $e | Should Not BeNullOrEmpty
            $e.what | Should Be "what-prod13"
        }
        It "Should Replace parent property variables without stub" {
            $e = get-entry "prod13" $map.test.default
            $e | Should Not BeNullOrEmpty
            Set-TestInconclusive "this is a feature request"
         <#
            $e.parent_property | Should Be "parent_property"
            #>
        }
        It "Should override parent variables without stub" {
            $e = get-entry "prod13" $map.test.override_parent
            $e | Should Not BeNullOrEmpty
               Set-TestInconclusive "this is a feature request"
         <#
            $e.what | Should Be "what-prod13"
            $e.parent_property | Should Be "overriden"
            #>
        }

         It "Should replace single variable with property" {
            $e = get-entry "vars_from_pros" $map.test
            $e.url_single_var | Should Be "http://svc"
         }
         It "Should replace multiple variables with properties" {
            $e = get-entry "vars_from_pros" $map.test
            $e.url_multi_var | Should Be "http://svc/test"
         }
         It "Should leave unresolved variables" {
            $e = get-entry "vars_from_pros" $map.test
            $e.url_missing_val | Should Be "http://svc/test/{path_required}"
         }
         It "Should remove optional variables" {
            $e = get-entry "vars_from_pros" $map.test
            $e.url_default_val | Should Be "http://svc/test/"
        }
    }
  
  
    
  
}