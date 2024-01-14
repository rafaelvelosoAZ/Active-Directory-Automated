variable "Domain_DNSName" {
  description = "FQDN for the Active Directory forest root domain"
  type        = string
  sensitive   = false
  default     = "contoso.local"
}

variable "netbios_name" {
  description = "NETBIOS name for the AD domain"
  type        = string
  sensitive   = false
  default     = "CONTOSO"
}

variable "SafeModeAdministratorPassword" {
  description = "Password for AD Safe Mode recovery"
  type        = string
  sensitive   = true
  default     = "P@$$w0rd1234!"
}

variable "admin_username" {
  description = "admin user name for AD Safe Mode recovery"
  type        = string
  sensitive   = true
  default     = "adminuser"
}

variable "admin_passwd" {
  description = "admin passwd AD"
  type        = string
  sensitive   = true
  default     = "P@$$w0rd1234!"
}

variable "ExistingDC" {
  description = "admin passwd AD"
  type        = string
  sensitive   = true
  default     = "vm-dc-0.contoso.local"
}

variable "SiteName" {
  description = "admin passwd AD"
  type        = string
  sensitive   = true
  default     = "Default-First-Site-Name"
}

variable "admin_username_domain" {
  description = "admin user name for AD Safe Mode recovery"
  type        = string
  sensitive   = true
  default     = "adminuser@contoso.local"
}
