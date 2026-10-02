"""Fixed loopback app APIs, with no caller-selected URLs or shell commands."""
import json
from pathlib import Path
from urllib.request import Request, build_opener, ProxyHandler, HTTPRedirectHandler

PORTS = {'ollama':11434, 'comfy':8188, 'unsloth':8888, 'invoke':9090, 'llm':8080}

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ConnectionError('App API redirected; no credentials forwarded')

def call(app, path, body=None):
    headers = {'Accept':'application/json'}
    if app == 'unsloth':
        key = Path.home()/'.unsloth/studio/auth/dashboard-api-key'
        headers['Authorization'] = 'Bearer ' + key.read_text().strip()
    data = None if body is None else json.dumps(body).encode()
    if data is not None:
        headers['Content-Type'] = 'application/json'
    request = Request(f'http://127.0.0.1:{PORTS[app]}{path}', data=data, headers=headers)
    with build_opener(ProxyHandler({}), NoRedirect()).open(request, timeout=12) as response:
        raw = response.read(2_000_001)
        if len(raw) > 2_000_000:
            raise ValueError('App response too large')
        return json.loads(raw) if raw.strip() else {}

def row(key, name, can_unload=False, activity='unknown', **extra):
    return dict(id=key, name=str(name), can_unload=can_unload, activity=activity, **extra)

def report(app, models=(), note='', activity='unknown', unload_all=False, **extra):
    result = dict(app=app, online=True, models=list(models), note=note,
                  activity=activity, unload_all=unload_all)
    result.update(extra)
    return result
