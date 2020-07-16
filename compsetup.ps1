PROCESS {

    #rename computer?
    $confirmRenamePC=Get-Confirmation("Rename Computer?")

    #create local admin account?
    $confirmCreateLocalAdmin=Get-Confirmation("Create Local Admin Account?")

    #install chocolatey framework?
    $confirmInstallChocolatey=Get-Confirmation("Install Chocolatey Framework?")
    
    #install chocolatey apps?
    if($confirmInstallChocolatey){$chocoApps=Read-Host("Install what chocolately packages?`n[eg 'googlechrome;adobereader']`n[Leave blank to continue without installing]")}

    #download Privacy Script?
    $confirmPrivacyDownload=Get-Confirmation("Download Privacy Script? [You will have the chance to reject installing this later.]")
    

    #execute Functions
    if($confirmRenamePC){Set-ComputerName} #renames pc
    if($confirmCreateLocalAdmin){New-LocalAdmin} #creates pcsadmin
    if($confirmInstallChocolatey){Install-Chocolatey} #installs chocolatey
    if($confirmPrivacyDownload){Get-PrivacyScript}
    if(($chocoApps -ne "")-and($chocoApps -ne $null)){choco install $chocoApps -n} #installs chocolatey apps
    Set-PowerSettings #sets power settings
    Set-TimeZone "Eastern Standard Time" -verbose #sets timezone

}

BEGIN { #backend functions and settings

    Clear-Host
    
    #region Error Handling

    #clear error log
    $Error.clear()
    #on error, continue script
    $ErrorActionPreference = "SilentlyContinue"

    #endregion Error Handling

    #region Helper Functions

    Function Pause { #waits for user to hit a key
        Write-Host 'Press any key to continue...'
        [void][System.Console]::ReadKey('NoEcho,IncludeKeyDown')
    }

    Function Get-Confirmation { #asks user to confirm yes or no
        param(
        [String] $prompt = 'Confirm?', #prompt that displays before [y/n]
        [String] $answer = (Read-Host($prompt + ' [y/n]')) #get 'y' or 'n' response from user
        )
        
        While (!(($answer -eq 'y') -or ($answer -eq 'n'))){ #variable validation, reject all but 'y' and 'no'
            $answer = (Read-Host($prompt + ' [y/n]'))
        }
    
        if ($answer-eq 'y') { #if 'y' return True
            return $true
        }
    
        else { #if 'n' return False
            return $false
        }
    }

    #endregion Helper Functions

    #region Local PC Settings

    Function Set-ComputerName { #renames computer and adds to domain if specified
        param(
            [String] $hostname = (Read-Host('New Hostname for computer?')),
            [String] $domain = $null
        )
    
            if ($domainname) { #if domain specified, rename and add to domain
                $Credential = (Get-Credential -Message ('Enter Domain Admin credentials for domain ' + $domain + '.'))
                Write-Host("Renaming Computer to " + $hostname + " and adding it go domain " + $domain + " .")
                Add-Computer -Domain $domain -NewName $hostname -Credential $Credential
            }
    
            else { #if domain not specified, rename computer
                Write-Host("Renaming Computer to: " + $hostname)
                Rename-Computer $hostname
            }
    }

    Function New-LocalAdmin { #creates Local Administrator account
        <#
        .SYNOPSIS
        Creates Local admin account on machine
    
        .DESCRIPTION
        Creates a new local user, and adds the user to the Administrators group
    
        .EXAMPLE
        Create_Local_Admin -UserName Sam -PassWord Hello123
    
        .NOTES
        PARAM:
        $UserName (String, name of new user)
        $PassWord (String, password for new user. NOT RECOMMENDED. Better to pass without parameter and add via secure input)
        $Descrition (String, Description of the user account)
        #>
    
        param(
            [String] $UserName = (Read-Host -Prompt "Enter Name for new Admin account"),
            [SecureString] $PassWord,
            [String] $Description
        )
    
        #parameter validation
        if (!(get-localuser -name $UserName -ErrorAction Ignore)) {
    
            if (!($PassWord)) {
                $pwd1_text = '1'
                $pwd2_text = '2'
                While ( $pwd1_text -ne $pwd2_text ) {
                    $PassWord = Read-Host -AsSecureString ("Enter password for " + $UserName)
                    $PassWord2 = Read-Host -AsSecureString ("Re-Enter password for " + $UserName)
                    $pwd1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PassWord))
                    $pwd2_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PassWord2))
                }
            }
    
            #execute command
            New-LocalUser -Name $UserName -Password $PassWord -Description $Description -PasswordNeverExpires
            Add-LocalGroupMember -Group Administrators -Member $UserName
        }
    }

    Function Set-PowerSettings { #sets default power settings
        #Sets default power settings for plugged in(ac) and on battery (dc) configurations, 0 is never, integers represent minutes
    
        #Set Sleep Timer
        powercfg /change standby-timeout-ac 0
        powercfg /change standby-timeout-dc 30
    
        #Set Hibernate Timer
        powercfg /change hibernate-timeout-ac 0
        powercfg /change hibernate-timeout-dc 0
    
        #Set Monitor Idle Timer
        powercfg /change monitor-timeout-ac 10
        powercfg /change monitor-timeout-dc 10
    
        #Sets Lid Close Action to Sleep when on battery, Do Nothing when plugged in
        powercfg /setacvalueindex scheme_current sub_buttons lidaction 0
        powercfg /setdcvalueindex scheme_current sub_buttons lidaction 1

        #confirms with user
        Write-Host("Power settings applied.") -ForegroundColor Yellow -BackgroundColor Black
    }

    #endregion Local PC Settings

    #region Application Automation

    Function Install-Chocolatey { #installs chocolatey framework
        #check if Chocolatey is installed and if not, install it
    
        if (-not (Test-Path "C:\ProgramData\chocolatey\choco.exe")) {
            
            #chocolatey.org install script
            Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction SilentlyContinue
    
        }
    }

    Function Install-Agent { #installs solarwinds agent
        #Installs SolarWinds Agent
        
            #Search for Agent executable
            $AppUserPath = Resolve-Path ".\*WindowsAgentSetup.exe"
        
            #If valid exe found, execute it
            If (Test-Path $AppUserPath)
                {Start-Process -FilePath $AppUserPath -ArgumentList "-ai"}
    }

    Function Get-PrivacyScript { #downloads hahndorf's Privacy Script
    
        (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/hahndorf/Set-Privacy/master/Set-Privacy.ps1') | out-file .\Set-Privacy.ps1 -force
        powershell_ise.exe .\Set-Privacy.ps1
        if(Get-Confirmation("Continue with running privacy script?")){
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
            if(Get-Confirmation("Install with Balanced privacy settings? [recommended]")){
                .\Set-Privacy.ps1 -Balanced
                .\Set-Privacy.ps1 -Balanced -admin
            }
            elseif(Get-Confirmation("Install with Strong privacy settings?")){
                .\Set-Privacy.ps1 -Strong
                .\Set-Privacy.ps1 -Strong -admin
            }
            elseif(Get-Confirmation("Restore privacy settings to default?")){
                .\Set-Privacy.ps1 -Default
                .\Set-Privacy.ps1 -Default -admin
            else{Write-Host("Privacy Settings not changed")}
            }      
        }
    }
    #endregion Application Automation
}

END {

    #output errors in easy to read format
    $Error | Out-GridView

    #restart pc or exit script
    $confirmRestartPC=Get-Confirmation("Script Finished. Restart PC?")
    if($confirmRestartPC){Restart-Computer}
    else{exit}

}