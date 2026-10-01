"""Independent Ubuntu user service. No service control or application API calls."""
import fcntl
import json
import os
import shutil
import time
from pathlib import Path
from .sensors import Sensors
from .store import Store
from .backup import snapshot

def main():
    os.umask(0o077)
    root = Path.home()/'.local/share/ai-usage-history'
    root.mkdir(parents=True,exist_ok=True,mode=0o700)
    lock = (root/'collector.lock').open('w')
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    store, sensors = Store(root/'history.sqlite3'), Sensors()
    print('Usage collector started; samples every 15 seconds, no automatic deletion.',flush=True)
    while True:
        started = time.monotonic()
        try:
            registry = json.loads((root/'apps.json').read_text()) if (root/'apps.json').exists() else []
            result = sensors.sample(started,registry)
            if result:
                duration, metrics, catalog, health = result
                health['collection_ms'] = round((time.monotonic()-started)*1000,1)
                health['disk_free_bytes'] = shutil.disk_usage(root).free
                health['database_bytes'] = (root/'history.sqlite3').stat().st_size
                try:
                    health['last_backup'] = snapshot(root/'history.sqlite3')
                except Exception:
                    health['backup_warning'] = 'Daily backup failed; check disk space and collector logs.'
                store.record(time.time(),duration,metrics,catalog,health)
        except Exception as error:
            print('Sampling failed: '+type(error).__name__+'; gap preserved, retrying.',flush=True)
            sensors.previous = None
        time.sleep(max(1,15-(time.monotonic()-started)))

if __name__=='__main__':
    main()
