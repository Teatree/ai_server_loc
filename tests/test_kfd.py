import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from usage.kfd import augment

class KfdTests(unittest.TestCase):
    def test_service_account_allocations_join_by_gpu_and_do_not_duplicate_drm(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            node=root/'class/kfd/kfd/topology/nodes/1'
            node.mkdir(parents=True)
            (node/'gpu_id').write_text('123')
            (node/'properties').write_text('drm_render_minor 128\n')
            device=root/'class/drm/renderD128/device'
            device.mkdir(parents=True)
            proc=root/'class/kfd/kfd/proc/42'
            proc.mkdir(parents=True)
            (proc/'vram_123').write_text('8000000')
            rows={42:{'owner':'ollama'}}
            clients={('device','old'):{'pid':42,'owner':'ollama','engines':{},'vram':900,'compute':True}}
            augment(rows,clients,root)
            self.assertEqual(len(clients),1)
            self.assertEqual(clients[('device','kfd:42')]['owner'],'ollama')
            self.assertEqual(clients[('device','kfd:42')]['vram'],8000000)
            # Cross-user /proc/fd denial leaves no DRM entry, but public KFD still works.
            clients.clear();augment(rows,clients,root)
            self.assertEqual(clients[('device','kfd:42')]['owner'],'ollama')
            # Missing /proc owner remains visible as unattributed, not another app.
            clients.clear();augment({},clients,root)
            self.assertEqual(clients[('device','kfd:42')]['owner'],'unattributed')
            # Counter-supported clients retain the measured path.
            clients={('device','graphics'):{'pid':42,'engines':{'compute':1}}}
            augment(rows,clients,root)
            self.assertEqual(list(clients),[('device','graphics')])
