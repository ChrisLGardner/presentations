# Domain Controller
Configuration DomainController {

    param (
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]$Credential,

        [Int]$RetryCount = 100,
        [Int]$RetryIntervalSec = 30
    ) 

    Import-DscResource -ModuleName xNetworking -ModuleVersion 3.2.0.0
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 6.0.0.0
    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.16.0.0
    Import-DscResource -ModuleName xAdcsDeployment -ModuleVersion 1.1.0.0
    Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.9.0.0
	Import-DscResource -ModuleName xCertificate -ModuleVersion 2.8.0.0
    Import-DscResource -ModuleName xDnsServer -ModuleVersion 1.9.0.0

    Write-Verbose "Processing Configuration DomainController"

    Write-Verbose "Processing configuration: Node DomainController"
    node $AllNodes.where({$_.Role -eq 'DomainController'}).NodeName {
        Write-Verbose "Processing Node: $($Node.NodeName)"

		Write-Verbose "Generating Credential Objects"
		$DomainCredentials = New-Object System.Management.Automation.PSCredential ("$($DomainNetbiosName)\$($Credential.UserName)", $Credential.Password)
		$DomainCredentialsAtDomain = New-Object System.Management.Automation.PSCredential ("$($Credential.UserName)@$($DomainName)", $Credential.Password)

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            AllowModuleOverwrite = $true
            ConfigurationMode = 'ApplyOnly'
            CertificateID = $Node.Thumbprint
            DebugMode = 'All'
        }
    
        if ($Node.IPaddress) {
            xIPAddress PrimaryIPAddress {
                IPAddress = $Node.IPAddress
                InterfaceAlias = $Node.InterfaceAlias
                PrefixLength = $Node.PrefixLength
                AddressFamily = $Node.AddressFamily
            }
        }

        # Set a default gateway if the config specifies one
        if ($Node.DefaultGateway) {
            xDefaultGatewayAddress DefaultGateway {
                InterfaceAlias = $Node.InterfaceAlias
                Address = $Node.DefaultGateway
                AddressFamily = $Node.AddressFamily
            }
        }

        if ($Node.DnsAddress) {
            xDNSServerAddress DNSaddress {
                Address = $Node.DnsAddress
                InterfaceAlias = $Node.InterfaceAlias
                AddressFamily = $Node.AddressFamily
            }
        }

        # Install AD required features
        WindowsFeature ADDS {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }

        # Install AD RSAT Tools
        WindowsFeature ADDSrsat {
            Ensure = 'Present'
            Name = 'RSAT-AD-Tools'
            IncludeAllSubFeature = $true
        }

        # Install CertServ Web Enroll required features
        WindowsFeature WebEnroll {
            Ensure = 'Present'
            Name = 'ADCS-Web-Enrollment'
        }

        # Create new AD domain
        xADDomain FirstDC {
            DependsOn = '[WindowsFeature]ADDS'
            DomainName = $DomainName
            DomainNetbiosName = $DomainNetBiosName
            SafemodeAdministratorPassword = $Credential
            DomainAdministratorCredential = $Credential
            DatabasePath = $Node.DSdrive + "\NTDS"
            LogPath = $Node.DSdrive + "\NTDS"
            SysVolPath = $Node.DSdrive + "\SysVol"
        }

		# Set Domain Admin Password to never expire
        xADUser DomainAdmin {
            DependsOn = '[xADDomain]FirstDC'
            Ensure = 'Present'
			DomainName = $DomainName
            UserName = "Administrator"
			UserPrincipalName = "Administrator@$DomainName"
            Password = $Credential
            DomainAdministratorCredential = $DomainCredentialsAtDomain
            PasswordNeverExpires = $true
        }

        # Install CertServ required features
        WindowsFeature ADCS {
            DependsOn = '[xADDomain]FirstDC'
            Ensure = 'Present'
            Name = 'ADCS-Cert-Authority'
        }

        WindowsFeature ADCSMgmt {
            DependsOn = '[xADDomain]FirstDC'
            Ensure = 'Present'
            Name = 'RSAT-ADCS-Mgmt'
        }

        # Create Cert Authority
        xAdcsCertificationAuthority CertAuth {
            DependsOn = '[WindowsFeature]ADCS'
            Ensure = 'Present'
            CAType = 'EnterpriseRootCA'
			HashAlgorithmName = 'SHA256'
			KeyLength = 2048
            Credential = $DomainCredentialsAtDomain
        }

		# Create Certificates Folder
		File Certificates {
			DependsOn = '[xAdcsCertificationAuthority]CertAuth'
			Ensure = 'Present'
			Type = 'Directory'
			DestinationPath = 'C:\Certificates'
		}

		# Export Domain Root Cert
		$CertFN = "CN=" + $EnvPrefix + "-" + $Node.NodeName + "-CA, DC=" + $EnvPrefix + ", DC=local"
		xCertificateExport DomainRoot {
			DependsOn = '[File]Certificates'
			Path = 'C:\Certificates\domainroot.cer'
			Subject = $CertFN
			Type = 'CERT'
		}

        xDnsServerForwarder ForwardToGoogleDNS {
            IsSingleInstance = 'Yes'
            IPAddresses = '8.8.8.8','8.8.4.4'
            DependsOn = "[Script]EnableWebServerEnroll"
        }

    }

# End configuration DomainController
}
