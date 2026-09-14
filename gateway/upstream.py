import asyncio
import json
from aiohttp import WSMsgType, ClientTimeout
from multidict import CIMultiDict
from yarl import URL
from .headers import clean_request, clean_response
from .policy import check_request, SERVICES, DOWNLOADS
from .transfer import MAX_UPLOAD


async def request_body(tunnel):
    total = 0
    async for message in tunnel:
        if message.type == WSMsgType.BINARY:
            total += len(message.data)
            if total > MAX_UPLOAD:
                raise ValueError('Upload exceeds 8 GiB limit')
            yield message.data
        elif message.type == WSMsgType.TEXT:
            if json.loads(message.data).get('kind') == 'end':
                return
            raise ValueError('Invalid upload frame')
    raise ConnectionError('Upload interrupted')


async def dashboard_body(body, path):
    data = bytearray()
    async for chunk in body:
        data.extend(chunk)
        if len(data) > 131072:
            raise ValueError('Dashboard request too large')
    record = json.loads(data or b'{}')
    if not isinstance(record, dict):
        raise ValueError('Expected a JSON object')
    if path == '/api/action':
        if record.get('service') not in SERVICES or record.get('action') not in {'start', 'stop', 'restart'}:
            raise ValueError('Unsupported service action')
    if path.startswith('/api/model-download') and record.get('target') not in DOWNLOADS:
        raise ValueError('Unsupported model target')
    return bytes(data)


async def proxy_http(client, tunnel, metadata, base):
    check_request(metadata['app'], metadata['method'], metadata['path'])
    body = request_body(tunnel)
    if metadata['app'] == 'dashboard' and metadata['method'] == 'POST':
        body = await dashboard_body(body, metadata['path'].split('?', 1)[0])
    headers = CIMultiDict(clean_request(metadata['headers'], metadata['public']))
    async with client.request(metadata['method'], URL(base + metadata['path'], encoded=True),
            headers=headers, data=body, allow_redirects=False,
            timeout=ClientTimeout(total=None, sock_connect=10, sock_read=None)) as response:
        pairs = [[k.decode('latin1'), v.decode('latin1')] for k, v in response.raw_headers]
        await tunnel.send_json({'kind': 'response', 'status': response.status,
            'headers': clean_response(pairs, base, metadata['public'])})
        async for chunk in response.content.iter_chunked(65536):
            await tunnel.send_bytes(chunk)
        await tunnel.send_json({'kind': 'end'})


async def proxy_websocket(client, tunnel, metadata, base):
    check_request(metadata['app'], 'GET', metadata['path'])
    if metadata['app'] == 'dashboard':
        raise PermissionError('Dashboard WebSockets are not exposed')
    headers = CIMultiDict(clean_request(metadata['headers'], metadata['public']))
    protocols = [x.strip() for x in metadata.get('protocols', []) if x.strip()]
    async with client.ws_connect(URL(base + metadata['path'], encoded=True),
            headers=headers, protocols=protocols, heartbeat=30,
            max_msg_size=8 * 1024 * 1024) as upstream:
        await tunnel.send_json({'kind': 'websocket', 'protocol': upstream.protocol})

        async def to_app():
            async for message in tunnel:
                if message.type == WSMsgType.BINARY:
                    await upstream.send_bytes(message.data)
                elif message.type == WSMsgType.TEXT:
                    record = json.loads(message.data)
                    if record.get('kind') == 'text':
                        await upstream.send_str(record['data'])
                    elif record.get('kind') == 'close':
                        return
                    else:
                        raise ValueError('Invalid WebSocket frame')

        async def from_app():
            async for message in upstream:
                if message.type == WSMsgType.BINARY:
                    await tunnel.send_bytes(message.data)
                elif message.type == WSMsgType.TEXT:
                    await tunnel.send_json({'kind': 'text', 'data': message.data})
            await tunnel.send_json({'kind': 'close', 'code': upstream.close_code or 1000})

        tasks = [asyncio.create_task(to_app()), asyncio.create_task(from_app())]
        try:
            done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                task.result()
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
