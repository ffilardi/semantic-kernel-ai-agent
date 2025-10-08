param vaultName string
param secretName string

@secure()
param secretValue string

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: vaultName
}

resource vaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: secretName
  properties: {
    value: secretValue
  }
}

output reference string = '@Microsoft.KeyVault(VaultName=${vault.name};SecretName=${secretName})'
