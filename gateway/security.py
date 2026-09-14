"""Session and request checks run before any local connection is opened."""
from collections import deque
import hmac
import secrets
import time
from urllib.parse import quote
from aiohttp import web
from .settings import COOKIE, PREFIX


class Security:
    def __init__(self, settings):
        self.settings = settings
        self.sessions: dict = {}
        self.states: dict = {}
        self.attempts: dict = {}

    def issue(self, public_origin: str) -> str:
        self.prune()
        if len(self.sessions) >= 64:
            raise web.HTTPTooManyRequests(text='Too many sessions; sign out first')
        sid = secrets.token_urlsafe(32)
        self.sessions[sid] = {'origin': public_origin,
                              'expires': time.time() + self.settings.session_seconds}
        return sid

    def prune(self) -> None:
        now = time.time()
        for records in (self.sessions, self.states):
            for key in list(records):
                if records[key]['expires'] < now:
                    del records[key]

    def valid(self, sid: str, public_origin: str) -> bool:
        record = self.sessions.get(sid, {})
        return (record.get('origin') == public_origin
                and record.get('expires', 0) > time.time())

    def machine(self, request: web.Request) -> None:
        value = request.headers.get('Authorization', '')
        if not hmac.compare_digest(value, 'Bearer ' + self.settings.token):
            raise web.HTTPUnauthorized(text='Connector authentication required')

    def rate(self, key: str, limit: int = 240, seconds: int = 60) -> None:
        now = time.monotonic()
        if len(self.attempts) > 512:
            self.attempts = {k: v for k, v in self.attempts.items()
                             if v and v[-1] > now - 300}
        queue = self.attempts.setdefault(key, deque(maxlen=limit + 1))
        while queue and queue[0] < now - seconds:
            queue.popleft()
        if len(queue) >= limit:
            raise web.HTTPTooManyRequests(headers={'Retry-After': str(seconds)})
        queue.append(now)

    @web.middleware
    async def middleware(self, request, handler):
        if request.path == PREFIX + '/health' and request.method in {'GET', 'HEAD'}:
            return await handler(request)
        public = next((o for o in self.settings.origins
                       if o.split('://', 1)[1] == request.host), None)
        if public is None:
            raise web.HTTPMisdirectedRequest(text='Unrecognized host')
        request['public'] = public
        request['app_id'] = self.settings.origins[public]
        path = request.path
        if path in {PREFIX + '/health', PREFIX + '/login', PREFIX + '/callback'}:
            return await handler(request)
        if path == PREFIX + '/connector' or path.startswith(PREFIX + '/stream/'):
            self.machine(request)
            return await handler(request)
        sid = request.cookies.get(COOKIE, '')
        if not self.valid(sid, public):
            if request.method == 'GET' and 'text/html' in request.headers.get('Accept', ''):
                raise web.HTTPFound(PREFIX + '/login?next=' + quote(request.raw_path, safe=''))
            raise web.HTTPUnauthorized(text='Sign in through /_gateway/login')
        request['sid'] = sid
        self.rate('session:' + sid, 1200)
        browser_origin = request.headers.get('Origin')
        if request.method not in {'GET', 'HEAD', 'OPTIONS'} or request.headers.get('Upgrade'):
            if browser_origin != public:
                raise web.HTTPForbidden(text='Browser origin rejected')
        if browser_origin and browser_origin != public:
            raise web.HTTPForbidden(text='Cross-origin access rejected')
        if request.headers.get('Sec-Fetch-Site') == 'cross-site':
            if request.method != 'GET' or request.headers.get('Sec-Fetch-Mode') != 'navigate':
                raise web.HTTPForbidden(text='Cross-site subresource rejected')
        return await handler(request)


async def secure_headers(request, response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000'
    response.headers['Cache-Control'] = 'no-store'
    response.headers.pop('Server', None)
    if request.get('app_id') == 'dashboard' or request.path.startswith(PREFIX):
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['Content-Security-Policy'] = (
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; "
            "img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; "
            "base-uri 'none'; form-action 'self'")
    elif 'frame-ancestors' not in response.headers.get('Content-Security-Policy', ''):
        existing = response.headers.get('Content-Security-Policy', '').rstrip('; ')
        response.headers['Content-Security-Policy'] = (
            (existing + '; ' if existing else '') + "frame-ancestors 'self'")
