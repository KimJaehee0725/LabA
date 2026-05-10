import csv
import datetime as dt
import html
import json
import math
import os
from collections import Counter
from decimal import Decimal
from datetime import timedelta
from io import IOBase, StringIO
from pathlib import Path
from typing import Any

import yaml
from authlib.integrations.starlette_client import OAuth
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from minio import Minio
from minio.error import S3Error
from starlette.middleware.sessions import SessionMiddleware


APP_DIR = Path(__file__).resolve().parent


def env_bool(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    value = os.environ.get(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.replace(" ", ",").split(",") if item.strip()]


VERSION = os.environ.get("HF_UI_VERSION", "phase5-mvp")
PUBLIC_URL = os.environ.get("HF_UI_PUBLIC_URL", "https://hf.lab.example.ac.kr").rstrip("/")
AUTH_REQUIRED = env_bool("HF_UI_AUTH_REQUIRED", True)
ALLOW_STAGING_BYPASS = env_bool("HF_UI_ALLOW_STAGING_BYPASS", False)
STAGING_BYPASS_TOKEN = os.environ.get("HF_UI_STAGING_BYPASS_TOKEN", "")
REQUIRED_GROUPS = set(split_csv(os.environ.get("HF_UI_REQUIRE_GROUPS", "lab-admin,lab-member,lab-collab")))
CATALOG_FILE = Path(os.environ.get("HF_UI_CATALOG_FILE", "/app/catalog/seed.catalog.yaml"))
PRESIGN_EXPIRY_SECONDS = int(os.environ.get("HF_UI_PRESIGN_EXPIRY_SECONDS", "900"))
PREVIEW_MAX_ROWS = env_int("HF_UI_PREVIEW_MAX_ROWS", 1000)
PREVIEW_MAX_BYTES = env_int("HF_UI_PREVIEW_MAX_BYTES", 5_242_880)
PREVIEW_PARQUET_MAX_BYTES = env_int("HF_UI_PREVIEW_PARQUET_MAX_BYTES", 20_971_520)
PREVIEW_RETURN_ROWS = env_int("HF_UI_PREVIEW_RETURN_ROWS", 50)
PREVIEW_CELL_MAX_CHARS = env_int("HF_UI_PREVIEW_CELL_MAX_CHARS", 240)
PREVIEW_SUPPORTED_FORMATS = {".jsonl": "jsonl", ".json": "json", ".csv": "csv", ".parquet": "parquet"}


app = FastAPI(title="Lab HF-like UI", version=VERSION)
app.add_middleware(
    SessionMiddleware,
    secret_key=os.environ.get("HF_UI_SESSION_SECRET", "change-me-generate-on-server"),
    same_site="lax",
    https_only=PUBLIC_URL.startswith("https://"),
)
app.mount("/static", StaticFiles(directory=APP_DIR / "static"), name="static")

oauth = OAuth()
oauth.register(
    name="authentik",
    server_metadata_url=os.environ.get("HF_UI_OIDC_ISSUER", "").rstrip("/") + "/.well-known/openid-configuration",
    client_id=os.environ.get("HF_UI_OIDC_CLIENT_ID", ""),
    client_secret=os.environ.get("HF_UI_OIDC_CLIENT_SECRET", ""),
    client_kwargs={"scope": os.environ.get("HF_UI_OIDC_SCOPES", "openid email profile groups")},
)


def minio_client(public: bool = False) -> Minio:
    if public:
        endpoint = os.environ.get("HF_UI_S3_PUBLIC_ENDPOINT", os.environ.get("HF_UI_S3_ENDPOINT", "minio:9000"))
        secure = env_bool("HF_UI_S3_PUBLIC_SECURE", True)
    else:
        endpoint = os.environ.get("HF_UI_S3_ENDPOINT", "minio:9000")
        secure = env_bool("HF_UI_S3_SECURE", False)
    return Minio(
        endpoint,
        access_key=os.environ.get("HF_UI_S3_ACCESS_KEY", ""),
        secret_key=os.environ.get("HF_UI_S3_SECRET_KEY", ""),
        secure=secure,
        region=os.environ.get("HF_UI_S3_REGION", "us-east-1"),
    )


def load_catalog() -> dict[str, list[dict[str, Any]]]:
    if not CATALOG_FILE.exists():
        return {"models": [], "datasets": []}
    with CATALOG_FILE.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    return {
        "models": [normalize_item("model", item) for item in data.get("models", [])],
        "datasets": [normalize_item("dataset", item) for item in data.get("datasets", [])],
    }


def normalize_item(kind: str, item: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(item)
    normalized["kind"] = kind
    normalized["tags"] = list(item.get("tags") or [])
    normalized["visibility"] = item.get("visibility") or os.environ.get("HF_UI_DEFAULT_VISIBILITY", "lab")
    normalized["prefix"] = item.get("prefix", "").lstrip("/")
    if normalized["prefix"] and not normalized["prefix"].endswith("/"):
        normalized["prefix"] += "/"
    return normalized


def visible_items(kind: str, query: str = "", tag: str = "") -> list[dict[str, Any]]:
    items = load_catalog()[kind]
    query = query.lower().strip()
    tag = tag.lower().strip()
    if query:
        items = [
            item
            for item in items
            if query in " ".join(
                [
                    item.get("owner", ""),
                    item.get("name", ""),
                    item.get("title", ""),
                    item.get("summary", ""),
                    " ".join(item.get("tags", [])),
                ]
            ).lower()
        ]
    if tag:
        items = [item for item in items if tag in {value.lower() for value in item.get("tags", [])}]
    return sorted(items, key=lambda item: (item.get("owner", ""), item.get("name", "")))


def find_item(kind: str, owner: str, name: str) -> dict[str, Any]:
    for item in load_catalog()[kind]:
        if item.get("owner") == owner and item.get("name") == name:
            return item
    raise HTTPException(status_code=404, detail=f"{kind[:-1]} not found")


def session_user(request: Request) -> dict[str, Any] | None:
    user = request.session.get("user")
    if isinstance(user, dict):
        return user
    return None


def staging_user(request: Request) -> dict[str, Any] | None:
    token = request.headers.get("x-hf-ui-staging-token", "")
    if ALLOW_STAGING_BYPASS and STAGING_BYPASS_TOKEN and token == STAGING_BYPASS_TOKEN:
        return {"name": "staging-smoke", "email": "", "groups": ["lab-member"], "auth": "staging-bypass"}
    return None


def current_user(request: Request) -> dict[str, Any] | None:
    return session_user(request) or staging_user(request)


def require_user(request: Request) -> dict[str, Any]:
    if not AUTH_REQUIRED:
        return {"name": "anonymous", "email": "", "groups": ["lab-member"], "auth": "disabled"}
    user = current_user(request)
    if not user:
        raise HTTPException(status_code=401, detail="login required")
    groups = set(user.get("groups") or [])
    if REQUIRED_GROUPS and not groups.intersection(REQUIRED_GROUPS):
        raise HTTPException(status_code=403, detail="lab group required")
    return user


def public_item(item: dict[str, Any]) -> dict[str, Any]:
    keys = [
        "kind",
        "id",
        "owner",
        "name",
        "title",
        "summary",
        "visibility",
        "tags",
        "license",
        "version",
        "base_model",
        "task",
        "bucket",
        "prefix",
    ]
    return {key: item.get(key) for key in keys if item.get(key) is not None}


def safe_object_path(item: dict[str, Any], path: str) -> str:
    cleaned = path.lstrip("/")
    if ".." in Path(cleaned).parts:
        raise HTTPException(status_code=400, detail="invalid object path")
    return item["prefix"] + cleaned


def safe_upload_object_path(item: dict[str, Any], path: str) -> str:
    if not path or path.startswith("/") or path.endswith("/"):
        raise HTTPException(status_code=400, detail="invalid upload path")
    if ".." in Path(path).parts:
        raise HTTPException(status_code=400, detail="invalid upload path")
    return item["prefix"] + path


def object_exists(bucket: str, object_name: str) -> bool:
    try:
        minio_client().stat_object(bucket, object_name)
    except S3Error as exc:
        if exc.code == "NoSuchKey":
            return False
        if exc.code == "NoSuchBucket":
            raise HTTPException(status_code=502, detail="storage bucket not found") from exc
        raise HTTPException(status_code=502, detail=exc.message) from exc
    return True


def object_to_dict(obj: Any, prefix: str) -> dict[str, Any]:
    name = obj.object_name[len(prefix) :] if obj.object_name.startswith(prefix) else obj.object_name
    return {
        "path": name,
        "size": obj.size,
        "last_modified": obj.last_modified.isoformat() if obj.last_modified else None,
        "etag": obj.etag,
    }


def read_object_text(bucket: str, object_name: str, limit: int = 256_000) -> str:
    response = None
    try:
        response = minio_client().get_object(bucket, object_name)
        data = response.read(limit + 1)
    except S3Error as exc:
        if exc.code in {"NoSuchKey", "NoSuchBucket"}:
            return ""
        raise
    finally:
        if response is not None:
            response.close()
            response.release_conn()
    if len(data) > limit:
        data = data[:limit]
    return data.decode("utf-8", errors="replace")


def read_object_bytes(bucket: str, object_name: str, limit: int) -> tuple[bytes, bool]:
    response = None
    try:
        response = minio_client().get_object(bucket, object_name)
        data = response.read(limit + 1)
    except S3Error as exc:
        if exc.code in {"NoSuchKey", "NoSuchBucket"}:
            raise HTTPException(status_code=404, detail="file not found") from exc
        raise HTTPException(status_code=502, detail=exc.message) from exc
    finally:
        if response is not None:
            response.close()
            response.release_conn()
    truncated = len(data) > limit
    if truncated:
        data = data[:limit]
    return data, truncated


def object_size(bucket: str, object_name: str) -> int:
    try:
        stat = minio_client().stat_object(bucket, object_name)
    except S3Error as exc:
        if exc.code in {"NoSuchKey", "NoSuchBucket"}:
            raise HTTPException(status_code=404, detail="file not found") from exc
        raise HTTPException(status_code=502, detail=exc.message) from exc
    return int(stat.size or 0)


def read_object_range(bucket: str, object_name: str, offset: int, length: int) -> bytes:
    response = None
    try:
        response = minio_client().get_object(bucket, object_name, offset=offset, length=length)
        return response.read(length)
    except S3Error as exc:
        if exc.code in {"NoSuchKey", "NoSuchBucket"}:
            raise HTTPException(status_code=404, detail="file not found") from exc
        raise HTTPException(status_code=502, detail=exc.message) from exc
    finally:
        if response is not None:
            response.close()
            response.release_conn()


class PreviewRangeLimitExceeded(Exception):
    pass


class MinioRangeReader(IOBase):
    def __init__(self, bucket: str, object_name: str, size: int, max_bytes: int):
        self.bucket = bucket
        self.object_name = object_name
        self.size = size
        self.max_bytes = max_bytes
        self.position = 0
        self.bytes_read = 0
        self._closed = False

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.position

    def seek(self, offset: int, whence: int = os.SEEK_SET) -> int:
        if whence == os.SEEK_SET:
            next_position = offset
        elif whence == os.SEEK_CUR:
            next_position = self.position + offset
        elif whence == os.SEEK_END:
            next_position = self.size + offset
        else:
            raise ValueError("invalid seek mode")
        self.position = max(0, min(self.size, next_position))
        return self.position

    def read(self, size: int = -1) -> bytes:
        if self._closed:
            raise ValueError("I/O operation on closed file")
        if self.position >= self.size:
            return b""
        if size is None or size < 0:
            length = self.size - self.position
        else:
            length = min(size, self.size - self.position)
        if length <= 0:
            return b""
        if self.bytes_read + length > self.max_bytes:
            raise PreviewRangeLimitExceeded()
        data = read_object_range(self.bucket, self.object_name, self.position, length)
        self.position += len(data)
        self.bytes_read += len(data)
        return data

    def close(self) -> None:
        self._closed = True
        super().close()


def preview_format(path: str) -> str | None:
    return PREVIEW_SUPPORTED_FORMATS.get(Path(path.lower()).suffix)


def add_warning(warnings: list[str], message: str) -> None:
    if len(warnings) < 20:
        warnings.append(message)


def display_scalar(value: Any, limit: int = PREVIEW_CELL_MAX_CHARS) -> str:
    if value is None:
        text = ""
    elif isinstance(value, bool):
        text = "true" if value else "false"
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        text = str(value)
    elif isinstance(value, str):
        text = value
    else:
        try:
            text = json.dumps(value, ensure_ascii=False, sort_keys=True)
        except TypeError:
            text = str(value)
    if len(text) > limit:
        return text[: max(0, limit - 3)] + "..."
    return text


def coerce_csv_value(value: Any) -> Any:
    if value is None:
        return None
    text = str(value).strip()
    if text == "":
        return None
    lowered = text.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    try:
        if any(marker in text for marker in (".", "e", "E")):
            number = float(text)
            return number if math.isfinite(number) else text
        return int(text)
    except ValueError:
        return text


def collect_columns(rows: list[dict[str, Any]]) -> list[str]:
    columns: list[str] = []
    seen: set[str] = set()
    for row in rows:
        for key in row:
            column = str(key)
            if column not in seen:
                seen.add(column)
                columns.append(column)
    return columns


def value_type(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int) and not isinstance(value, bool):
        return "integer"
    if isinstance(value, float) and math.isfinite(value):
        return "float"
    if isinstance(value, str):
        return "string"
    return "mixed"


def infer_column_type(values: list[Any]) -> str:
    types = {value_type(value) for value in values if value_type(value) != "null"}
    if not types:
        return "null"
    if types == {"integer"}:
        return "integer"
    if types <= {"integer", "float"}:
        return "float"
    if len(types) == 1:
        return next(iter(types))
    return "mixed"


def clean_number(value: float) -> int | float:
    if math.isclose(value, round(value), rel_tol=0, abs_tol=1e-9):
        return int(round(value))
    return round(value, 6)


def percentile(values: list[float], quantile: float) -> int | float | None:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return clean_number(ordered[0])
    rank = (len(ordered) - 1) * quantile
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return clean_number(ordered[lower])
    weight = rank - lower
    return clean_number(ordered[lower] * (1 - weight) + ordered[upper] * weight)


def numeric_column_stats(column: str, column_type: str, values: list[Any], missing: int) -> dict[str, Any]:
    numbers = [float(value) for value in values if value is not None]
    mean = sum(numbers) / len(numbers) if numbers else 0
    variance = sum((value - mean) ** 2 for value in numbers) / len(numbers) if numbers else 0
    return {
        "column": column,
        "type": column_type,
        "kind": "numeric",
        "count": len(numbers),
        "missing": missing,
        "min": clean_number(min(numbers)) if numbers else None,
        "max": clean_number(max(numbers)) if numbers else None,
        "mean": clean_number(mean) if numbers else None,
        "stddev": clean_number(math.sqrt(variance)) if numbers else None,
        "p50": percentile(numbers, 0.5),
        "p90": percentile(numbers, 0.9),
    }


def categorical_column_stats(column: str, column_type: str, values: list[Any], missing: int) -> dict[str, Any]:
    counter = Counter(display_scalar(value, limit=80) for value in values if value is not None)
    return {
        "column": column,
        "type": column_type,
        "kind": "categorical",
        "count": sum(counter.values()),
        "missing": missing,
        "unique_count": len(counter),
        "top_counts": [{"value": value, "count": count} for value, count in counter.most_common(20)],
    }


def text_length_column_stats(column: str, values: list[Any], missing: int) -> dict[str, Any]:
    lengths = [len(value) for value in values if isinstance(value, str)]
    buckets = [
        ("0-30", lambda length: length <= 30),
        ("31-100", lambda length: 31 <= length <= 100),
        ("101-300", lambda length: 101 <= length <= 300),
        ("301-1000", lambda length: 301 <= length <= 1000),
        ("1000+", lambda length: length > 1000),
    ]
    return {
        "column": column,
        "type": "string",
        "kind": "text_length",
        "count": len(lengths),
        "missing": missing,
        "length": {
            "min": min(lengths) if lengths else None,
            "max": max(lengths) if lengths else None,
            "mean": clean_number(sum(lengths) / len(lengths)) if lengths else None,
            "p50": percentile([float(length) for length in lengths], 0.5),
            "p90": percentile([float(length) for length in lengths], 0.9),
            "p95": percentile([float(length) for length in lengths], 0.95),
        },
        "buckets": [
            {"label": label, "count": sum(1 for length in lengths if predicate(length))}
            for label, predicate in buckets
        ],
    }


def analyze_rows(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[str]]:
    columns = collect_columns(rows)
    schema: list[dict[str, Any]] = []
    stats: list[dict[str, Any]] = []
    total = len(rows)
    for column in columns:
        values = [row.get(column) if column in row else None for row in rows]
        missing = sum(1 for value in values if value is None)
        non_missing = [value for value in values if value is not None]
        column_type = infer_column_type(values)
        schema.append(
            {
                "name": column,
                "type": column_type,
                "non_null": total - missing,
                "missing": missing,
            }
        )
        if column_type in {"integer", "float"}:
            stats.append(numeric_column_stats(column, column_type, values, missing))
        elif column_type == "string" and non_missing and max(len(str(value)) for value in non_missing) >= 30:
            stats.append(text_length_column_stats(column, values, missing))
        elif column_type in {"string", "boolean"}:
            stats.append(categorical_column_stats(column, column_type, values, missing))
        elif column_type == "null":
            stats.append({"column": column, "type": "null", "kind": "empty", "count": 0, "missing": missing})
        else:
            mixed = categorical_column_stats(column, column_type, values, missing)
            mixed["kind"] = "mixed"
            stats.append(mixed)
    return schema, stats, columns


def parse_jsonl_preview(text: str, max_rows: int, warnings: list[str]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        if len(rows) >= max_rows:
            add_warning(warnings, f"row sample capped at {max_rows} rows")
            break
        stripped = line.strip()
        if not stripped:
            continue
        try:
            value = json.loads(stripped)
        except json.JSONDecodeError as exc:
            add_warning(warnings, f"line {line_number} is not valid JSON: {exc.msg}")
            continue
        if isinstance(value, dict):
            rows.append(value)
        else:
            add_warning(warnings, f"line {line_number} is not a JSON object")
    return rows, rows


def parse_json_preview(text: str, max_rows: int, warnings: list[str]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail=f"invalid JSON preview source: {exc.msg}") from exc

    if isinstance(value, list):
        candidates = value
    elif isinstance(value, dict) and isinstance(value.get("rows"), list):
        candidates = value["rows"]
    elif isinstance(value, dict) and isinstance(value.get("data"), list):
        candidates = value["data"]
    elif isinstance(value, dict):
        candidates = [value]
    else:
        add_warning(warnings, "top-level JSON value is not an object or array")
        candidates = []

    rows: list[dict[str, Any]] = []
    for index, item in enumerate(candidates, start=1):
        if len(rows) >= max_rows:
            add_warning(warnings, f"row sample capped at {max_rows} rows")
            break
        if isinstance(item, dict):
            rows.append(item)
        else:
            add_warning(warnings, f"JSON row {index} is not an object")
    return rows, rows


def parse_csv_preview(text: str, max_rows: int, warnings: list[str]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    reader = csv.DictReader(StringIO(text))
    if not reader.fieldnames:
        add_warning(warnings, "CSV header row was not found")
        return [], []

    rows: list[dict[str, Any]] = []
    stats_rows: list[dict[str, Any]] = []
    for index, row in enumerate(reader):
        if index >= max_rows:
            add_warning(warnings, f"row sample capped at {max_rows} rows")
            break
        clean_row: dict[str, Any] = {}
        stats_row: dict[str, Any] = {}
        for key, value in row.items():
            column = "_extra" if key is None else str(key)
            if key is None and isinstance(value, list):
                raw_value: Any = ",".join(value)
            else:
                raw_value = value
            clean_row[column] = raw_value
            stats_row[column] = coerce_csv_value(raw_value)
        rows.append(clean_row)
        stats_rows.append(stats_row)
    return rows, stats_rows


def parquet_value_to_safe(value: Any) -> Any:
    if value is None or isinstance(value, (bool, int, str)):
        return value
    if isinstance(value, float):
        return value if math.isfinite(value) else str(value)
    if isinstance(value, Decimal):
        try:
            number = float(value)
            return number if math.isfinite(number) else str(value)
        except (OverflowError, ValueError):
            return str(value)
    if isinstance(value, (dt.datetime, dt.date, dt.time)):
        return value.isoformat()
    if isinstance(value, (bytes, bytearray, memoryview)):
        return bytes(value).decode("utf-8", errors="replace")
    if isinstance(value, list):
        return [parquet_value_to_safe(item) for item in value]
    if isinstance(value, tuple):
        return [parquet_value_to_safe(item) for item in value]
    if isinstance(value, dict):
        return {str(key): parquet_value_to_safe(item) for key, item in value.items()}
    return display_scalar(value)


def parquet_row_to_safe(row: dict[str, Any]) -> dict[str, Any]:
    return {str(key): parquet_value_to_safe(value) for key, value in row.items()}


def parquet_source_types(parquet_file: Any) -> dict[str, str]:
    try:
        schema = parquet_file.schema_arrow
    except Exception:
        return {}
    return {field.name: str(field.type) for field in schema}


def parse_parquet_preview(source: Any, max_rows: int, warnings: list[str]) -> tuple[
    list[dict[str, Any]], list[dict[str, Any]], dict[str, str]
]:
    try:
        import pyarrow as pa
        import pyarrow.parquet as pq
    except ImportError as exc:
        raise HTTPException(status_code=500, detail="Parquet preview support is not installed") from exc

    try:
        parquet_file = pq.ParquetFile(source)
        source_types = parquet_source_types(parquet_file)
        rows: list[dict[str, Any]] = []
        for batch in parquet_file.iter_batches(batch_size=max(1, max_rows)):
            for row in pa.Table.from_batches([batch]).to_pylist():
                if len(rows) >= max_rows:
                    break
                rows.append(parquet_row_to_safe(row))
            if len(rows) >= max_rows:
                if parquet_file.metadata and parquet_file.metadata.num_rows > max_rows:
                    add_warning(warnings, f"row sample capped at {max_rows} rows")
                break
    except PreviewRangeLimitExceeded as exc:
        raise HTTPException(
            status_code=413,
            detail=f"Parquet preview range reads exceeded {PREVIEW_PARQUET_MAX_BYTES} bytes",
        ) from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"invalid Parquet preview source: {exc}") from exc

    return rows, rows, source_types


def finalize_preview_payload(
    path: str,
    file_format: str,
    rows: list[dict[str, Any]],
    stats_rows: list[dict[str, Any]],
    warnings: list[str],
    max_bytes: int,
    truncated: bool,
    source_types: dict[str, str] | None = None,
) -> dict[str, Any]:
    if not rows:
        add_warning(warnings, "no object rows were found in the preview sample")
    schema, stats, columns = analyze_rows(stats_rows)
    if source_types:
        schema_names = {column_schema["name"] for column_schema in schema}
        for column_schema in schema:
            source_type = source_types.get(column_schema["name"])
            if source_type:
                column_schema["source_type"] = source_type
        for column, source_type in source_types.items():
            if column not in schema_names:
                schema.append(
                    {
                        "name": column,
                        "type": "null",
                        "non_null": 0,
                        "missing": 0,
                        "source_type": source_type,
                    }
                )
    preview_rows = [
        {column: display_scalar(row.get(column) if column in row else None) for column in columns}
        for row in rows[:PREVIEW_RETURN_ROWS]
    ]
    return {
        "file": {
            "path": path,
            "format": file_format,
            "sampled_rows": len(rows),
            "returned_rows": len(preview_rows),
            "max_rows": PREVIEW_MAX_ROWS,
            "max_bytes": max_bytes,
            "truncated_bytes": truncated,
        },
        "schema": schema,
        "rows": preview_rows,
        "stats": stats,
        "warnings": warnings,
    }


def build_preview_payload(path: str, file_format: str, data: bytes, truncated: bool) -> dict[str, Any]:
    warnings: list[str] = []
    if truncated:
        add_warning(warnings, f"preview read capped at {PREVIEW_MAX_BYTES} bytes")
    text = data.decode("utf-8", errors="replace")
    if file_format == "jsonl":
        rows, stats_rows = parse_jsonl_preview(text, PREVIEW_MAX_ROWS, warnings)
    elif file_format == "json":
        rows, stats_rows = parse_json_preview(text, PREVIEW_MAX_ROWS, warnings)
    elif file_format == "csv":
        rows, stats_rows = parse_csv_preview(text, PREVIEW_MAX_ROWS, warnings)
    else:
        raise HTTPException(status_code=400, detail="unsupported preview file type")

    return finalize_preview_payload(path, file_format, rows, stats_rows, warnings, PREVIEW_MAX_BYTES, truncated)


def build_parquet_preview_payload(path: str, source: Any) -> dict[str, Any]:
    warnings: list[str] = []
    rows, stats_rows, source_types = parse_parquet_preview(source, PREVIEW_MAX_ROWS, warnings)
    return finalize_preview_payload(
        path,
        "parquet",
        rows,
        stats_rows,
        warnings,
        PREVIEW_PARQUET_MAX_BYTES,
        False,
        source_types,
    )


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(APP_DIR / "static" / "index.html")


@app.get("/login")
async def login(request: Request):
    redirect_uri = os.environ.get("HF_UI_OIDC_REDIRECT_URI", f"{PUBLIC_URL}/oauth/callback")
    return await oauth.authentik.authorize_redirect(request, redirect_uri)


@app.get("/oauth/callback")
async def oauth_callback(request: Request):
    token = await oauth.authentik.authorize_access_token(request)
    userinfo = token.get("userinfo") or {}
    if not userinfo and token.get("access_token"):
        userinfo = await oauth.authentik.userinfo(token=token)
    request.session["user"] = {
        "name": userinfo.get("preferred_username") or userinfo.get("name") or userinfo.get("email") or "user",
        "email": userinfo.get("email", ""),
        "groups": userinfo.get("groups") or [],
        "auth": "oidc",
    }
    return RedirectResponse("/")


@app.get("/logout")
async def logout(request: Request):
    request.session.clear()
    return RedirectResponse("/")


@app.get("/api/health")
async def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "service": "hf-ui",
        "version": VERSION,
        "catalog_file": str(CATALOG_FILE),
        "auth_required": AUTH_REQUIRED,
    }


@app.get("/api/auth/me")
async def me(request: Request) -> dict[str, Any]:
    user = current_user(request)
    return {"authenticated": bool(user), "user": user, "login_url": "/login", "logout_url": "/logout"}


@app.get("/api/models")
async def models(request: Request, q: str = "", tag: str = "") -> dict[str, Any]:
    require_user(request)
    return {"items": [public_item(item) for item in visible_items("models", q, tag)]}


@app.get("/api/datasets")
async def datasets(request: Request, q: str = "", tag: str = "") -> dict[str, Any]:
    require_user(request)
    return {"items": [public_item(item) for item in visible_items("datasets", q, tag)]}


@app.get("/api/dataset/{owner}/{name}/preview")
async def dataset_preview(
    request: Request,
    owner: str,
    name: str,
    path: str = Query(..., min_length=1),
) -> dict[str, Any]:
    require_user(request)
    item = find_item("datasets", owner, name)
    file_format = preview_format(path)
    if not file_format:
        raise HTTPException(status_code=400, detail="unsupported preview file type")
    object_name = safe_object_path(item, path)
    if file_format == "parquet":
        size = object_size(item["bucket"], object_name)
        source = MinioRangeReader(item["bucket"], object_name, size, PREVIEW_PARQUET_MAX_BYTES)
        return build_parquet_preview_payload(path, source)
    data, truncated = read_object_bytes(item["bucket"], object_name, PREVIEW_MAX_BYTES)
    return build_preview_payload(path, file_format, data, truncated)


@app.get("/api/{kind}/{owner}/{name}")
async def detail(request: Request, kind: str, owner: str, name: str) -> dict[str, Any]:
    require_user(request)
    collection = collection_for_kind(kind)
    item = find_item(collection, owner, name)
    readme_name = safe_object_path(item, item.get("readme", "README.md"))
    return {"item": public_item(item), "readme": read_object_text(item["bucket"], readme_name)}


@app.get("/api/{kind}/{owner}/{name}/files")
async def files(request: Request, kind: str, owner: str, name: str) -> dict[str, Any]:
    require_user(request)
    collection = collection_for_kind(kind)
    item = find_item(collection, owner, name)
    try:
        objects = list(minio_client().list_objects(item["bucket"], prefix=item["prefix"], recursive=True))
    except S3Error as exc:
        raise HTTPException(status_code=502, detail=exc.message) from exc
    return {"items": [object_to_dict(obj, item["prefix"]) for obj in objects]}


@app.post("/api/files/presign")
async def presign(
    request: Request,
    kind: str = Query(..., pattern="^(model|dataset)$"),
    owner: str = Query(...),
    name: str = Query(...),
    path: str = Query(...),
    action: str = Query("download", pattern="^(download|upload)$"),
    overwrite: bool = Query(False),
) -> dict[str, Any]:
    require_user(request)
    collection = collection_for_kind(kind)
    item = find_item(collection, owner, name)
    expires = timedelta(seconds=PRESIGN_EXPIRY_SECONDS)
    client = minio_client(public=True)

    if action == "upload":
        object_name = safe_upload_object_path(item, path)
        if not overwrite and object_exists(item["bucket"], object_name):
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "object_exists",
                    "message": "Object already exists. Set overwrite=true to replace it.",
                },
            )
        try:
            url = client.presigned_put_object(
                item["bucket"],
                object_name,
                expires=expires,
            )
        except S3Error as exc:
            raise HTTPException(status_code=502, detail=exc.message) from exc
        return {
            "method": "PUT",
            "url": url,
            "headers": {},
            "expires_in": PRESIGN_EXPIRY_SECONDS,
            "file": {"path": path, "size": None},
        }

    object_name = safe_object_path(item, path)
    try:
        url = client.presigned_get_object(
            item["bucket"],
            object_name,
            expires=expires,
        )
    except S3Error as exc:
        raise HTTPException(status_code=502, detail=exc.message) from exc
    return {"url": url, "expires_in": str(PRESIGN_EXPIRY_SECONDS)}


@app.get("/api/files/download")
async def download(
    request: Request,
    kind: str = Query(..., pattern="^(model|dataset)$"),
    owner: str = Query(...),
    name: str = Query(...),
    path: str = Query(...),
) -> StreamingResponse:
    require_user(request)
    collection = collection_for_kind(kind)
    item = find_item(collection, owner, name)
    object_name = safe_object_path(item, path)
    try:
        response = minio_client().get_object(item["bucket"], object_name)
    except S3Error as exc:
        if exc.code in {"NoSuchKey", "NoSuchBucket"}:
            raise HTTPException(status_code=404, detail="file not found") from exc
        raise HTTPException(status_code=502, detail=exc.message) from exc

    filename = html.escape(Path(path).name or "download.bin", quote=True)

    def iterator():
        try:
            for chunk in response.stream(64 * 1024):
                yield chunk
        finally:
            response.close()
            response.release_conn()

    return StreamingResponse(
        iterator(),
        media_type="application/octet-stream",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


def collection_for_kind(kind: str) -> str:
    if kind == "model":
        return "models"
    if kind == "dataset":
        return "datasets"
    raise HTTPException(status_code=404, detail="unknown catalog kind")


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
