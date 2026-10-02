"""Loopback companion with strict browser origins and serialized SSH requests."""
import json
import os
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from .query import validate

PORT = 32150

def server(config_path, port=PORT, execute=None):
    config = json.loads(Path(config_path).read_text(encoding='utf-8-sig'))
    ssh = config['ssh']
    command = ['ssh','-i',os.path.expandvars(ssh['key']),'-o','BatchMode=yes',
        '-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=5',ssh['target'],
        'cd ~/.local/share/ai-model-control && python3 -m model_control.query']
    origins = {'http://127.0.0.1:32146','http://localhost:32146'}
    origins.update(url for ep in config['endpoints'] for url,app in ep['origins'].items() if app=='dashboard')
    lock, cache = threading.Lock(), {}
    def run(payload):
        result = subprocess.run(command,input=json.dumps(payload),capture_output=True,
            text=True,encoding='utf-8',timeout=65,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        if result.returncode or len(result.stdout)>2_000_000:
            raise ConnectionError('SSH model query failed')
        return json.loads(result.stdout)
    execute = execute or run
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args):
            pass

        def allowed(self, mutation=False):
            actual_port = self.server.server_port
            return (self.headers.get('Host') in {f'127.0.0.1:{actual_port}',f'localhost:{actual_port}'}
                and self.headers.get('Origin') in (origins if mutation else origins|{None})
                and (self.headers.get('Sec-Fetch-Site')!='cross-site' or self.headers.get('Origin') in origins))

        def reply(self, value, status=200):
            body = json.dumps(value).encode()
            self.send_response(status)
            self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(body)))
            self.send_header('Cache-Control','no-store')
            self.send_header('X-Content-Type-Options','nosniff')
            if self.headers.get('Origin') in origins:
                self.send_header('Access-Control-Allow-Origin',self.headers['Origin'])
                self.send_header('Vary','Origin')
                self.send_header('Access-Control-Allow-Methods','GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers','Content-Type')
            self.end_headers()
            self.wfile.write(body)

        def do_OPTIONS(self):
            self.reply({'ok':self.allowed(True)},200 if self.allowed(True) else 403)

        def do_GET(self):
            if not self.allowed():
                return self.reply({'ok':False,'error':'Origin rejected'},403)
            if self.path=='/api/health':
                return self.reply({'ok':True,'service':'model-control'})
            if self.path!='/api/models':
                return self.reply({'ok':False,'error':'Not found'},404)
            try:
                with lock:
                    if time.monotonic()-cache.get('time',0)>8:
                        cache['value'] = execute({'action':'list'})
                        cache['time'] = time.monotonic()
                    value = cache['value']
                self.reply(value)
            except Exception:
                self.reply({'ok':False,'error':'Cannot read model status. Check the model companion and SSH connection.'},503)

        def do_POST(self):
            if not self.allowed(True):
                return self.reply({'ok':False,'error':'Origin rejected'},403)
            if self.path!='/api/models/unload':
                return self.reply({'ok':False,'error':'Not found'},404)
            try:
                size = int(self.headers.get('Content-Length','0'))
                if (not 0<size<=131072 or self.headers.get('Transfer-Encoding') or
                        self.headers.get('Content-Type','').split(';')[0]!='application/json'):
                    raise ValueError('Expected a bounded JSON request')
                request = validate(json.loads(self.rfile.read(size)))
                if request['action']!='unload':
                    raise ValueError('Expected unload action')
                # Never replay a mutation after failure or reconnect.
                with lock:
                    cache.clear()
                    value = execute(request)
                self.reply(value,200 if value.get('ok') else 409)
            except ValueError as error:
                self.reply({'ok':False,'error':str(error)},400)
            except Exception:
                self.reply({'ok':False,'error':'Request failed or timed out. Its outcome may be unknown. Refresh before retrying.'},503)
    return ThreadingHTTPServer(('127.0.0.1',port),Handler)
