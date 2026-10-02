"""Independent model-control bridge; leaves running app connections untouched."""
import asyncio
import json
import logging
import threading
from pathlib import Path
from .connector import Connector
from model_control.windows import server, PORT

def main():
    path = Path(__file__).resolve().parent.parent/'private/connector.json'
    local = server(path)
    threading.Thread(target=local.serve_forever,daemon=True).start()
    config = json.loads(path.read_text(encoding='utf-8-sig'))
    endpoints = []
    for ep in config['endpoints']:
        mapping = {url:app for url,app in ep['origins'].items() if app=='dashboard'}
        if mapping:
            endpoints.append({**ep,'origins':mapping})
    config = {'targets':{'dashboard':f'http://127.0.0.1:{PORT}'},'endpoints':endpoints}
    logging.basicConfig(level=logging.INFO,format='%(asctime)s %(levelname)s %(message)s')
    try:
        asyncio.run(Connector(config,channel='models-').run())
    finally:
        local.shutdown()

if __name__=='__main__':
    main()
