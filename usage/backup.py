"""Daily online SQLite snapshots; never copy a live database file directly."""
import os
import shutil
import sqlite3
import time
from pathlib import Path

def snapshot(path):
    path = Path(path)
    folder = path.parent/'backups'
    folder.mkdir(mode=0o700,exist_ok=True)
    latest = folder/'history-latest.sqlite3'
    previous = folder/'history-previous.sqlite3'
    temporary = folder/'history-pending.sqlite3'
    if latest.exists() and time.time()-latest.stat().st_mtime<86400:
        return latest.stat().st_mtime
    required = path.stat().st_size*2 + 64*1024**2
    if shutil.disk_usage(folder).free<required:
        raise OSError('Insufficient free space for backup')
    source = sqlite3.connect(path.resolve().as_uri()+'?mode=ro',uri=True)
    destination = sqlite3.connect(temporary)
    try:
        source.backup(destination,pages=64,sleep=.01)
        if destination.execute('PRAGMA quick_check').fetchone()[0]!='ok':
            raise OSError('Backup integrity check failed')
    finally:
        destination.close()
        source.close()
    if latest.exists():
        os.replace(latest,previous)
    os.replace(temporary,latest)
    return latest.stat().st_mtime
