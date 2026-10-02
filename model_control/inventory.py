"""Resident model inventories; installed model lists are deliberately not used."""
from concurrent.futures import ThreadPoolExecutor
from .api import call, row, report
from .unsloth import inventory as unsloth_inventory

APPS = ('ollama','comfy','unsloth','invoke','llm','openclaw','openwebui')

def inspect(app):
    try:
        return inventory(app)
    except Exception:
        return report(app, online=False, note='Model status unavailable. The app may be stopped, starting, or require authentication.')

def all_apps():
    with ThreadPoolExecutor(max_workers=5) as pool:
        return dict(zip(APPS, pool.map(inspect, APPS)))

def inventory(app):
    if app in {'openclaw','openwebui'}:
        return report(app, note='Models live in the configured provider. For local Ollama models, use the Ollama controls below; unloading affects every client using that model.', provider='ollama')
    if app == 'unsloth':
        return unsloth_inventory()
    if app == 'ollama':
        models = [row(m['name'],m['name'],True,bytes=m.get('size'),vram_bytes=m.get('size_vram'))
                  for m in call(app,'/api/ps')['models']]
        return report(app,models,unload_all=bool(models),
            note='Activity is not reported by Ollama. Unload requests expire models after current requests finish. New requests can load them again.')
    if app == 'comfy':
        queue = call(app,'/queue')
        busy = bool(queue['queue_running'] or queue['queue_pending'])
        return report(app, activity='busy' if busy else 'idle', unload_all=not busy,
            inventory_known=False, note='ComfyUI does not expose resident model names. Release all clears its model and execution caches after the current job; model files stay on disk.')
    if app == 'invoke':
        queue = call(app,'/api/v1/queue/default/status')
        state = queue['queue']
        busy = bool(state['in_progress'] or state['pending'])
        return report(app, activity='busy' if busy else 'idle', unload_all=not busy,
            inventory_known=False, note='InvokeAI does not expose resident model names. Release all empties its RAM/VRAM model cache; models locked by a job are retained.')
    if app == 'llm':
        models = [row(m['id'],m['id']) for m in call(app,'/v1/models')['data']]
        return report(app,models,note='This single-model llama.cpp service keeps its model loaded for its lifetime. Use Stop app to release it; there is no separate unload API in this configuration.')
    raise ValueError('Unknown app')
