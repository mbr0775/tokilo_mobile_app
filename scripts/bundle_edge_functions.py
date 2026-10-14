from pathlib import Path
import re

output = Path('.release/functions')
output.mkdir(parents=True, exist_ok=True)
for name in ['delete-account', 'send-chat-push']:
    source = Path('supabase/functions', name, 'index.ts').read_text(encoding='utf-8')
    source = re.sub(r'^import[^\n]+from "\./handler\.ts";\n', '', source, flags=re.M)
    handler = Path('supabase/functions', name, 'handler.ts').read_text(encoding='utf-8')
    output.joinpath(name + '.ts').write_text(source + '\n' + handler, encoding='utf-8')
