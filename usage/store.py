"""Versioned, compressed time buckets. Only the collector opens a writable DB."""
import json
import sqlite3
import zlib
from pathlib import Path

def pack(value):
    return zlib.compress(json.dumps(value, separators=(',', ':'), allow_nan=False).encode())

def unpack(value):
    return json.loads(zlib.decompress(value))

def merge(target, values, seconds):
    for key, metric in values.items():
        value = metric.get('value')
        if value is None:
            continue
        item = target.setdefault(key, {'sum': 0, 'seconds': 0, 'peak': 0, 'apps': {}})
        item['sum'] += value * seconds
        item['seconds'] += seconds
        item['peak'] = max(item['peak'], value)
        for app, amount in metric.get('apps', {}).items():
            item['apps'][app] = item['apps'].get(app, 0) + amount * seconds

class Store:
    def __init__(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.db = sqlite3.connect(path, timeout=10)
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        version = self.db.execute('PRAGMA user_version').fetchone()[0]
        if version > 1:
            raise RuntimeError('History schema is newer than this collector; refusing to alter it')
        self.db.executescript('''
          CREATE TABLE IF NOT EXISTS buckets (
            resolution INTEGER, time INTEGER, data BLOB NOT NULL,
            PRIMARY KEY(resolution,time)) WITHOUT ROWID;
          CREATE TABLE IF NOT EXISTS catalog (id TEXT PRIMARY KEY, data TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS metadata (id TEXT PRIMARY KEY, value TEXT NOT NULL);
          PRAGMA user_version=1;
        ''')

    def record(self, end, duration, metrics, catalog, health):
        # Split each sample at minute/hour/day boundaries; never fill downtime.
        start = end - duration
        previous = self.db.execute("SELECT value FROM metadata WHERE id='last_sample'").fetchone()
        if previous:
            start = max(start, float(json.loads(previous[0])))
        if start >= end:
            return
        with self.db:
            for size in (60, 3600, 86400):
                cursor = start
                while cursor < end:
                    bucket = int(cursor // size) * size
                    seconds = min(end, bucket + size) - cursor
                    row = self.db.execute('SELECT data FROM buckets WHERE resolution=? AND time=?',
                                          (size, bucket)).fetchone()
                    data = unpack(row[0]) if row else {}
                    merge(data, metrics, seconds)
                    self.db.execute('INSERT OR REPLACE INTO buckets VALUES (?,?,?)',
                                    (size, bucket, pack(data)))
                    cursor += seconds
            for item in catalog:
                self.db.execute('INSERT OR REPLACE INTO catalog VALUES (?,?)',
                                (item['id'], json.dumps(item)))
            for key, value in {'last_sample': end, 'health': health}.items():
                self.db.execute('INSERT OR REPLACE INTO metadata VALUES (?,?)', (key, json.dumps(value)))
            self.db.execute('INSERT OR IGNORE INTO metadata VALUES (?,?)', ('first_sample', json.dumps(start)))

    def close(self):
        self.db.close()
