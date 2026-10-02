"""SSH entry point: bounded JSON, fixed commands, never service stop/start."""
import json
import sys
from urllib.parse import urlencode
from .api import call
from .inventory import APPS, all_apps, inventory

def validate(request):
    if not isinstance(request,dict) or request.get('action') not in {'list','unload'}:
        raise ValueError('Invalid model request')
    if request['action']=='list':
        if set(request)!={'action'}:
            raise ValueError('Unexpected fields')
    elif (set(request)!={'action','app','models'} or request['app'] not in APPS or
          not isinstance(request['models'],list) or not 1<=len(request['models'])<=64 or
          any(not isinstance(x,str) or not 1<=len(x)<=2048 for x in request['models']) or
          len(set(request['models']))!=len(request['models'])):
        raise ValueError('Invalid unload selection')
    return request

def release(app, keys):
    state = inventory(app)  # Fresh check; never authorize from a cached browser snapshot.
    if state['activity']=='busy':
        raise ValueError('App is busy or loading. Wait for it to finish, then refresh.')
    available = {m['id']:m for m in state['models'] if m['can_unload']}
    if app in {'comfy','invoke'}:
        if keys!=['cache'] or not state['unload_all']:
            raise ValueError('Cache cannot be released now')
        route, body = ('/free',{'unload_models':True,'free_memory':True}) if app=='comfy' else ('/api/v2/models/empty_model_cache',{})
        call(app,route,body)
        return 'Cache release requested. Busy models may remain until work finishes.'
    if any(key not in available for key in keys):
        raise ValueError('Selection changed or safe unloading is unsupported. Refresh models.')
    for key in keys:
        # Recheck between models: a job could start after the previous release.
        current = inventory(app)
        if current['activity']=='busy' or key not in {m['id'] for m in current['models'] if m['can_unload']}:
            raise ValueError('State changed. Some earlier releases may have succeeded; refresh before retrying.')
        model = available[key]
        if app=='ollama':
            call(app,'/api/generate',{'model':key,'keep_alive':0,'stream':False})
        elif app=='unsloth' and key.startswith('text:'):
            call(app,'/api/inference/unload',{'model_path':key[5:],'force_cancel_active':False})
        elif app=='unsloth' and key.startswith('stt:'):
            params = urlencode({'engine':model['engine'],'model':model['name']})
            call(app,'/api/inference/audio/stt/unload?'+params,{})
        else:
            raise ValueError('Safe unload is not supported for this model')
    return 'Unload requested. Refreshing resident models; no app was stopped.'

def main():
    try:
        raw = sys.stdin.read(131073)
        if len(raw)>131072:
            raise ValueError('Request too large')
        request = validate(json.loads(raw))
        if request['action']=='list':
            result = {'ok':True,'apps':all_apps()}
        else:
            # Serializes dashboard unloads across SSH processes; app-native guards
            # also protect requests coming from the applications themselves.
            import fcntl
            from pathlib import Path
            with (Path.home()/'.local/share/ai-model-control/unload.lock').open('a') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX)
                result = {'ok':True,'message':release(request['app'],request['models'])}
    except ValueError as error:
        result = {'ok':False,'error':str(error)}
    except Exception:
        result = {'ok':False,'error':'App refused or did not complete the request. It may be busy or require authentication. Refresh status before retrying; no automatic retry was made.'}
    print(json.dumps(result))

if __name__=='__main__':
    main()
