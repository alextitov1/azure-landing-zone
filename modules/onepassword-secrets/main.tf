# References parsed into vault, item and field
locals {
  secret_refs = {
    for ref in var.references :
    ref => {
      vault = regex("^op://([^/]+)/([^/]+)/(.+)$", ref)[0]
      item  = regex("^op://([^/]+)/([^/]+)/(.+)$", ref)[1]
      field = regex("^op://([^/]+)/([^/]+)/(.+)$", ref)[2] # built-in field (credential, password, ...) or <section>/<field>
    }
  }
}

data "onepassword_vault" "this" {
  for_each = toset([for r in values(local.secret_refs) : r.vault])
  name     = each.key
}

# Ephemeral: the secrets are read on each plan and apply and never stored in state or plan files
ephemeral "onepassword_item" "this" {
  for_each = toset([for r in values(local.secret_refs) : "${r.vault}/${r.item}"])
  vault    = data.onepassword_vault.this[split("/", each.key)[0]].uuid
  title    = split("/", each.key)[1]
}

locals {
  values = {
    for ref, r in local.secret_refs : ref => (
      length(split("/", r.field)) == 2
      # <section>/<field>: custom field in a named section
      ? one(flatten([
        for s in ephemeral.onepassword_item.this["${r.vault}/${r.item}"].section : [
          for f in s.field : f.value if s.label == split("/", r.field)[0] && f.label == split("/", r.field)[1]
        ]
      ]))
      # built-in field, e.g. credential or password
      : ephemeral.onepassword_item.this["${r.vault}/${r.item}"][r.field]
    )
  }
}
