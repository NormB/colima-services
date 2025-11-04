"""
Vault client service for fetching secrets

Demonstrates how to integrate with HashiCorp Vault to fetch credentials
for other infrastructure services.
"""

import httpx
import logging
import re
from typing import Optional, Dict, Any
from urllib.parse import urljoin

from app.config import settings
from app.exceptions import VaultUnavailableError, ResourceNotFoundError

logger = logging.getLogger(__name__)


class VaultClient:
    """Client for interacting with HashiCorp Vault"""

    def __init__(self):
        self.vault_addr = settings.VAULT_ADDR
        self.vault_token = settings.VAULT_TOKEN
        self.headers = {"X-Vault-Token": self.vault_token}

    def _validate_secret_path(self, path: str) -> str:
        """
        Validate and sanitize the secret path to prevent SSRF attacks.

        Args:
            path: The secret path to validate

        Returns:
            Sanitized path

        Raises:
            ValueError: If path contains invalid characters
        """
        # Remove leading/trailing slashes
        path = path.strip("/")

        # Only allow alphanumeric, hyphens, underscores, and forward slashes
        if not re.match(r'^[a-zA-Z0-9/_-]+$', path):
            raise ValueError(f"Invalid secret path: {path}. Only alphanumeric characters, hyphens, underscores, and forward slashes are allowed.")

        # Prevent path traversal
        if ".." in path:
            raise ValueError(f"Invalid secret path: {path}. Path traversal sequences are not allowed.")

        return path

    async def get_secret(self, path: str, key: Optional[str] = None) -> Dict[str, Any]:
        """
        Fetch a secret from Vault KV v2 secrets engine

        Args:
            path: Secret path (e.g., 'postgres', 'mysql')
            key: Optional specific key to extract

        Returns:
            Secret data or specific key value

        Raises:
            VaultUnavailableError: If Vault is unreachable or returns an error
            ResourceNotFoundError: If the secret doesn't exist
            ValueError: If path contains invalid characters
        """
        # Validate path to prevent SSRF
        validated_path = self._validate_secret_path(path)

        # Construct URL safely
        url = urljoin(f"{self.vault_addr}/", f"v1/secret/data/{validated_path}")

        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=self.headers, timeout=5.0)

                # Handle 404 specifically
                if response.status_code == 404:
                    raise ResourceNotFoundError(
                        resource_type="secret",
                        resource_id=path,
                        message=f"Secret '{path}' not found in Vault",
                        details={"secret_path": path, "key": key}
                    )

                # Handle 403 (permission denied)
                if response.status_code == 403:
                    raise VaultUnavailableError(
                        message="Permission denied accessing Vault secret",
                        secret_path=path,
                        details={"status_code": 403}
                    )

                response.raise_for_status()

                data = response.json()
                secret_data = data.get("data", {}).get("data", {})

                if key:
                    # Check if the specific key exists
                    if key not in secret_data:
                        raise ResourceNotFoundError(
                            resource_type="secret_key",
                            resource_id=f"{path}/{key}",
                            message=f"Key '{key}' not found in secret '{path}'",
                            details={"secret_path": path, "key": key}
                        )
                    return {key: secret_data.get(key)}

                return secret_data

        except (ResourceNotFoundError, VaultUnavailableError):
            # Re-raise our custom exceptions
            raise
        except httpx.TimeoutException as e:
            logger.error(f"Timeout fetching secret from Vault: {e}")
            raise VaultUnavailableError(
                message="Timeout connecting to Vault",
                secret_path=path,
                details={"error": str(e), "timeout": "5.0s"}
            )
        except httpx.ConnectError as e:
            logger.error(f"Connection error to Vault: {e}")
            raise VaultUnavailableError(
                message="Cannot connect to Vault server",
                secret_path=path,
                details={"error": str(e), "vault_address": self.vault_addr}
            )
        except httpx.HTTPError as e:
            logger.error(f"HTTP error fetching secret from Vault: {e}")
            raise VaultUnavailableError(
                message=f"Vault returned an error: {e}",
                secret_path=path,
                details={"error": str(e)}
            )
        except Exception as e:
            logger.error(f"Unexpected error fetching secret: {e}")
            raise VaultUnavailableError(
                message=f"Unexpected error accessing Vault: {e}",
                secret_path=path,
                details={"error": str(e)}
            )

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
                "error": "Health check failed"
            }


# Global Vault client instance
vault_client = VaultClient()
