import base64
import hashlib
import hmac
import secrets
import time
from urllib.parse import urlencode
from aiohttp import web, ClientTimeout
from .settings import COOKIE, STATE_COOKIE, PREFIX
from .policy import checked_path


class OAuth:
    def __init__(self, security, client):
        self.security, self.client = security, client

    async def login(self, request):
        sec = self.security
        sec.rate('login', 30, 300)
        sec.prune()
        destination = request.query.get('next', '/')
        if checked_path(destination).startswith(PREFIX):
            destination = '/'
        if len(sec.states) >= 32:
            raise web.HTTPTooManyRequests()
        state, verifier, binding = (secrets.token_urlsafe(32) for _ in range(3))
        public = request['public']
        sec.states[state] = {'verifier': verifier, 'binding': binding,
                             'origin': public, 'expires': time.time() + 300,
                             'destination': destination}
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest())
        params = {'client_id': sec.settings.client_id, 'state': state,
                  'redirect_uri': public + PREFIX + '/callback', 'scope': 'read:user',
                  'code_challenge': challenge.decode().rstrip('='),
                  'code_challenge_method': 'S256'}
        response = web.HTTPFound('https://github.com/login/oauth/authorize?' + urlencode(params))
        response.set_cookie(STATE_COOKIE, binding, secure=not sec.settings.testing,
                            httponly=True, samesite='Lax', max_age=300, path='/')
        raise response

    async def github_user(self, code: str, record: dict) -> dict:
        settings = self.security.settings
        data = {'client_id': settings.client_id, 'client_secret': settings.client_secret,
                'code': code, 'code_verifier': record['verifier'],
                'redirect_uri': record['origin'] + PREFIX + '/callback'}
        async with self.client.post('https://github.com/login/oauth/access_token',
                                    data=data, headers={'Accept': 'application/json'},
                                    timeout=ClientTimeout(total=20)) as reply:
            token = (await reply.json()).get('access_token') if reply.status == 200 else None
        if not token:
            raise web.HTTPUnauthorized(text='GitHub authorization failed')
        headers = {'Authorization': 'Bearer ' + token,
                   'Accept': 'application/vnd.github+json', 'User-Agent': 'AI-Private-Gateway'}
        async with self.client.get('https://api.github.com/user', headers=headers,
                                   timeout=ClientTimeout(total=20)) as reply:
            if reply.status != 200:
                raise web.HTTPUnauthorized(text='GitHub identity could not be verified')
            return await reply.json()

    async def callback(self, request):
        sec = self.security
        sec.rate('callback', 40, 300)
        record = sec.states.pop(request.query.get('state', ''), None)
        binding = request.cookies.get(STATE_COOKIE, '')
        if (not record or record['expires'] < time.time()
                or record['origin'] != request['public']
                or not hmac.compare_digest(record['binding'], binding)):
            raise web.HTTPForbidden(text='Login expired or browser binding invalid; sign in again')
        code = request.query.get('code', '')
        if not code or len(code) > 1024:
            raise web.HTTPUnauthorized(text='GitHub authorization code required')
        user = await self.github_user(code, record)
        if str(user.get('id', '')) != sec.settings.owner_id:
            raise web.HTTPForbidden(text='This account is not authorized')
        if user.get('two_factor_authentication') is not True:
            raise web.HTTPForbidden(text='Enable GitHub two-factor authentication, then sign in again')
        sid = sec.issue(request['public'])
        response = web.HTTPFound(record['destination'])
        response.set_cookie(COOKIE, sid, secure=not sec.settings.testing,
                            httponly=True, samesite='Lax',
                            max_age=sec.settings.session_seconds, path='/')
        response.del_cookie(STATE_COOKIE, path='/')
        raise response

    async def logout(self, request):
        sid = request['sid']
        self.security.sessions.pop(sid, None)
        await request.app['relay'].revoke(sid)
        response = web.Response(text='Signed out of this app. Close this tab.')
        response.del_cookie(COOKIE, path='/')
        return response
