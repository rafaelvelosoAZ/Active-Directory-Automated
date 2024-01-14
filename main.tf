####################################################################################
######################Resource Groups###############################################
resource "azurerm_resource_group" "rg_hub" {
  name     = "rg-hub"
  location = "eastus"
  #tags     = var.tags

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

resource "azurerm_resource_group" "rg_spoke" {
  name     = "rg-spoke"
  location = "eastus"
  #tags     = var.tags

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

####################################################################################
######################Virtual Networks##############################################
resource "azurerm_virtual_network" "vnet_hub" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  address_space       = ["10.0.0.0/16"]

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }

  tags = {
    environment = "aks"
  }
}

resource "azurerm_subnet" "subnet_ad" {
  name                 = "sub-ad"
  resource_group_name  = azurerm_resource_group.rg_hub.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_virtual_network" "vnet_spoke" {
  name                = "vnet-spoke"
  location            = azurerm_resource_group.rg_spoke.location
  resource_group_name = azurerm_resource_group.rg_spoke.name
  address_space       = ["10.1.0.0/16"]
  dns_servers         = [azurerm_network_interface.dc_win[0].private_ip_address]

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
  tags = {
    environment = "aks"
  }
}

resource "azurerm_subnet" "snet_spoke" {
  name                 = "subnet-spoke"
  resource_group_name  = azurerm_resource_group.rg_spoke.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke.name
  address_prefixes     = ["10.1.0.0/24"]
}

####################################################################################
######################Virtual Machines###############################################
resource "azurerm_public_ip" "dc_win" {
  count               = 1
  name                = "vm2-dc-win-${count.index}"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "dc_win" {
  count = 1

  name                = "vm-spoke2-win-${count.index}-nic"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_ad.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(concat(azurerm_public_ip.dc_win.*.id, [""]), count.index)
  }
}

resource "azurerm_windows_virtual_machine" "dc_win" {
  count = 1

  name                = "vm-dc-${count.index}"
  resource_group_name = azurerm_resource_group.rg_hub.name
  location            = azurerm_resource_group.rg_hub.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.dc_win[count.index].id,
  ]

  admin_password = var.admin_passwd

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  #tags = var.tags-worker
}

resource "azurerm_public_ip" "dc_promo" {
  count               = 1
  name                = "vm2-dc-promo-${count.index}"
  location            = azurerm_resource_group.rg_spoke.location
  resource_group_name = azurerm_resource_group.rg_spoke.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "dc_promo" {
  count = 1

  name                = "vm-spoke2-promo-${count.index}-nic"
  location            = azurerm_resource_group.rg_spoke.location
  resource_group_name = azurerm_resource_group.rg_spoke.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_spoke.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(concat(azurerm_public_ip.dc_promo.*.id, [""]), count.index)
  }
}

resource "azurerm_windows_virtual_machine" "dc_promo" {
  count = 1

  name                = "vm-dc-promo-${count.index}"
  resource_group_name = azurerm_resource_group.rg_spoke.name
  location            = azurerm_resource_group.rg_spoke.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.dc_promo[count.index].id,
  ]

  admin_password = var.admin_passwd

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  depends_on = [azurerm_windows_virtual_machine.dc_win, azurerm_virtual_machine_extension.install_ad, data.template_file.ADDS]
}

resource "azurerm_public_ip" "pub_win2" {
  count               = 1
  name                = "vm2-win-${count.index}"
  location            = azurerm_resource_group.rg_spoke.location
  resource_group_name = azurerm_resource_group.rg_spoke.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "ni_win2" {
  count = 1

  name                = "vm-spoke2-win-${count.index}-nic"
  location            = azurerm_resource_group.rg_spoke.location
  resource_group_name = azurerm_resource_group.rg_spoke.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_spoke.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(concat(azurerm_public_ip.pub_win2.*.id, [""]), count.index)
  }
}

resource "azurerm_windows_virtual_machine" "vm_win2" {
  count = 1

  name                = "vm-join-${count.index}"
  resource_group_name = azurerm_resource_group.rg_spoke.name
  location            = azurerm_resource_group.rg_spoke.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.ni_win2[count.index].id,
  ]

  admin_password = "P@$$w0rd1234!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  depends_on = [azurerm_windows_virtual_machine.dc_win, azurerm_virtual_machine_extension.install_ad, data.template_file.ADDS]
  #tags = var.tags-worker
}

####################################################################################
######################Security Groups###############################################
resource "azurerm_network_security_group" "sg" {
  name                = "kubernetes-security-group"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name
}

resource "azurerm_network_security_rule" "sg" {
  name                        = "test123"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_hub.name
  network_security_group_name = azurerm_network_security_group.sg.name
}

resource "azurerm_subnet_network_security_group_association" "sg_as" {
  subnet_id                 = azurerm_subnet.subnet_ad.id
  network_security_group_id = azurerm_network_security_group.sg.id
}

resource "azurerm_network_security_group" "sg2" {
  name                = "spoke-sg"
  location            = azurerm_resource_group.rg_spoke.location
  resource_group_name = azurerm_resource_group.rg_spoke.name
}

resource "azurerm_network_security_rule" "sg2" {
  name                        = "test123"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_spoke.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_subnet_network_security_group_association" "sg_as2" {
  subnet_id                 = azurerm_subnet.snet_spoke.id
  network_security_group_id = azurerm_network_security_group.sg2.id
}

####################################################################################
######################Vnet Peering##################################################
resource "azurerm_virtual_network_peering" "peering" {
  name                         = "peer1to2"
  resource_group_name          = azurerm_resource_group.rg_spoke.name
  virtual_network_name         = azurerm_virtual_network.vnet_spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}
resource "azurerm_virtual_network_peering" "peering2" {
  name                         = "peer2to1"
  resource_group_name          = azurerm_resource_group.rg_hub.name
  virtual_network_name         = azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}


####################################################################################
######################Instalação Active Directory Role##############################
resource "azurerm_virtual_machine_extension" "install_ad" {
  name                 = "install_ad"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc_win[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<SETTINGS
  {    
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.ADDS.rendered)}')) | Out-File -filepath ADDS.ps1\" && powershell -ExecutionPolicy Unrestricted -File ADDS.ps1 -Domain_DNSName ${data.template_file.ADDS.vars.Domain_DNSName} -Domain_NETBIOSName ${data.template_file.ADDS.vars.Domain_NETBIOSName} -SafeModeAdministratorPassword ${data.template_file.ADDS.vars.SafeModeAdministratorPassword}"
  }
  SETTINGS
}

data "template_file" "ADDS" {
  template = file("ADDS.ps1")
  vars = {
    Domain_DNSName                = "${var.Domain_DNSName}"
    Domain_NETBIOSName            = "${var.netbios_name}"
    SafeModeAdministratorPassword = "${var.SafeModeAdministratorPassword}"
  }
}
#https://techcommunity.microsoft.com/t5/itops-talk-blog/how-to-run-powershell-scripts-on-azure-vms-with-terraform/ba-p/3827573
####################################################################################
######################Promote AD####################################################

resource "azurerm_virtual_machine_extension" "promote_ad" {
  name                 = "promote_ad"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc_promo[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<SETTINGS
  {    
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.promote_ad.rendered)}')) | Out-File -filepath promote-ad.ps1\" && powershell -ExecutionPolicy Unrestricted -File promote-ad.ps1 -Domain_DNSName ${data.template_file.promote_ad.vars.Domain_DNSName} -admin_username_domain ${data.template_file.promote_ad.vars.admin_username_domain} -admin_passwd ${data.template_file.promote_ad.vars.admin_passwd} -SafeModeAdministratorPassword ${data.template_file.promote_ad.vars.SafeModeAdministratorPassword}"
  }
  SETTINGS

  depends_on = [ time_sleep.wait_5_min ]
}

data "template_file" "promote_ad" {
  template = file("promote-ad.ps1")
  vars = {
    Domain_DNSName                = "${var.Domain_DNSName}"
    SafeModeAdministratorPassword = "${var.SafeModeAdministratorPassword}"
    admin_username_domain         = "${var.admin_username_domain}"
    admin_passwd                  = "${var.admin_passwd}"
  }
}

####################################################################################
######################Join VM in Active Directory###################################

resource "azurerm_virtual_machine_extension" "join_ad" {
  name                 = "join-domain"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm_win2[0].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = <<SETTINGS
    {
        "Name": "${var.Domain_DNSName}",
        "User": "${var.admin_username}@${var.Domain_DNSName}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
        "Password": "${var.admin_passwd}"
    }
PROTECTED_SETTINGS

depends_on = [ time_sleep.wait_5_min ]
}

####################################################################################
######################Time Sleep####################################################

resource "time_sleep" "wait_5_min" {
  depends_on = [azurerm_virtual_machine_extension.install_ad, data.template_file.ADDS]

  create_duration = "5m"
}

