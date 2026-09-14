import asyncio
import json
from aiohttp import web, WSMsgType
from multidict import CIMultiDict
from .headers import clean_response

MAX_UPLOAD = 8 * 1024 ** 3


async def send_body(request, tunnel):
    total = 0
    async for chunk in request.content.iter_chunked(65536):
        total += len(chunk)
        if total > MAX_UPLOAD:
            raise web.HTTPRequestEntityTooLarge(max_size=MAX_UPLOAD, actual_size=total)
        await tunnel.send_bytes(chunk)
    await tunnel.send_json({'kind': 'end'})


async def first_message(tunnel):
    message = await asyncio.wait_for(tunnel.receive(), 3600)
    if message.type != WSMsgType.TEXT:
        raise web.HTTPBadGateway(text='Local app disconnected before responding')
    record = json.loads(message.data)
    if record.get('kind') == 'error':
        raise web.HTTPBadGateway(text=record.get('message', 'Local app unavailable'))
    return record


async def http_proxy(request, tunnel):
    if request.content_length and request.content_length > MAX_UPLOAD:
        raise web.HTTPRequestEntityTooLarge(max_size=MAX_UPLOAD, actual_size=request.content_length)
    upload = asyncio.create_task(send_body(request, tunnel))
    first = asyncio.create_task(first_message(tunnel))
    response = None
    try:
        done, _ = await asyncio.wait({upload, first}, return_when=asyncio.FIRST_COMPLETED)
        if upload in done:
            await upload
        header = await first
        if header.get('kind') != 'response':
            raise web.HTTPBadGateway(text='Invalid local response')
        headers = clean_response(header['headers'], '__unused__', request['public'])
        response = web.StreamResponse(status=int(header['status']), headers=CIMultiDict(headers))
        await response.prepare(request)
        async for message in tunnel:
            if message.type == WSMsgType.BINARY:
                await response.write(message.data)
            elif message.type == WSMsgType.TEXT:
                if json.loads(message.data).get('kind') == 'end':
                    await response.write_eof()
                    return response
                break
        raise ConnectionError('Transfer interrupted')
    except BaseException:
        if response is not None and response.prepared:
            response.force_close()
            if request.transport:
                request.transport.close()
        raise
    finally:
        for task in (upload, first):
            task.cancel()
        await asyncio.gather(upload, first, return_exceptions=True)


async def websocket_proxy(request, tunnel, stream):
    hello = await first_message(tunnel)
    if hello.get('kind') != 'websocket':
        raise web.HTTPBadGateway(text='App WebSocket handshake failed')
    protocol = hello.get('protocol')
    browser = web.WebSocketResponse(protocols=[protocol] if protocol else [],
                                    heartbeat=30, max_msg_size=8 * 1024 * 1024)
    await browser.prepare(request)
    stream.browser = browser

    async def outbound():
        async for message in browser:
            if message.type == WSMsgType.TEXT:
                await tunnel.send_json({'kind': 'text', 'data': message.data})
            elif message.type == WSMsgType.BINARY:
                await tunnel.send_bytes(message.data)
        await tunnel.send_json({'kind': 'close'})

    async def inbound():
        async for message in tunnel:
            if message.type == WSMsgType.BINARY:
                await browser.send_bytes(message.data)
            elif message.type == WSMsgType.TEXT:
                record = json.loads(message.data)
                if record.get('kind') == 'text':
                    await browser.send_str(record['data'])
                elif record.get('kind') == 'close':
                    await browser.close(code=record.get('code', 1000))
                    return
                else:
                    return
    tasks = [asyncio.create_task(outbound()), asyncio.create_task(inbound())]
    try:
        done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in done:
            task.result()
    finally:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        await browser.close()
    return browser
