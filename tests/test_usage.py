import tempfile
import unittest
from pathlib import Path
from usage.store import Store
from usage.query import query, options
from usage.processes import partition, discovered_app
from usage.sensors import Sensors
from usage.backup import snapshot
from unittest.mock import patch
import sqlite3

class UsageHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name)/'history.sqlite3'
        self.store = Store(self.path)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def record(self, end, duration, value=50):
        self.store.record(end,duration,{'cpu':{'value':value,'apps':{'test':value}}},
                          [{'id':'cpu','type':'cpu','label':'CPU'}],{})

    def test_boundary_weighting_downtime_and_clock_regression(self):
        self.record(3605,15,60)  # ten seconds before hour, five after
        self.record(3610,5,20)
        self.record(3600,15,100) # backward clock must not duplicate history
        result = query(self.path,{'start':3540,'end':3780,'step':60})
        self.assertEqual([p['time'] for p in result['points']],[3540,3600])
        first,last = [p['metrics']['cpu'] for p in result['points']]
        self.assertEqual(first['seconds'],10)
        self.assertEqual(last['seconds'],10)
        self.assertEqual(last['value'],40)
        self.assertEqual(last['peak'],60)
        self.assertEqual(last['apps'],{'test':40})

    def test_rollups_clip_range_edges_and_keep_extensions(self):
        self.record(3600,60,10)
        self.record(3660,60,90)
        self.store.record(3720,60,{'future:metric':{'value':7}},[],{})
        r = query(self.path,{'start':3600,'end':3720,'step':86400})
        self.assertEqual(len(r['points']),1)
        self.assertEqual(r['points'][0]['metrics']['cpu']['seconds'],60)
        self.assertEqual(r['points'][0]['metrics']['cpu']['value'],90)
        self.assertEqual(r['points'][0]['metrics']['future:metric']['value'],7)

    def test_ten_year_range_bounded_and_missing_database_not_created(self):
        start,end,step = options({'start':1000000000,'end':1315576000,'step':60})
        self.assertLessEqual((end-start)/step,1200)
        missing=self.path.with_name('missing.sqlite3')
        self.assertEqual(query(missing,{})['points'],[])
        self.assertFalse(missing.exists())

    def test_invalid_queries_and_partition(self):
        for params in ({'start':'nan'},{'end':'inf'},{'path':'/tmp/x'},{'step':1}):
            with self.assertRaises(ValueError): options(params)
        self.assertEqual(partition(60,{'a':80,'b':40}),{'a':40,'b':20,'unattributed':0})
        self.assertEqual(partition(None,{'a':80}),{})

    def test_new_python_projects_are_distinct_without_storing_paths(self):
        first,label=discovered_app('python3','/home/user/new-app')
        second,_=discovered_app('python3','/home/user/another-app')
        self.assertNotEqual(first,second)
        self.assertEqual(label,'new-app (discovered)')
        self.assertNotIn('/home',first)
        self.assertEqual(discovered_app('systemd','/'),('process:systemd','systemd'))

    def test_online_backup_includes_wal_and_is_readable(self):
        self.record(3600,60,25)
        snapshot(self.path)
        backup=self.path.parent/'backups/history-latest.sqlite3'
        self.assertEqual(query(backup,{'start':3540,'end':3600})['points'][0]['metrics']['cpu']['value'],25)
        self.record(3660,60,80)
        self.assertEqual(len(query(backup,{'start':3540,'end':3660})['points']),1)
        self.assertEqual(len(query(self.path,{'start':3540,'end':3660})['points']),2)

    def test_unknown_schema_refused_without_overwriting_history(self):
        self.record(3600,60)
        self.store.db.execute('PRAGMA user_version=2')
        with self.assertRaises(ValueError): query(self.path,{})
        self.assertEqual(self.store.db.execute('SELECT count(*) FROM buckets').fetchone()[0],3)

    def test_allocated_vram_never_claims_execution_from_an_unseen_app(self):
        sensor=Sensors()
        device={'id':'gpu:test','bus':'test','label':'GPU','value':60,'power':100}
        clients={('test','1'):{'owner':'a','compute':True,'engines':{},'vram':300},
                 ('test','2'):{'owner':'b','compute':True,'engines':{},'vram':100}}
        with patch('usage.sensors.cpu_counters',side_effect=[(100,50),(200,100)]), \
             patch('usage.sensors.memory',return_value=(1000,500)), \
             patch('usage.sensors.scan',return_value=({},clients,{'a':'A','b':'B'})), \
             patch.object(sensor,'devices',return_value=[device]):
            self.assertIsNone(sensor.sample(0))
            _,metrics,_,_=sensor.sample(15)
        self.assertEqual(metrics['gpu:test']['apps'],{'unattributed':60})
        self.assertEqual(metrics['measured:gpu:test']['apps'],{'unattributed':60})
        self.assertEqual(metrics['power:gpu:test']['value'],100)

    def test_read_api_removes_old_false_estimates_without_changing_saved_history(self):
        self.store.record(3600,60,{
            'gpu:x':{'value':80,'apps':{'comfy':80}},
            'measured:gpu:x':{'value':80,'apps':{'unattributed':80}}},[],{})
        response=query(self.path,{'start':3540,'end':3600})
        self.assertEqual(response['points'][0]['metrics']['gpu:x']['apps'],{'unattributed':80})
        from usage.store import unpack
        saved=unpack(self.store.db.execute('SELECT data FROM buckets WHERE resolution=60').fetchone()[0])
        self.assertEqual(saved['gpu:x']['apps'],{'comfy':4800})
