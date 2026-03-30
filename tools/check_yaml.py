import yaml,sys,traceback
p='.github/workflows/ci.yml'
try:
    with open(p,'r',encoding='utf-8') as f:
        yaml.safe_load(f)
    print('OK')
except Exception as e:
    print('YAML_ERROR', e)
    traceback.print_exc()
    sys.exit(1)
