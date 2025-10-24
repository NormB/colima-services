#!/usr/bin/env python3
"""Read secrets from HashiCorp Vault KV v2 engine.

This module provides a simple interface to retrieve secrets from HashiCorp Vault's
KV (Key-Value) version 2 secret engine. It uses only standard library modules to
minimize dependencies.

The script is designed to be called from shell scripts to inject Vault secrets
into environment variables without requiring the full Vault CLI.

Environment Variables:
    VAULT_ADDR: Vault server address (default: http://localhost:8200)
    VAULT_TOKEN: Vault authentication token (required)

Example:
    $ export VAULT_ADDR=http://localhost:8200
    $ export VAULT_TOKEN=hvs.xxx
    $ python3 read-vault-secret.py postgres password
    my_secure_password

Usage:
    read-vault-secret.py <path> <field>

Arguments:
    path: Secret path in Vault (e.g., 'postgres', 'mysql')
    field: Field name within the secret (e.g., 'password', 'username')
"""
import sys
import json
import os
import urllib.request


def read_secret(vault_addr, vault_token, path, field):
    """Read a specific field from a Vault KV v2 secret.

    Args:
        vault_addr: Vault server address (e.g., 'http://localhost:8200')
        vault_token: Vault authentication token
        path: Secret path in the KV v2 engine (e.g., 'postgres')
        field: Field name within the secret (e.g., 'password')

    Returns:
        str: The value of the requested field

    Raises:
        SystemExit: If the secret cannot be read or the field doesn't exist

    Note:
        The URL format for KV v2 is: /v1/secret/data/{path}
        This differs from KV v1 which uses: /v1/secret/{path}
    """
    url = f"{vault_addr}/v1/secret/data/{path}"

    req = urllib.request.Request(url)
    req.add_header('X-Vault-Token', vault_token)

    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            return data['data']['data'][field]
    except Exception as e:
        print(f"Error reading secret: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: read-vault-secret.py <path> <field>", file=sys.stderr)
        print("Example: read-vault-secret.py postgres password", file=sys.stderr)
        sys.exit(1)

    vault_addr = os.environ.get('VAULT_ADDR', 'http://localhost:8200')
    vault_token = os.environ.get('VAULT_TOKEN')

    if not vault_token:
        print("VAULT_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    field = sys.argv[2]

    value = read_secret(vault_addr, vault_token, path, field)
    print(value)
