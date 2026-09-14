"""Applied independently by gateway and connector; never proxy arbitrary dashboard paths."""
from urllib.parse import urlsplit, unquote, parse_qs
from .settings import APP_IDS, PREFIX

LOCAL_ONLY = frozenset({'/api/terminal', '/api/remote-desktop',
    '/api/host/shutdown', '/api/openclaw/dashboard'})
SERVICES = APP_IDS - {'dashboard', 'openwebui'}
DOWNLOADS = frozenset({'llm', 'comfy', 'unsloth'})


def checked_path(path: str) -> str:
    if len(path) > 16384 or not path.startswith('/') or path.startswith('//'):
        raise ValueError('Invalid request path')
    decoded = unquote(unquote(path.split('?', 1)[0]))
    if ('\\' in decoded or any(ord(c) < 32 for c in decoded)
            or any(p in {'.', '..'} for p in decoded.split('/'))
            or decoded.startswith('//') or '://' in decoded):
        raise ValueError('Unsafe request path')
    if urlsplit(path).scheme or urlsplit(path).netloc:
        raise ValueError('Absolute request targets are prohibited')
    return decoded


def check_request(app_id: str, method: str, path: str) -> None:
    route = checked_path(path)
    if app_id not in APP_IDS or method not in {'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'}:
        raise ValueError('Unsupported request')
    if route.startswith(PREFIX):
        raise ValueError('Reserved gateway path')
    if app_id != 'dashboard':
        return
    if route in LOCAL_ONLY:
        raise PermissionError('This action must be accessed locally.')
    allowed_get = {'/api/status', '/api/model-download', '/api/ollama/models'}
    allowed_post = {'/api/action', '/api/model-download',
                    '/api/model-download/cancel', '/api/ollama/chat'}
    if method == 'GET' and (route in allowed_get or
            route.startswith('/api/logs/') and route.rsplit('/', 1)[-1] in SERVICES):
        if route == '/api/model-download':
            target = parse_qs(urlsplit(path).query).get('target', [''])[0]
            if target not in DOWNLOADS:
                raise ValueError('Invalid download target')
        return
    if method == 'POST' and route in allowed_post:
        return
    raise PermissionError('Dashboard route is not available remotely')
