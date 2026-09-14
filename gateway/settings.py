from dataclasses import dataclass
import json
import os
from urllib.parse import urlsplit

APP_IDS = frozenset({'dashboard', 'comfy', 'unsloth', 'llm',
                     'ollama', 'invoke', 'openwebui', 'openclaw'})
PREFIX = '/_gateway'
COOKIE = '__Host-ai_gateway'
STATE_COOKIE = '__Host-ai_oauth'


def origin(value: str, testing: bool = False) -> str:
    parsed = urlsplit(value)
    if (parsed.scheme != 'https' and not testing) or not parsed.hostname:
        raise ValueError('Public origins must use HTTPS')
    if parsed.username or parsed.password or parsed.path not in ('', '/'):
        raise ValueError('Use an origin without credentials or a path')
    if parsed.query or parsed.fragment:
        raise ValueError('Origins cannot contain a query or fragment')
    return f'{parsed.scheme}://{parsed.netloc}'.rstrip('/')


@dataclass
class Settings:
    origins: dict[str, str]
    links: dict[str, str]
    token: str
    client_id: str
    client_secret: str
    owner_id: str
    testing: bool = False
    session_seconds: int = 28800
    max_streams: int = 24

    @classmethod
    def from_env(cls) -> 'Settings':
        mapping = json.loads(os.environ['GATEWAY_ORIGINS'])
        mapping = {origin(k): v for k, v in mapping.items()}
        if not mapping or not set(mapping.values()) <= APP_IDS:
            raise ValueError('Unknown or empty application mapping')
        token = os.environ['CONNECTOR_TOKEN']
        if len(token) < 43:
            raise ValueError('Generate a connector token with setup.py')
        links = json.loads(os.environ.get('APP_LINKS', '{}'))
        links = {k: origin(v) for k, v in links.items() if k in APP_IDS}
        client_id = os.environ['GITHUB_CLIENT_ID'].strip()
        client_secret = os.environ['GITHUB_CLIENT_SECRET'].strip()
        owner_id = os.environ['GITHUB_OWNER_ID'].strip()
        if not client_id or not client_secret or not owner_id.isdecimal() or int(owner_id) < 1:
            raise ValueError('Set OAuth credentials and a positive numeric GitHub owner ID')
        return cls(mapping, links, token, client_id, client_secret, owner_id)
