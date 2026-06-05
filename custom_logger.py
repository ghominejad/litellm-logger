from litellm.integrations.custom_logger import CustomLogger
import hashlib
import os
import json
import asyncio
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor

LOGS_DIR = "/app/logs"
TOOLS_REGISTRY_DIR = os.path.join(LOGS_DIR, "tools")

# Single shared executor — bounded so we don't fork unbounded threads
_executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="litellm-logger")


class LocalDirectoryLogger(CustomLogger):
    def _serialize_response(self, response_obj):
        # Exceptions don't have model_dump; check type first
        if isinstance(response_obj, BaseException):
            return {
                "error_type": type(response_obj).__name__,
                "error_message": str(response_obj),
            }
        if hasattr(response_obj, "model_dump"):
            try:
                return response_obj.model_dump()
            except Exception:
                pass
        if hasattr(response_obj, "json") and callable(response_obj.json):
            try:
                out = response_obj.json()
                return out if isinstance(out, (dict, list)) else json.loads(out)
            except Exception:
                pass
        return str(response_obj)

    def _write_log_sync(self, kwargs, response_obj):
        """Blocking I/O — only ever called inside a worker thread."""
        try:
            now = datetime.now()
            log_dir = os.path.join(LOGS_DIR, now.strftime("%y%m%d-%H"))
            os.makedirs(log_dir, exist_ok=True)

            time_prefix = now.strftime("%H%M%S_%f")
            call_id = kwargs.get("litellm_call_id", "unknown")
            filepath = os.path.join(log_dir, f"{time_prefix}_{call_id}.json")

            response_data = self._serialize_response(response_obj)
            optional_params = kwargs.get("optional_params", {}) or {}
            tools = optional_params.get("tools") or kwargs.get("tools")

            tools_hash = None
            if tools:
                canonical = json.dumps(
                    tools, sort_keys=True, separators=(",", ":"),
                    ensure_ascii=False, default=str,
                ).encode("utf-8")
                tools_hash = hashlib.sha256(canonical).hexdigest()
                path = os.path.join(TOOLS_REGISTRY_DIR, f"{tools_hash}.json")
                if not os.path.exists(path):
                    os.makedirs(TOOLS_REGISTRY_DIR, exist_ok=True)
                    with open(path, "w", encoding="utf-8") as f:
                        json.dump(tools, f, indent=2, ensure_ascii=False, default=str)

            payload = {
                "timestamp": now.isoformat(),
                "model": kwargs.get("model", "unknown"),
                "messages": kwargs.get("messages", []),
                "system": optional_params.get("system") or kwargs.get("system"),
                "tools_hash": tools_hash,
                "tool_choice": optional_params.get("tool_choice"),
                "response": response_data,
            }
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2, ensure_ascii=False, default=str)
        except Exception as e:
            # Never raise out of a logging hook
            print(f"[Custom Logger Error] {e}")

    # Sync hooks: keep behavior, but offload to executor so we don't block
    def log_success_event(self, kwargs, response_obj, start_time, end_time):
        _executor.submit(self._write_log_sync, kwargs, response_obj)

    def log_failure_event(self, kwargs, response_obj, start_time, end_time):
        _executor.submit(self._write_log_sync, kwargs, response_obj)

    # Async hooks: run blocking I/O in the default loop executor — does NOT await
    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        loop = asyncio.get_running_loop()
        loop.run_in_executor(_executor, self._write_log_sync, kwargs, response_obj)

    async def async_log_failure_event(self, kwargs, response_obj, start_time, end_time):
        loop = asyncio.get_running_loop()
        loop.run_in_executor(_executor, self._write_log_sync, kwargs, response_obj)


proxy_logger = LocalDirectoryLogger()