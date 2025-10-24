"""
Vault integration examples

Demonstrates how to:
- Fetch secrets from Vault
- Use credentials for other services
- Handle Vault errors
"""

from fastapi import APIRouter, HTTPException
from app.services.vault import vault_client

router = APIRouter()


@router.get("/secret/{service_name}")
async def get_secret_example(service_name: str):
    """
    Example: Fetch a secret from Vault

    This shows how to retrieve credentials for any service stored in Vault.
    """
    try:
        secret = await vault_client.get_secret(service_name)

        # Don't return passwords in real applications!
        # This is just a demonstration
        safe_secret = {
            k: "***" if "password" in k.lower() else v
            for k, v in secret.items()
        }

        return {
            "service": service_name,
            "data": safe_secret,
            "note": "Passwords are masked. In real apps, use credentials internally, never return them."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch secret: {str(e)}")


@router.get("/secret/{service_name}/{key}")
async def get_secret_key_example(service_name: str, key: str):
    """
    Example: Fetch a specific key from a secret

    Useful when you only need one field (like just the password).
    """
    try:
        secret = await vault_client.get_secret(service_name, key=key)

        # Mask sensitive data
        value = secret.get(key)
        if value and ("password" in key.lower() or "token" in key.lower()):
            value = "***"

        return {
            "service": service_name,
            "key": key,
            "value": value,
            "note": "Sensitive values are masked"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch secret key: {str(e)}")
