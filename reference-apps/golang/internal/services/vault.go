package services

import (
	"context"
	"fmt"

	vault "github.com/hashicorp/vault/api"
)

// VaultClient wraps the Vault API client
type VaultClient struct {
	client *vault.Client
}

// NewVaultClient creates a new Vault client
func NewVaultClient(addr, token string) (*VaultClient, error) {
	config := vault.DefaultConfig()
	config.Address = addr

	client, err := vault.NewClient(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create Vault client: %w", err)
	}

	client.SetToken(token)

	return &VaultClient{client: client}, nil
}

// GetSecret retrieves a secret from Vault KV v2
func (v *VaultClient) GetSecret(ctx context.Context, path string) (map[string]interface{}, error) {
	secret, err := v.client.KVv2("secret").Get(ctx, path)
	if err != nil {
		return nil, fmt.Errorf("failed to read secret at %s: %w", path, err)
	}

	if secret == nil || secret.Data == nil {
		return nil, fmt.Errorf("no data found at %s", path)
	}

	return secret.Data, nil
}

// GetSecretKey retrieves a specific key from a secret
func (v *VaultClient) GetSecretKey(ctx context.Context, path, key string) (interface{}, error) {
	data, err := v.GetSecret(ctx, path)
	if err != nil {
		return nil, err
	}

	value, ok := data[key]
	if !ok {
		return nil, fmt.Errorf("key %s not found in secret %s", key, path)
	}

	return value, nil
}

// HealthCheck checks if Vault is accessible and unsealed
func (v *VaultClient) HealthCheck(ctx context.Context) (map[string]interface{}, error) {
	health, err := v.client.Sys().Health()
	if err != nil {
		return nil, fmt.Errorf("failed to check Vault health: %w", err)
	}

	return map[string]interface{}{
		"initialized": health.Initialized,
		"sealed":      health.Sealed,
		"standby":     health.Standby,
		"version":     health.Version,
	}, nil
}
