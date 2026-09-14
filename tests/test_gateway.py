import asyncio
import json
import time
import unittest
from urllib.parse import urlsplit, parse_qs
from aiohttp import web, ClientSession, DummyCookieJar, WSMsgType, WSServerHandshakeError
from aiohttp.test_utils import TestServer
from gateway.server import create_app
from gateway.settings import Settings, APP_IDS, COOKIE, STATE_COOKIE, PREFIX
from gateway.connector import Connector
from gateway.policy import check_request


class GatewayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.calls = []
        self.release_stream = asyncio.Event()
        mock = web.Application(client_max_size=16 * 1024 ** 2)
        mock.router.add_route('*', '/{path:.*}', self.upstream)
        self.mock = TestServer(mock); await self.mock.start_server()
        self.settings = Settings({}, {}, 'T' * 64, 'client', 'secret', '123', testing=True)
        self.app = create_app(self.settings)
        self.server = TestServer(self.app); await self.server.start_server()
        self.public = str(self.server.make_url('')).rstrip('/')
        self.settings.origins[self.public] = 'comfy'
        self.sid = self.app['security'].issue(self.public)
        self.client = ClientSession(cookie_jar=DummyCookieJar())
        config = {'targets': {x: str(self.mock.make_url('')).rstrip('/') for x in APP_IDS},
            'endpoints': [{'origin': self.public, 'token': 'T' * 64,
                           'origins': self.settings.origins}]}
        self.bridge = Connector(config, testing=True)
        self.runner = asyncio.create_task(self.bridge.run())
        for _ in range(100):
            if self.app['relay'].control is not None:
                break
            await asyncio.sleep(.01)
        self.assertIsNotNone(self.app['relay'].control)

    async def asyncTearDown(self):
        self.runner.cancel()
        await asyncio.gather(self.runner, return_exceptions=True)
        await self.client.close()
        await self.server.close()
        await self.mock.close()

    def headers(self, **extra):
        return {'Cookie': COOKIE + '=' + self.sid, 'Origin': self.public, **extra}

    async def request(self, method, path, **kwargs):
        kwargs.setdefault('headers', self.headers())
        kwargs.setdefault('allow_redirects', False)
        return await self.client.request(method, self.public + path, **kwargs)

    async def upstream(self, request):
        self.calls.append(request.path)
        if request.headers.get('Upgrade', '').lower() == 'websocket':
            socket = web.WebSocketResponse(protocols=['test'])
            await socket.prepare(request)
            async for message in socket:
                if message.type == WSMsgType.TEXT:
                    await socket.send_str(message.data)
                elif message.type == WSMsgType.BINARY:
                    await socket.send_bytes(message.data)
            return socket
        body = await request.read()
        if request.path == '/sse':
            response = web.StreamResponse(headers={'Content-Type': 'text/event-stream'})
            await response.prepare(request)
            await response.write(b'data: first\n\n')
            await self.release_stream.wait()
            await response.write(b'data: second\n\n')
            await response.write_eof()
            return response
        if request.path == '/range':
            self.assertEqual(request.headers.get('Range'), 'bytes=2-5')
            return web.Response(status=206, body=b'2345', headers={'Content-Range': 'bytes 2-5/10'})
        if request.path == '/partial':
            response = web.StreamResponse()
            await response.prepare(request)
            await response.write(b'incomplete')
            request.transport.close()
            return response
        if request.path == '/echo':
            return web.Response(body=body, content_type='application/octet-stream')
        if request.path == '/redirect':
            raise web.HTTPFound(str(self.mock.make_url('/destination')))
        if request.path == '/cookies':
            response = web.Response(text='cookies')
            response.set_cookie(COOKIE, 'evil')
            response.set_cookie('app_session', 'preserved', domain='localhost')
            return response
        return web.json_response({'path': request.raw_path, 'method': request.method,
                                  'headers': dict(request.headers), 'body': body.decode()})

    async def test_every_app_http_and_native_routes(self):
        for app_id in sorted(APP_IDS):
            self.settings.origins[self.public] = app_id
            path = '/api/status' if app_id == 'dashboard' else '/native/deep/path?x=1'
            async with await self.request('GET', path) as response:
                self.assertEqual(response.status, 200, await response.text())
                self.assertEqual((await response.json())['path'], path)

    async def test_stream_upload_download_and_headers(self):
        payload = b'0123456789abcdef' * 180000
        async with await self.request('POST', '/echo', data=payload) as response:
            self.assertEqual(response.status, 200, await response.text() if response.status != 200 else '')
            self.assertEqual(await response.read(), payload)
        async with await self.request('GET', '/inspect', headers=self.headers(
                Cookie=COOKIE + '=' + self.sid + '; app_session=abc',
                Authorization='Bearer app-secret', **{'X-Forwarded-Host': 'attacker'})) as response:
            headers = (await response.json())['headers']
            self.assertEqual(headers['Cookie'], 'app_session=abc')
            self.assertEqual(headers['Authorization'], 'Bearer app-secret')
            self.assertEqual(headers['X-Forwarded-Host'], urlsplit(self.public).netloc)

    async def test_sse_is_incremental_and_range_is_preserved(self):
        async with await self.request('GET', '/sse') as response:
            line = await asyncio.wait_for(response.content.readline(), 2)
            self.assertEqual(line, b'data: first\n')
            self.release_stream.set()
            self.assertIn(b'data: second', await response.read())
        async with await self.request('GET', '/range', headers=self.headers(Range='bytes=2-5')) as response:
            self.assertEqual(response.status, 206)
            self.assertEqual(response.headers['Content-Range'], 'bytes 2-5/10')
            self.assertEqual(await response.read(), b'2345')

    async def test_truncated_response_is_not_a_successful_download(self):
        import aiohttp
        with self.assertRaises((aiohttp.ClientPayloadError, aiohttp.ServerDisconnectedError)):
            async with await self.request('GET', '/partial') as response:
                await response.read()

    async def test_unauthorized_and_forged_origin_never_reach_local(self):
        for headers in ({}, {'Cookie': COOKIE + '=invalid'},
                        self.headers(Origin='https://evil.example')):
            async with await self.request('POST', '/echo', headers=headers, data=b'bad') as response:
                self.assertIn(response.status, {401, 403})
        self.assertEqual(self.calls, [])

    async def begin_login(self):
        async with await self.request('GET', PREFIX + '/login', headers={}) as response:
            self.assertEqual(response.status, 302)
            params = parse_qs(urlsplit(response.headers['Location']).query)
            self.assertEqual(params['code_challenge_method'], ['S256'])
            self.assertNotIn('client_secret', params)
            cookie = response.cookies[STATE_COOKIE].value
            self.assertTrue(response.cookies[STATE_COOKIE]['httponly'])
            return params['state'][0], cookie

    async def test_oauth_browser_binding_owner_mfa_and_single_use(self):
        for user, expected in [({'id': 999, 'two_factor_authentication': True}, 403),
                               ({'id': 123, 'two_factor_authentication': False}, 403),
                               ({'id': 123, 'two_factor_authentication': True}, 302)]:
            state, binding = await self.begin_login()
            async def fake_user(code, record, result=user):
                return result
            self.app['oauth'].github_user = fake_user
            url = PREFIX + '/callback?code=fake&state=' + state
            headers = {'Cookie': STATE_COOKIE + '=' + binding}
            async with await self.request('GET', url, headers=headers) as response:
                self.assertEqual(response.status, expected)
                if expected == 302:
                    cookie = response.cookies[COOKIE]
                    self.assertTrue(cookie['httponly'])
                    self.assertEqual(cookie['samesite'], 'Lax')
            async with await self.request('GET', url, headers=headers) as response:
                self.assertEqual(response.status, 403)
        state, _ = await self.begin_login()
        async with await self.request('GET', PREFIX + '/callback?code=fake&state=' + state,
                                      headers={'Cookie': STATE_COOKIE + '=wrong-browser'}) as response:
            self.assertEqual(response.status, 403)

    async def test_host_scope_and_traversal(self):
        async with await self.request('GET', '/inspect', headers=self.headers(Host='evil.example')) as response:
            self.assertEqual(response.status, 421)
        for path in ('//evil.example', '/%2e%2e/secret', '/%252e%252e/secret', '/foo\\bar'):
            with self.assertRaises(ValueError):
                check_request('comfy', 'GET', path)
        other = 'https://another-app.example'
        self.assertFalse(self.app['security'].valid(self.sid, other))

    async def test_local_only_and_unknown_dashboard_routes_rejected(self):
        self.settings.origins[self.public] = 'dashboard'
        for path in ('/api/terminal', '/api/remote-desktop', '/api/host/shutdown',
                     '/api/openclaw/dashboard', '/api/arbitrary-command'):
            async with await self.request('POST', path, json={}) as response:
                self.assertEqual(response.status, 403)
        self.assertEqual(self.calls, [])
        for path in ('/api/terminal', '/go/openclaw', '/api/arbitrary-command'):
            with self.assertRaises(PermissionError):
                check_request('dashboard', 'POST', path)

    async def test_redirects_and_cookie_isolation(self):
        async with await self.request('GET', '/redirect') as response:
            self.assertEqual(response.headers['Location'], self.public + '/destination')
        async with await self.request('GET', '/cookies') as response:
            cookies = response.headers.getall('Set-Cookie')
            self.assertEqual(len(cookies), 1)
            self.assertIn('app_session=preserved', cookies[0])
            self.assertNotIn('Domain=', cookies[0])

    async def test_websocket_binary_text_and_logout(self):
        socket = await self.client.ws_connect(self.public + '/ws', headers=self.headers(), protocols=['test'])
        self.assertEqual(socket.protocol, 'test')
        await socket.send_str('hello')
        self.assertEqual((await asyncio.wait_for(socket.receive(), 3)).data, 'hello')
        await socket.send_bytes(b'\x00\xffpreview')
        self.assertEqual((await asyncio.wait_for(socket.receive(), 3)).data, b'\x00\xffpreview')
        async with await self.request('POST', PREFIX + '/logout') as response:
            self.assertEqual(response.status, 200)
        self.assertIn((await asyncio.wait_for(socket.receive(), 3)).type,
                      {WSMsgType.CLOSE, WSMsgType.CLOSED})
        await socket.close()
        async with await self.request('GET', '/inspect') as response:
            self.assertEqual(response.status, 401)

    async def test_all_seven_native_apps_support_websocket_traffic(self):
        for app_id in sorted(APP_IDS - {'dashboard'}):
            self.settings.origins[self.public] = app_id
            socket = await self.client.ws_connect(self.public + '/ws', headers=self.headers())
            await socket.send_str(app_id)
            self.assertEqual((await asyncio.wait_for(socket.receive(), 2)).data, app_id)
            await socket.close()

    async def test_health_is_minimal_and_stream_limit_is_enforced(self):
        async with await self.request('GET', PREFIX + '/health', headers={'Host': 'internal-probe'}) as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(await response.json(), {'ok': True})
        self.settings.max_streams = 1
        socket = await self.client.ws_connect(self.public + '/ws', headers=self.headers())
        async with await self.request('GET', '/inspect') as response:
            self.assertEqual(response.status, 429)
        await socket.close()

    async def test_login_cannot_redirect_to_another_website(self):
        async with await self.request('GET', PREFIX + '/login?next=//evil.example', headers={}) as response:
            self.assertEqual(response.status, 400)

    async def test_websocket_rejects_missing_session_and_wrong_origin(self):
        for headers in ({}, self.headers(Origin='https://evil.example')):
            with self.assertRaises(WSServerHandshakeError) as error:
                await self.client.ws_connect(self.public + '/ws', headers=headers)
            self.assertIn(error.exception.status, {401, 403})
        self.assertEqual(self.calls, [])

    async def test_expired_session_closes_existing_socket(self):
        socket = await self.client.ws_connect(self.public + '/ws', headers=self.headers())
        self.app['security'].sessions[self.sid]['expires'] = time.time() - 1
        self.assertIn((await asyncio.wait_for(socket.receive(), 3)).type,
                      {WSMsgType.CLOSE, WSMsgType.CLOSED})
        await socket.close()

    async def test_machine_endpoints_reject_browser_credentials(self):
        for path in ('/connector', '/stream/unrequested'):
            with self.assertRaises(WSServerHandshakeError) as error:
                await self.client.ws_connect(self.public + PREFIX + path, headers=self.headers())
            self.assertEqual(error.exception.status, 401)
        with self.assertRaises(WSServerHandshakeError) as error:
            await self.client.ws_connect(self.public + PREFIX + '/stream/unrequested',
                                          headers={'Authorization': 'Bearer ' + 'T' * 64})
        self.assertEqual(error.exception.status, 404)

    async def test_offline_never_queues_or_replays_controls(self):
        self.runner.cancel(); await asyncio.gather(self.runner, return_exceptions=True)
        await asyncio.sleep(.05)
        self.settings.origins[self.public] = 'dashboard'
        async with await self.request('POST', '/api/action', json={'service': 'comfy', 'action': 'stop'}) as response:
            self.assertEqual(response.status, 503)
        self.runner = asyncio.create_task(self.bridge.run())
        await asyncio.sleep(.15)
        self.assertEqual(self.calls, [])

    async def test_connector_rejects_invalid_control_payload(self):
        self.settings.origins[self.public] = 'dashboard'
        async with await self.request('POST', '/api/action',
                json={'service': 'comfy;evil', 'action': 'restart'}) as response:
            self.assertEqual(response.status, 502)
        self.assertEqual(self.calls, [])
