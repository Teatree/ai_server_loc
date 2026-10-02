import unittest
from usage.probe import merge_snapshot
from usage.sensors import Sensors
from unittest.mock import patch

class GpuProbeTests(unittest.TestCase):
    def sample(self, start=123):
        return {'version':1,'time':100,'clients':[{'pid':42,'start':start,
            'bus':'0000:03:00.0','client':'7','engines':{'drm-engine-compute':1000000000}}]}

    def test_cross_account_join_and_shared_fd_dedup(self):
        data=self.sample();data['clients']*=2
        clients={};rows={42:{'key':(42,123),'owner':'ollama'}}
        self.assertEqual(merge_snapshot(data,rows,clients,105),1)
        self.assertEqual(clients[('0000:03:00.0','7')]['owner'],'ollama')
        self.assertEqual(clients[('0000:03:00.0','7')]['sample_time'],100)

    def test_pid_reuse_and_stale_snapshots_never_attribute_usage(self):
        clients={};rows={42:{'key':(42,999),'owner':'comfy'}}
        self.assertEqual(merge_snapshot(self.sample(),rows,clients,105),0)
        self.assertEqual(clients,{})
        with self.assertRaises(ValueError):merge_snapshot(self.sample(),rows,clients,140)

    def test_invalid_or_capacity_counters_are_not_utilization(self):
        data=self.sample();data['clients'][0]['engines']={
            'drm-engine-capacity-compute':8,'drm-engine-compute':-1,'prompt':'private'}
        clients={};rows={42:{'key':(42,123),'owner':'ollama'}}
        self.assertEqual(merge_snapshot(data,rows,clients,105),0)

    def test_live_counter_delta_attributes_ollama_instead_of_idle_comfy(self):
        snapshots=[]
        for stamp,count in [(100,1000000000),(115,13000000000)]:
            snapshots.append(({}, {
                ('pci','ollama'):{'owner':'ollama','pid':42,'source':'probe',
                    'sample_time':stamp,'engines':{'drm-engine-compute':count},'compute':False,'vram':0},
                ('pci','comfy'):{'owner':'comfy','source':'kfd','engines':{},'compute':True,'vram':9999999}
            }, {'ollama':'Ollama','comfy':'ComfyUI'}))
        sensor=Sensors()
        with patch('usage.sensors.cpu_counters',side_effect=[(100,50),(200,100)]), \
             patch('usage.sensors.memory',return_value=(1000,500)), \
             patch('usage.sensors.scan',side_effect=snapshots), \
             patch('usage.sensors.augment_probe',return_value='active'), \
             patch.object(sensor,'devices',return_value=[{'id':'gpu:x','bus':'pci','label':'GPU','value':75,'power':100}]):
            sensor.sample(100)
            _,metrics,_,_=sensor.sample(115)
        self.assertEqual(metrics['gpu:x']['apps'],{'ollama':75,'unattributed':0})
