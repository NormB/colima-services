"""
Vault client service for fetching secrets

Demonstrates how to integrate with HashiCorp Vault to fetch credentials
for other infrastructure services.
"""

import httpx
import logging
from typing import Optional, Dict, Any

from app.config import settings

logger = logging.getLogger(__name__)


class VaultClient:
    """Client for interacting with HashiCorp Vault"""

    def __init__(self):
        self.vault_addr = settings.VAULT_ADDR
        self.vault_token = settings.VAULT_TOKEN
        self.headers = {"X-Vault-Token": self.vault_token}

    async def get_secret(self, path: str, key: Optional[str] = None) -> Dict[str, Any]:
        """
        Fetch a secret from Vault KV v2 secrets engine

        Args:
            path: Secret path (e.g., 'postgres', 'mysql')
            key: Optional specific key to extract

        Returns:
            Secret data or specific key value
        """
        url = f"{self.vault_addr}/v1/secret/data/{path}"

        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=self.headers, timeout=5.0)
                response.raise_for_status()

                data = response.json()
                secret_data = data.get("data", {}).get("data", {})

                if key:
                    return {key: secret_data.get(key)}

                return secret_data

        except httpx.HTTPError as e:
            logger.error(f"Failed to fetch secret from Vault: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error fetching secret: {e}")
            raise

    async def check_health(self) -> Dict[str, Any]:
        """Check Vault health status"""
        url = f"{self.vault_addr}/v1/sys/health"

        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{url}?standbyok=true",
                    timeout=5.0
                )

                return {
                    "status": "healthy" if response.status_code == 200 else "unhealthy",
                    "initialized": response.status_code != 501,
                    "sealed": response.status_code == 503,
                    "standby": response.status_code == 429,
                }
        except Exception as e:
            logger.error(f"Vault health check failed: {e}")
            return {
                "status": "unhealthy",
                "error": str(e)
            }


# Global Vault client instance
vault_client = VaultClient()
