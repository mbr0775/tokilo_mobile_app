"""Reject private credentials in the candidate Git index without printing values."""
import base64
import json
import re
import subprocess
import sys

names = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
issues = []
for name in filter(None, names):
    lower = name.lower()
    if lower.endswith(('.p12', '.pfx', '.jks', '.keystore', 'key.properties', 'firebase-service-account.json')):
        issues.append((name, 'private credential file'))
        continue
    data = subprocess.check_output(['git', 'show', ':' + name])
    if b'\0' in data[:8192]:
        continue
    source = data.decode('utf-8', errors='replace')
    if re.search(r'-----BEGIN (?:RSA |EC |ENCRYPTED )?PRIVATE KEY-----', source):
        issues.append((name, 'private key material'))
    if re.search(r'\bsb_secret_[A-Za-z0-9_-]{20,}|\bre_[A-Za-z0-9]{25,}', source):
        issues.append((name, 'server credential'))
    for token in re.findall(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', source):
        try:
            payload = token.split('.')[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
            if claims.get('role') == 'service_role':
                issues.append((name, 'service role JWT'))
        except (ValueError, UnicodeDecodeError):
            pass
if issues:
    for name, reason in sorted(set(issues)):
        print(f'{name}: {reason}', file=sys.stderr)
    raise SystemExit(1)
print(f'Candidate index checked: {len(list(filter(None, names)))} files; no private credentials found.')
