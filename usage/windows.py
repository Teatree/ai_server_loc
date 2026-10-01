"""Local read-only companion: static page plus bounded SSH history queries."""
import json
import os
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, parse_qs
from .query import options

ROOT = Path(__file__).resolve().parent.parent
PORT = 32149

def server(config_path):
    config = json.loads(Path(config_path).read_text(encoding='utf-8-sig'))
    ssh = config['ssh']
    command = ['ssh','-i',os.path.expandvars(ssh['key']),'-o','BatchMode=yes',
               '-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=5',ssh['target'],
               'cd ~/.local/share/ai-usage-collector && python3 -m usage.query']
    lock, cache = threading.Lock(), {}
    origins = {f'http://127.0.0.1:{PORT}',f'http://localhost:{PORT}'}
    origins.update(public for ep in config['endpoints'] for public,app in ep['origins'].items() if app=='dashboard')
    def history(params):
        options(params)
        key = json.dumps(params,sort_keys=True)
        with lock:
            if key in cache and time.monotonic()-cache[key][0]<5:
                return cache[key][1]
            result = subprocess.run(command,input=json.dumps(params),capture_output=True,
                text=True,encoding='utf-8',timeout=25,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
            if result.returncode or len(result.stdout)>20_000_000:
                raise ConnectionError('History could not be read over SSH. The collector may still be recording.')
            body = result.stdout.encode('utf-8')
            if not json.loads(body).get('ok'):
                raise ConnectionError('History query failed')
            cache.clear() if len(cache)>12 else None
            cache[key] = (time.monotonic(),body)
            return body
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args):
            pass

        def reply(self,body,content_type='application/json',status=200):
            self.send_response(status)
            self.send_header('Content-Type',content_type)
            self.send_header('Content-Length',str(len(body)))
            self.send_header('Cache-Control','no-store')
            self.send_header('X-Content-Type-Options','nosniff')
            self.send_header('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if (self.headers.get('Host') not in {f'127.0.0.1:{PORT}',f'localhost:{PORT}'} or
                    self.headers.get('Origin',next(iter(origins))) not in origins or
                    self.headers.get('Sec-Fetch-Site')=='cross-site' and self.headers.get('Sec-Fetch-Mode')!='navigate'):
                return self.reply(b'{"error":"Origin rejected"}',status=403)
            parsed = urlsplit(self.path)
            if parsed.path=='/api/health':
                return self.reply(b'{"ok":true,"service":"usage-metrics"}')
            if parsed.path=='/api/usage':
                try:
                    params = parse_qs(parsed.query,keep_blank_values=True,max_num_fields=3)
                    if any(len(v)!=1 for v in params.values()):
                        raise ValueError('Duplicate query parameter')
                    body = history({k:v[0] for k,v in params.items()})
                    return self.reply(body)
                except ValueError as error:
                    return self.reply(json.dumps({'ok':False,'error':str(error)}).encode(),status=400)
                except Exception:
                    return self.reply(b'{"ok":false,"error":"Cannot read history from the AI server. Check SSH and the collector."}',status=503)
            files = {'/usage.html':'text/html; charset=utf-8','/usage.css':'text/css',
                     '/usage.js':'text/javascript','/usage-charts.js':'text/javascript'}
            route = '/usage.html' if parsed.path=='/' else parsed.path
            if route not in files:
                return self.reply(b'{"error":"Not found"}',status=404)
            self.reply((ROOT/'web'/route[1:]).read_bytes(),files[route])
    return ThreadingHTTPServer(('127.0.0.1',PORT),Handler)
