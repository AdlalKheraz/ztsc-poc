import os, tarfile, json, csv

def extract(path, label):
    feat = {'file': os.path.basename(path), 'label': label, 'files': 0, 'install_scripts': 0, 'net_calls': 0, 'obfuscation': 0, 'exec': 0}
    try:
        with tarfile.open(path, "r:gz") as tar:
            feat['files'] = len(tar.getmembers())
            for m in tar.getmembers():
                if m.isfile():
                    f = tar.extractfile(m)
                    if not f: continue
                    content = f.read().decode('utf-8', errors='ignore')
                    if m.name.endswith('package.json'):
                        try:
                            scripts = json.loads(content).get('scripts', {})
                            if any(k in scripts for k in ['preinstall', 'install', 'postinstall', 'prepare']):
                                feat['install_scripts'] = 1
                        except: pass
                    elif m.name.endswith('.js') or m.name.endswith('setup.js'):
                        feat['net_calls'] += sum(content.count(x) for x in ['curl', 'wget', 'http', 'net.Socket'])
                        feat['obfuscation'] += sum(content.count(x) for x in ['eval', 'base64', 'Buffer', '\\x'])
                        feat['exec'] += sum(content.count(x) for x in ['child_process', 'exec', 'spawn'])
    except: pass
    return feat

data = []
for f in os.listdir('dataset/malicious'):
    if f.endswith('.tgz'): data.append(extract(f'dataset/malicious/{f}', 1))
for f in os.listdir('dataset/legitimate'):
    if f.endswith('.tgz'): data.append(extract(f'dataset/legitimate/{f}', 0))

with open('dataset/features.csv', 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=data[0].keys())
    writer.writeheader()
    writer.writerows(data)

print(f"Extraction terminée : {len(data)} paquets analysés. Fichier généré : dataset/features.csv")
