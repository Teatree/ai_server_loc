import asyncio
import json
import secrets
import time
from dataclasses import dataclass, field
from aiohttp import web, WSMsgType
from .headers import clean_request
from .settings import PREFIX


@dataclass
class Stream:
    sid: str
    public: str
    future: asyncio.Future
    done: asyncio.Event = field(default_factory=asyncio.Event)
    socket: object = None
    browser: object = None


class Relay:
    def __init__(self, security):
        self.security = security
        self.control = None
        self.streams: dict[str, Stream] = {}

    async def connector(self, request):
        if self.control and not self.control.closed:
            raise web.HTTPConflict(text='A connector is already attached')
        socket = web.WebSocketResponse(heartbeat=30, max_msg_size=4096)
        await socket.prepare(request)
        self.control = socket
        try:
            async for message in socket:
                if message.type == WSMsgType.TEXT and message.data == 'ready':
                    continue
                await socket.close(code=1008, message=b'Unexpected control frame')
        finally:
            if self.control is socket:
                self.control = None
                await self.close_all()
        return socket

    async def close_stream(self, stream):
        stream.done.set()
        if not stream.future.done():
            stream.future.cancel()
        if stream.socket:
            await stream.socket.close(code=1008, message=b'Access ended')
        if stream.browser and not stream.browser.closed:
            await stream.browser.close(code=1008, message=b'Access ended')

    async def close_all(self):
        await asyncio.gather(*(self.close_stream(s) for s in list(self.streams.values())))

    async def revoke(self, sid):
        await asyncio.gather(*(self.close_stream(s) for s in list(self.streams.values())
                               if s.sid == sid))

    async def expire(self):
        while True:
            await asyncio.sleep(1)
            for stream in list(self.streams.values()):
                if not self.security.valid(stream.sid, stream.public):
                    await self.close_stream(stream)

    async def proxy(self, request):
        if not self.control or self.control.closed:
            raise web.HTTPServiceUnavailable(text='Local connector offline. No command was queued.')
        if len(self.streams) >= self.security.settings.max_streams:
            raise web.HTTPTooManyRequests(text='Too many active transfers')
        stream_id = secrets.token_urlsafe(24)
        stream = Stream(request['sid'], request['public'], asyncio.get_running_loop().create_future())
        self.streams[stream_id] = stream
        upgrade = request.headers.get('Upgrade', '').lower() == 'websocket'
        headers = clean_request(request.headers, request['public'])
        metadata = {'id': stream_id, 'app': request['app_id'], 'public': request['public'],
                    'method': request.method, 'path': request.raw_path,
                    'headers': headers, 'upgrade': upgrade,
                    'protocols': request.headers.get('Sec-WebSocket-Protocol', '').split(',')}
        try:
            await self.control.send_json(metadata)
            tunnel = await asyncio.wait_for(asyncio.shield(stream.future), 20)
            from .transfer import http_proxy, websocket_proxy
            if upgrade:
                return await websocket_proxy(request, tunnel, stream)
            return await http_proxy(request, tunnel)
        except asyncio.TimeoutError:
            raise web.HTTPGatewayTimeout(text='Local app did not respond. The action was not retried.')
        except asyncio.CancelledError:
            if request.transport and not request.transport.is_closing():
                raise web.HTTPServiceUnavailable(text='Connection ended. No action was retried.')
            raise
        finally:
            self.streams.pop(stream_id, None)
            await self.close_stream(stream)

    async def attach(self, request):
        stream = self.streams.get(request.match_info['stream_id'])
        if not stream or stream.future.done():
            raise web.HTTPNotFound()
        if not self.security.valid(stream.sid, stream.public):
            raise web.HTTPUnauthorized()
        socket = web.WebSocketResponse(heartbeat=30, max_msg_size=8 * 1024 * 1024)
        await socket.prepare(request)
        stream.socket = socket
        stream.future.set_result(socket)
        await stream.done.wait()
        await socket.close()
        return socket
