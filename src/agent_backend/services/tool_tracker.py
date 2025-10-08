import contextvars

from typing import Any, List, Optional


# Context-local container for the current request's used_tools list.
_current_used_tools: contextvars.ContextVar[Optional[List[str]]] = contextvars.ContextVar(
    "current_used_tools", default=None
)


def create_used_tools_list() -> List[str]:
    """Return a fresh container for recording used tools (convenience).

    This is useful if callers prefer to manage lists themselves, but the
    recommended pattern is to set the per-request list via
    `set_current_used_tools` before invoking the agent.
    """
    return []


def set_current_used_tools(lst: Optional[List[str]]) -> None:
    """Set the ContextVar to point to the per-request used_tools list.

    Pass None to clear and revert to fallback.
    """
    _current_used_tools.set(lst)


def get_current_used_tools() -> List[str]:
    """Return the current per-request list or a fresh empty list.

    Wrappers call this at runtime so they always append to the appropriate
    list for the active task. Returns a fresh list if no per-request list
    was set to avoid cross-request contamination.
    """
    lst = _current_used_tools.get()
    return lst if lst is not None else []


def wrap_call_tool(plugin: Any, name_attr: str = "call_tool") -> None:
    """Wrap a plugin (and its session) to record tool invocations.

    The wrapper appends entries to `get_current_used_tools()` so callers can set
    a per-request list with `set_current_used_tools()`.
    """
    if plugin is None:
        return

    plugin_name = getattr(plugin, "name", repr(plugin))

    # Try to wrap the public call_tool if it exists
    if hasattr(plugin, name_attr):
        try:
            orig = getattr(plugin, name_attr)

            async def wrapped_call(*args, **kwargs):
                try:
                    if args:
                        arg0 = args[0]
                        if isinstance(arg0, str):
                            tool_name = arg0
                        else:
                            tool_name = (
                                getattr(arg0, "method", None)
                                or getattr(arg0, "tool", None)
                                or getattr(arg0, "name", None)
                                or repr(arg0)
                            )
                        get_current_used_tools().append(f"{plugin_name}:{tool_name}")
                    return await orig(*args, **kwargs)
                except Exception:
                    get_current_used_tools().append(f"{plugin_name}:call_failed")
                    raise

            try:
                setattr(plugin, name_attr, wrapped_call)
            except Exception:
                pass
        except Exception:
            pass

    # Try to wrap an underlying session.call_tool if present; this often carries the canonical tool identifier.
    try:
        sess = getattr(plugin, "session", None)
        if sess and hasattr(sess, "call_tool"):
            orig_sess_call = sess.call_tool
            async def wrapped_sess_call(tool_name, *a, **kw):
                try:
                    tn = tool_name if isinstance(tool_name, str) else repr(tool_name)
                    
                    # Capture function parameters
                    params_info = []
                    if a:
                        params_info.extend([f"arg{i}: {repr(arg)}" for i, arg in enumerate(a)])
                    if kw:
                        params_info.extend([f"{k}: {repr(v)}" for k, v in kw.items()])
                    
                    params_str = f"{','.join(params_info)}" if params_info else ""
                    get_current_used_tools().append(f"{plugin_name}.{tn}.{params_str}")
                except Exception:
                    get_current_used_tools().append(f"{plugin_name}.unknown")
                return await orig_sess_call(tool_name, *a, **kw)

            try:
                setattr(sess, "call_tool", wrapped_sess_call)
            except Exception:
                pass
    except Exception:
        pass


def install_wrappers(*plugins: Any) -> None:
    """Install wrappers for a sequence of plugin objects.

    Example:
        install_wrappers(gh_plugin, learn_plugin, weather_plugin)
    """
    for p in plugins:
        try:
            wrap_call_tool(p)
        except Exception:
            pass
