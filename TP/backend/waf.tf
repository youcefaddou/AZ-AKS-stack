resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "waf-policy"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "waf" {
  name                = "appgw-waf"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  firewall_policy_id  = azurerm_web_application_firewall_policy.waf_policy.id

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name         = "frontend-pool"
    ip_addresses = azurerm_network_interface.frontend[*].private_ip_address
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "PathBasedRouting"
    http_listener_name         = "http-listener"
    url_path_map_name          = "path-map"
    priority                    = 1
  }
    backend_address_pool {
    name         = "backend-pool"
    ip_addresses = [azurerm_lb.internal.private_ip_address]
  }
    backend_http_settings {
    name                  = "api-settings"
    cookie_based_affinity = "Disabled"
    port                  = 3000
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "api-probe"
  }

  probe {
    name                = "api-probe"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 10
    unhealthy_threshold = 3
  }
    url_path_map {
    name                               = "path-map"
    default_backend_address_pool_name  = "frontend-pool"
    default_backend_http_settings_name = "http-settings"

    path_rule {
      name                       = "api-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = "backend-pool"
      backend_http_settings_name = "api-settings"
    }
  }
}
