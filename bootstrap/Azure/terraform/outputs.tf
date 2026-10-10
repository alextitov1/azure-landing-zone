output "applications" {
  value = {
    for name, app in module.entraid_application : name => {
      client_id                   = app.client_id
      service_principal_object_id = app.service_principal_object_id
    }
  }
  description = "Client IDs and service principal object IDs of the Entra ID applications"
}
