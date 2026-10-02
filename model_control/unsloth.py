"""Unsloth Studio resident backends, distinct from training and disk downloads."""
from .api import call, row, report

def inventory():
    state = call('unsloth','/api/inference/status')
    train = call('unsloth','/api/train/status')
    diffusion_train = call('unsloth','/api/train/diffusion/status')
    training = bool(train['is_training_running'] or diffusion_train['active'] or
                    train.get('phase','unknown') not in {'idle','completed','finished','failed','cancelled','stopped'})
    loading = bool(state['loading'])
    activity = 'busy' if training or loading else 'unknown'
    names = list(state['loaded'])
    active = state.get('model_identifier') or state.get('active_model')
    if active and not names:
        names.append(active)
    models = []
    for name in names:
        identifier = active if active and name==state.get('active_model') else name
        models.append(row('text:'+identifier,name,not training and not loading,activity,kind='text'))
    notes = ['Chat activity is checked by Unsloth when unloading. Active training or loading blocks dashboard unloads.']
    for kind in ('images','video'):
        try:
            s = call('unsloth',f'/api/inference/{kind}/status')
            if s.get('loaded'):
                # These endpoints cancel work, without an atomic idle-only option.
                models.append(row(kind+':'+s['repo_id'],s['repo_id'],kind=kind))
                notes.append(f'{kind.title()}: unload in Unsloth itself; its release API can cancel generation.')
        except Exception:
            notes.append(f'{kind.title()} model status unavailable.')
    try:
        stt = call('unsloth','/api/inference/audio/stt/status')
        for engine in ('transformers','gguf','mtmd'):
            s = stt.get(engine,{})
            if s.get('loaded_model'):
                models.append(row('stt:'+engine+':'+s['loaded_model'],s['loaded_model'],
                    not training and not loading and not s.get('loading'),kind='speech',engine=engine))
    except Exception:
        notes.append('Speech model status unavailable.')
    try:
        embedding = call('unsloth','/api/settings/embedding-model')
        if embedding['backend_loaded']:
            name = embedding['embedding_model'] if embedding['loaded'] else 'Resident embedding model (name unavailable)'
            models.append(row('embedding',name,kind='embedding'))
            notes.append('Release the embedding model in Unsloth settings after indexing finishes.')
    except Exception:
        notes.append('Embedding model status unavailable.')
    if training:
        name = diffusion_train.get('base_model') if diffusion_train['active'] else train.get('model_name')
        models.append(row('training',name or 'Active training model',False,'busy',kind='training'))
    return report('unsloth',models,' '.join(notes),activity,
        unload_all=bool(models) and all(m['can_unload'] for m in models))
