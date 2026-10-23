import json, os, pathlib, select, subprocess, sys, tempfile, time

package = pathlib.Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='hermes-gateway-regression-') as home:
    root = pathlib.Path(home)
    (root / 'config.yaml').write_text('''model:
  default: test-model
  provider: custom
  base_url: http://127.0.0.1:1/v1
  api_key: test-not-real
platform_toolsets:
  acp: []
''')
    env = {'PATH': str(package / 'bin') + ':/run/current-system/sw/bin',
           'HOME': home, 'HERMES_HOME': home, 'HERMES_ACP_SKIP_CONFIGURED_MCP': '1',
           'XDG_STATE_HOME': str(root / 'xdg-state'), 'PYTHONIOENCODING': 'utf-8'}
    with (root / 'adapter.log').open('w+') as log:
        p = subprocess.Popen([str(package / 'bin/hermes-acp')], cwd=home, env=env,
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log,
                             text=True, bufsize=1)
        def rpc(ident, method, params):
            p.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': ident, 'method': method, 'params': params}) + '\n')
            p.stdin.flush()
            deadline = time.monotonic() + 90
            while time.monotonic() < deadline:
                if not select.select([p.stdout], [], [], max(0, deadline - time.monotonic()))[0]:
                    break
                line = p.stdout.readline()
                if not line:
                    raise RuntimeError('adapter exited')
                response = json.loads(line)
                if response.get('id') == ident:
                    if 'error' in response:
                        raise RuntimeError(json.dumps(response['error']))
                    return response['result']
            raise RuntimeError(method + ' timed out')
        try:
            rpc(1, 'initialize', {'protocolVersion': 1, 'clientCapabilities': {},
                                 'clientInfo': {'name': 'nix-gateway-regression', 'version': '1'}})
            result = rpc(2, 'session/new', {'cwd': home, 'mcpServers': []})
            assert result.get('sessionId'), result
            print('ACP session/new succeeded through the auto-started gateway; no model prompt sent.', flush=True)
        except Exception:
            log.flush(); log.seek(0); print(log.read()[-12000:])
            gateway_log = root / 'logs/gateway-stdio.log'
            if gateway_log.exists(): print(gateway_log.read_text()[-12000:])
            raise
        finally:
            p.terminate()
            try: p.wait(timeout=5)
            except subprocess.TimeoutExpired: p.kill(); p.wait()
            stop = subprocess.run([str(package / 'bin/hermes'), 'gateway', 'stop'],
                                  env=env, cwd=home, capture_output=True, text=True, timeout=30)
            print('Isolated gateway cleanup exit:', stop.returncode, flush=True)
