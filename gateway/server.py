import asyncio
import logging
import os
from pathlib import Path
from aiohttp import web, ClientSession, ClientTimeout, DummyCookieJar
from .settings import Settings, PREFIX
from .security import Security, secure_headers
from .oauth import OAuth
from .relay import Relay
from .policy import check_request, LOCAL_ONLY

WEB_ROOT = Path(__file__).resolve().parent.parent / 'web'


@web.middleware
async def errors(request, handler):
    try:
        return await handler(request)
    except PermissionError as exc:
        return web.json_response({'ok': False, 'error': str(exc)}, status=403)
    except ValueError:
        return web.json_response({'ok': False, 'error': 'Invalid request'}, status=400)
    except web.HTTPException:
        raise
    except Exception:
        logging.warning('Request failed; private details omitted')
        return web.json_response({'ok': False, 'error': 'Connection failed; action not retried'}, status=502)


async def health(request):
    return web.json_response({'ok': True})


async def info(request):
    settings = request.app['settings']
    return web.json_response({'app': request['app_id'], 'remote': True,
        'connected': bool(request.app['relay'].control), 'apps': settings.links,
        'expires': request.app['security'].sessions[request['sid']]['expires']})


async def account(request):
    return web.Response(content_type='text/html', text='''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Private AI access</title><h1>Private AI access</h1>
<p>Your session lasts up to eight hours. Sign-out applies to this app address.</p>
<form method="post" action="/_gateway/logout"><button>Sign out</button></form>
<p><a href="/">Return to app</a></p></html>''')


async def route(request):
    if request['app_id'] == 'dashboard':
        path = request.path
        if path.startswith('/go/') and request.method == 'GET':
            name = path.rsplit('/', 1)[-1]
            name = 'openwebui' if name == 'openwebui-models' else name
            destination = request.app['settings'].links.get(name)
            if not destination:
                raise web.HTTPServiceUnavailable(text='Configure this app address in APP_LINKS')
            suffix = '/api/tags' if name == 'ollama' else '/'
            if path.endswith('openwebui-models'):
                suffix = '/admin/settings/connections'
            raise web.HTTPFound(destination + suffix)
        if path in LOCAL_ONLY:
            raise PermissionError('This action must be accessed locally.')
        if not path.startswith('/api/'):
            filename = 'index.html' if path == '/' else path.lstrip('/')
            allowed = {'index.html', 'app.js', 'styles.css', 'remote.js',
                       'commands.html', 'commands.js'}
            allowed |= {'assets/' + p.name for p in (WEB_ROOT / 'assets').glob('*') if p.is_file()}
            if filename in allowed and request.method in {'GET', 'HEAD'}:
                return web.FileResponse(WEB_ROOT / filename)
            raise web.HTTPNotFound()
    check_request(request['app_id'], request.method, request.raw_path)
    return await request.app['relay'].proxy(request)


def create_app(settings: Settings) -> web.Application:
    security = Security(settings)
    app = web.Application(middlewares=[errors, security.middleware], client_max_size=131072,
                          handler_args={'auto_decompress': False})
    app['settings'], app['security'] = settings, security
    app['relay'] = Relay(security)
    app.on_response_prepare.append(secure_headers)

    async def resources(app):
        async with ClientSession(timeout=ClientTimeout(total=20), cookie_jar=DummyCookieJar()) as client:
            app['oauth'] = OAuth(security, client)
            expiry = asyncio.create_task(app['relay'].expire())
            yield
            expiry.cancel()
            await asyncio.gather(expiry, return_exceptions=True)
            await app['relay'].close_all()
            if app['relay'].control:
                await app['relay'].control.close(code=1001)
    app.cleanup_ctx.append(resources)
    install_routes(app)
    return app


def install_routes(app):
    async def login(request):
        return await request.app['oauth'].login(request)

    async def callback(request):
        return await request.app['oauth'].callback(request)

    async def logout(request):
        return await request.app['oauth'].logout(request)

    app.router.add_get(PREFIX + '/health', health)
    app.router.add_get(PREFIX + '/login', login)
    app.router.add_get(PREFIX + '/callback', callback)
    app.router.add_post(PREFIX + '/logout', logout)
    app.router.add_get(PREFIX, account)
    app.router.add_get(PREFIX + '/info', info)
    app.router.add_get(PREFIX + '/connector', app['relay'].connector)
    app.router.add_get(PREFIX + '/stream/{stream_id}', app['relay'].attach)
    app.router.add_route('*', '/{path:.*}', route)


def main():
    logging.basicConfig(level=logging.WARNING)
    # No access log: OAuth codes, prompts, and app tokens must not enter logs.
    web.run_app(create_app(Settings.from_env()), host='0.0.0.0',
                port=int(os.environ.get('PORT', '10000')), access_log=None,
                print=None, shutdown_timeout=10)


if __name__ == '__main__':
    main()
