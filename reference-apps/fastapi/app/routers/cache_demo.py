"""
Redis cache integration examples

Demonstrates:
- Basic key-value operations
- TTL (Time To Live) management
- Redis cluster usage
"""

from fastapi import APIRouter, HTTPException
import redis.asyncio as redis

from app.config import settings
from app.services.vault import vault_client

router = APIRouter()


async def get_redis_client():
    """Get configured Redis client"""
    creds = await vault_client.get_secret("redis-1")
    return redis.Redis(
        host=settings.REDIS_HOST,
        port=settings.REDIS_PORT,
        password=creds.get("password"),
        decode_responses=True,
        socket_connect_timeout=5
    )


@router.get("/{key}")
async def get_cache_value(key: str):
    """Example: Get a value from cache"""
    try:
        client = await get_redis_client()
        value = await client.get(key)
        ttl = await client.ttl(key)
        await client.close()

        if value is None:
            return {"key": key, "value": None, "exists": False}

        return {
            "key": key,
            "value": value,
            "exists": True,
            "ttl": ttl if ttl > 0 else "no expiration"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cache get failed: {str(e)}")


@router.post("/{key}")
async def set_cache_value(key: str, value: str, ttl: int = None):
    """Example: Set a value in cache with optional TTL"""
    try:
        client = await get_redis_client()

        if ttl:
            await client.setex(key, ttl, value)
        else:
            await client.set(key, value)

        await client.close()

        return {
            "key": key,
            "value": value,
            "ttl": ttl,
            "action": "set"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cache set failed: {str(e)}")


@router.delete("/{key}")
async def delete_cache_value(key: str):
    """Example: Delete a value from cache"""
    try:
        client = await get_redis_client()
        deleted = await client.delete(key)
        await client.close()

        return {
            "key": key,
            "deleted": bool(deleted),
            "action": "delete"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cache delete failed: {str(e)}")
