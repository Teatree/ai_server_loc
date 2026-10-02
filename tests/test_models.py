import json
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from model_control.api import report, row
from model_control.inventory import inventory, all_apps
from model_control.query import release, validate
from model_control.install_policy import launcher_policy, unit_policy, LOOP
from model_control.windows import server

class ModelTests(unittest.TestCase):
    def test_offline_apps_do_not_hide_the_rest_of_the_inventory(self):
        with patch('model_control.inventory.call',side_effect=ConnectionError), patch('model_control.unsloth.call',side_effect=ConnectionError):
            result = all_apps()
        self.assertFalse(result['ollama']['online'])
        self.assertFalse(result['unsloth']['online'])
        self.assertEqual(result['openclaw']['provider'],'ollama')

    def test_ollama_resident_inventory_not_installed_catalog(self):
        with patch('model_control.inventory.call',return_value={'models':[
                {'name':'test:latest','size':200,'size_vram':80}]}) as api:
            state = inventory('ollama')
        api.assert_called_once_with('ollama','/api/ps')
        self.assertEqual(state['models'][0]['vram_bytes'],80)
        self.assertEqual(state['models'][0]['activity'],'unknown')

    def test_ollama_unload_no_prompt_or_service_command(self):
        state = report('ollama',[row('test','test',True)])
        with patch('model_control.query.inventory',return_value=state), patch('model_control.query.call') as api:
            release('ollama',['test'])
        api.assert_called_once_with('ollama','/api/generate',{'model':'test','keep_alive':0,'stream':False})

    def test_busy_stale_and_unsupported_refuse_before_mutation(self):
        for state in [report('comfy',activity='busy'),report('llm',[row('test','test')]),report('ollama')]:
            with patch('model_control.query.inventory',return_value=state), patch('model_control.query.call') as api:
                with self.assertRaises(ValueError): release(state['app'],['test'])
                api.assert_not_called()

    def test_unload_all_checks_state_again_between_models(self):
        state = report('ollama',[row('a','a',True),row('b','b',True)])
        with patch('model_control.query.inventory',side_effect=[state,state,report('ollama',activity='busy')]), patch('model_control.query.call') as api:
            with self.assertRaisesRegex(ValueError,'Some earlier'): release('ollama',['a','b'])
            self.assertEqual(api.call_count,1)

    def test_cache_release_targets_only_memory(self):
        for app,path,body in [('comfy','/free',{'unload_models':True,'free_memory':True}),
                              ('invoke','/api/v2/models/empty_model_cache',{})]:
            with patch('model_control.query.inventory',return_value=report(app,activity='idle',unload_all=True)), patch('model_control.query.call') as api:
                release(app,['cache'])
                api.assert_called_once_with(app,path,body)

    def test_policy_preserves_explicit_stop_and_unrelated_conflicts(self):
        self.assertEqual(launcher_policy('start\n'+LOOP+'stop_one "$name"\n'),'start\nstop_one "$name"\n')
        self.assertEqual(unit_policy('[Unit]\nConflicts=ai-llama.service other.service\nAfter=network.target\n'),
                         '[Unit]\nConflicts=other.service\nAfter=network.target\n')
        with self.assertRaises(ValueError): launcher_policy('for other in llm comfy changed')

    def test_unsloth_never_forces_active_generation_cancel(self):
        state = report('unsloth',[row('text:abc','abc',True)])
        with patch('model_control.query.inventory',return_value=state), patch('model_control.query.call') as api:
            release('unsloth',['text:abc'])
        api.assert_called_once_with('unsloth','/api/inference/unload',{'model_path':'abc','force_cancel_active':False})

    def test_unsloth_training_blocks_text_and_speech_unload(self):
        from model_control.unsloth import inventory as unsloth
        responses = {'/api/inference/status':{'loaded':['text-model'],'loading':[]},
            '/api/train/status':{'is_training_running':False,'phase':'idle'},
            '/api/train/diffusion/status':{'active':True,'base_model':'training-model'},
            '/api/inference/images/status':{'loaded':True,'repo_id':'image-model'},
            '/api/inference/video/status':{'loaded':False},
            '/api/inference/audio/stt/status':{'transformers':{'loaded_model':'small','loading':False}},
            '/api/settings/embedding-model':{'backend_loaded':True,'loaded':False,'embedding_model':'not-loaded'}}
        with patch('model_control.unsloth.call',side_effect=lambda app,path:responses[path]):
            result = unsloth()
        self.assertEqual(result['activity'],'busy')
        self.assertFalse(result['unload_all'])
        self.assertTrue(all(not model['can_unload'] for model in result['models']))
        self.assertNotIn('not-loaded',[model['name'] for model in result['models']])

    def test_unsloth_native_display_name_uses_exact_loaded_identifier(self):
        from model_control.unsloth import inventory as unsloth
        values = [{'loaded':['folder-name'],'loading':[],'active_model':'folder-name',
                   'model_identifier':'/models/folder-name'},
                  {'is_training_running':False,'phase':'idle'}, {'active':False},
                  {'loaded':False},{'loaded':False},{},{'backend_loaded':False}]
        with patch('model_control.unsloth.call',side_effect=values):
            model = unsloth()['models'][0]
        self.assertEqual(model['id'],'text:/models/folder-name')
        self.assertEqual(model['name'],'folder-name')

    def test_request_schema_rejects_arbitrary_commands_and_urls(self):
        for body in [{},[],{'action':'restart','app':'ollama'},
                     {'action':'unload','app':'ollama','models':[]},
                     {'action':'unload','app':'ollama','models':['a','a']},
                     {'action':'unload','app':'ollama','models':['a'],'url':'http://evil'},
                     {'action':'list','shell':'anything'}]:
            with self.assertRaises(ValueError): validate(body)

class ModelHTTPTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        config = Path(self.temp.name)/'config.json'
        config.write_text(json.dumps({'ssh':{'key':'test','target':'unused'},'endpoints':[]}))
        self.calls = []
        def execute(payload):
            self.calls.append(payload)
            return {'ok':True,'apps':{}}
        self.http = server(config,port=0,execute=execute)
        self.thread = threading.Thread(target=self.http.serve_forever,daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.http.server_port}'

    def tearDown(self):
        self.http.shutdown(); self.http.server_close(); self.thread.join()
        self.temp.cleanup()

    def test_csrf_and_rebinding_rejected_before_ssh(self):
        payload = json.dumps({'action':'unload','app':'ollama','models':['a']}).encode()
        for headers in [{},{'Origin':'https://evil.example'},
                        {'Origin':'http://127.0.0.1:32146','Host':'evil.example'}]:
            request = Request(self.url+'/api/models/unload',data=payload,
                headers={**headers,'Content-Type':'application/json'})
            with self.assertRaises(HTTPError) as error: urlopen(request)
            self.assertEqual(error.exception.code,403)
        self.assertEqual(self.calls,[])

    def test_local_origin_can_read_and_explicitly_release(self):
        headers = {'Origin':'http://127.0.0.1:32146','Content-Type':'application/json'}
        with urlopen(Request(self.url+'/api/models',headers=headers)) as response:
            self.assertEqual(response.headers['Access-Control-Allow-Origin'],headers['Origin'])
        payload = {'action':'unload','app':'ollama','models':['a']}
        with urlopen(Request(self.url+'/api/models/unload',headers=headers,data=json.dumps(payload).encode())) as response:
            self.assertTrue(json.load(response)['ok'])
        self.assertEqual(self.calls,[{'action':'list'},payload])
