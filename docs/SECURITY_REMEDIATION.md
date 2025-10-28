# Security Remediation Plan

**Total Alerts**: 63 CodeQL security alerts
**Date**: 2025-10-28
**Status**: In Progress

## Summary by Severity

- ✅ **CRITICAL (2)**: FIXED - SSRF vulnerabilities
- 🔄 **HIGH (7)**: In Progress
  - 4x Clear-text logging of sensitive data
  - 3x Log injection vulnerabilities
- ⏳ **MEDIUM (22)**: Pending - Stack trace exposure
- ⏳ **LOW/INFO (32)**: Pending - Code quality issues

---

## ✅ Completed Fixes

### CRITICAL: Server-Side Request Forgery (SSRF) - 2 alerts

**Files**:
- `reference-apps/fastapi/app/services/vault.py:45`
- `reference-apps/fastapi-api-first/app/services/vault.py:45`

**Issue**: User-provided path parameter directly interpolated into HTTP request URL

**Fix Applied**:
- Added `_validate_secret_path()` method with regex validation
- Only allow alphanumeric, hyphens, underscores, forward slashes
- Prevent path traversal attacks (`../`)
- Use `urljoin()` for safe URL construction

**Commit**: 0e36d58

---

## 🔄 HIGH Severity - In Progress (7 alerts)

### 1. Clear-Text Logging of Sensitive Data (4 alerts)

#### Alert #8: scripts/read-vault-secret.py:83
**Issue**: Logging secret data in clear text
```python
logger.debug(f"Retrieved secret: {secret}")
```

**Fix Needed**: Redact or mask sensitive values
```python
logger.debug(f"Retrieved secret: [REDACTED]")
# Or log only the secret keys, not values:
logger.debug(f"Retrieved secret keys: {list(secret.keys())}")
```

#### Alert #7: reference-apps/fastapi/app/main.py:376
**Issue**: Logging password/secret in clear text
```python
logger.debug(f"Connection details: {details}")  # Contains passwords
```

**Fix Needed**: Redact sensitive fields before logging
```python
def redact_sensitive(data: dict) -> dict:
    """Redact sensitive fields from logging"""
    sensitive_keys = {'password', 'secret', 'token', 'key', 'auth'}
    return {k: '[REDACTED]' if any(s in k.lower() for s in sensitive_keys) else v
            for k, v in data.items()}

logger.debug(f"Connection details: {redact_sensitive(details)}")
```

#### Alerts #6, #5: reference-apps/fastapi*/app/middleware/cache.py:186
**Issue**: Same as above - logging passwords in cache middleware

**Fix Needed**: Apply same redaction pattern

---

### 2. Log Injection (3 alerts)

#### Alert #67: reference-apps/golang/internal/middleware/logging.go:29
**Issue**: Logging user-controlled path without sanitization
```go
logger.WithFields(logrus.Fields{
    "path": c.Request.URL.Path,  // User-controlled, could contain newlines
})
```

**Fix Needed**: Sanitize newlines and special characters
```go
import "strings"

func sanitizeForLogging(s string) string {
    s = strings.ReplaceAll(s, "\n", "\\n")
    s = strings.ReplaceAll(s, "\r", "\\r")
    return s
}

logger.WithFields(logrus.Fields{
    "path": sanitizeForLogging(c.Request.URL.Path),
})
```

#### Alerts #34, #33: reference-apps/fastapi*/app/routers/redis_cluster.py:301
**Issue**: Logging user-provided cluster node name without sanitization

**Fix Needed**: Sanitize input before logging
```python
def sanitize_log_value(value: str) -> str:
    """Remove newlines and control characters from log values"""
    return value.replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')

logger.info(f"Cluster node: {sanitize_log_value(node_name)}")
```

---

## ⏳ MEDIUM Severity - Pending (22 alerts)

### Stack Trace Exposure (22 alerts)

**Issue**: Exception handlers return stack traces to clients, exposing internal implementation details

**Files Affected**: Multiple exception handlers across both FastAPI implementations

**Fix Strategy**:
1. In production, only return generic error messages to clients
2. Log full stack traces server-side for debugging
3. Use different behavior based on environment (dev vs prod)

**Example Fix**:
```python
from app.config import settings

@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    # Log full details server-side
    logger.error(f"Unhandled exception: {exc}", exc_info=True)

    # Return generic message to client (unless in dev mode)
    if settings.DEBUG:
        return JSONResponse(
            status_code=500,
            content={"detail": str(exc), "type": type(exc).__name__}
        )
    else:
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"}
        )
```

---

## ⏳ Code Quality - Pending (32 alerts)

### Unused Imports (23 alerts)
**Files**: Multiple test files and application modules

**Fix**: Run automated cleanup:
```bash
# Using autoflake
autoflake --in-place --remove-all-unused-imports --recursive reference-apps/

# Or using ruff
ruff check --select F401 --fix reference-apps/
```

### Unused Local Variables (4 alerts)
**Fix**: Remove or prefix with underscore if intentionally unused

### Unnecessary Pass Statements (2 alerts)
**Fix**: Remove redundant `pass` statements

### Overwritten Inherited Attribute (2 alerts)
**Fix**: Rename conflicting attributes or use different approach

### Multiple Definitions (1 alert)
**File**: reference-apps/fastapi/tests/test_cors.py:21

**Fix**: Rename duplicate function/variable

---

## Implementation Priority

1. ✅ **CRITICAL SSRF** - COMPLETED
2. 🔄 **HIGH Clear-text logging** - IN PROGRESS
   - Create utility function for redacting sensitive data
   - Apply across all logging statements
3. 🔄 **HIGH Log injection** - NEXT
   - Create utility functions for log sanitization (Python & Go)
   - Apply to all user-controlled log inputs
4. ⏳ **MEDIUM Stack traces** - After HIGH
   - Implement environment-aware exception handling
   - Ensure DEBUG flag is properly configured
5. ⏳ **Code quality** - Final cleanup
   - Run automated tools (autoflake, ruff)
   - Manual review of remaining issues

---

## Automated Fix Scripts

### Python: Remove Unused Imports
```bash
#!/bin/bash
cd reference-apps
pip install autoflake ruff
autoflake --in-place --remove-all-unused-imports --recursive fastapi*/
ruff check --select F401,F841 --fix .
```

### Python: Add Redaction Utility
Create `reference-apps/fastapi/app/utils/logging.py`:
```python
from typing import Any, Dict, Set

SENSITIVE_KEYS: Set[str] = {
    'password', 'secret', 'token', 'key', 'auth',
    'credential', 'api_key', 'private'
}

def redact_sensitive(data: Dict[str, Any]) -> Dict[str, Any]:
    """Redact sensitive fields from dict for safe logging"""
    if not isinstance(data, dict):
        return data

    return {
        k: '[REDACTED]' if any(s in k.lower() for s in SENSITIVE_KEYS) else v
        for k, v in data.items()
    }

def sanitize_log_string(value: str) -> str:
    """Remove control characters that could break log parsing"""
    return value.replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')
```

---

## Testing Strategy

1. **Unit Tests**: Add tests for utility functions
2. **Integration Tests**: Verify logging doesn't expose sensitive data
3. **Security Tests**: Attempt log injection and verify sanitization
4. **Manual Review**: Check logs in dev environment

---

## References

- [CWE-918: SSRF](https://cwe.mitre.org/data/definitions/918.html)
- [CWE-532: Information Exposure Through Log Files](https://cwe.mitre.org/data/definitions/532.html)
- [CWE-117: Log Injection](https://cwe.mitre.org/data/definitions/117.html)
- [CWE-209: Information Exposure Through Error Message](https://cwe.mitre.org/data/definitions/209.html)
