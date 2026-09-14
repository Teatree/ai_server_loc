from http.cookies import SimpleCookie, CookieError
from urllib.parse import urlsplit
from .settings import COOKIE, STATE_COOKIE

HOP = {'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization',
       'te', 'trailer', 'transfer-encoding', 'upgrade', 'host', 'content-length'}
RESERVED = {COOKIE, STATE_COOKIE}


def clean_request(headers, public: str) -> list:
    pairs = list(headers.items()) if hasattr(headers, 'items') else headers
    extra = {x.strip().lower() for k, v in pairs if k.lower() == 'connection'
             for x in v.split(',')}
    result = []
    for key, value in pairs:
        name = key.lower()
        if name in HOP | extra or name.startswith(('x-forwarded-', 'sec-websocket-')):
            continue
        if name in {'forwarded', 'x-real-ip', 'x-openclaw-scopes', 'x-forwarded-user',
                    'remote-user', 'x-auth-request-user', 'x-auth-request-email',
                    'cf-access-authenticated-user-email', 'tailscale-user-login',
                    'tailscale-user-name', 'tailscale-user-profile-pic'}:
            continue
        if name == 'cookie':
            value = '; '.join(p.strip() for p in value.split(';')
                              if p.split('=', 1)[0].strip() not in RESERVED)
            if not value:
                continue
        result.append([key, value])
    result.extend([['X-Forwarded-Proto', urlsplit(public).scheme],
                   ['X-Forwarded-Host', urlsplit(public).netloc]])
    return result


def clean_response(headers: list, base: str, public: str) -> list:
    result = []
    for key, value in headers:
        name = key.lower()
        if name in HOP or name == 'server':
            continue
        if name == 'set-cookie':
            try:
                cookies = SimpleCookie(); cookies.load(value)
            except CookieError:
                continue
            for cookie_name, morsel in cookies.items():
                if cookie_name in RESERVED:
                    continue
                morsel['domain'] = ''
                morsel['secure'] = public.startswith('https:')
                result.append([key, morsel.OutputString()])
            continue
        if name == 'location' and (value == base or value.startswith(base + '/')):
            value = public + value[len(base):]
        result.append([key, value])
    return result
