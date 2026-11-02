{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  python3,
  git,
  bash,
  cacert,
  coreutils,
}:

rustPlatform.buildRustPackage {
  pname = "buzz-agent-tools";
  version = "0.1.0-unstable-2026-10-22";

  # Match the source revision used for optiplex3's relay deployment.
  src = fetchFromGitHub {
    owner = "block";
    repo = "buzz";
    rev = "20ba95ed8906b2b7ae1819bdddadf82c09778097";
    hash = "sha256-TjouzY6PHHQD9Y9bc+y9yu6A4+R+Wnzf2jBjISsfsFc=";
  };

  cargoHash = "sha256-bcLoCIjiCNLAYOqJ59ELQZJJ5ZUh58CSU9CyDTNbckk=";
  cargoBuildFlags = [
    "-p"
    "buzz-acp"
    "-p"
    "buzz-cli"
    "-p"
    "buzz-dev-mcp"
  ];
  cargoTestFlags = [
    "--no-fail-fast"
    "-p"
    "buzz-acp"
    "-p"
    "buzz-cli"
    "-p"
    "buzz-dev-mcp"
  ];
  # This upstream fixture intermittently fails with ETXTBSY immediately after
  # creating its mock executable. The real Hermes ACP launch is checked separately.
  checkFlags = [
    "--skip=acp::tests::claude_named_adapter_wire_lifecycle_records_prompt_and_cost"
  ];
  nativeBuildInputs = [ pkg-config ];
  nativeCheckInputs = [
    python3
    git
  ];
  buildInputs = [ openssl ];

  # Upstream tests generate executable fixtures rather than shipping scripts
  # that patchShebangs can discover. Nix sandboxes have no /usr/bin/env or /bin/bash.
  postPatch = ''
    substituteInPlace crates/buzz-acp/src/acp.rs \
      --replace-fail '#!/usr/bin/env bash' '#!${lib.getExe bash}'
    substituteInPlace crates/buzz-acp/src/acp/launch/tests.rs \
      --replace-fail '#!/usr/bin/env python3' '#!${lib.getExe python3}' \
      --replace-fail '/usr/bin/env' '${coreutils}/bin/env'
    substituteInPlace crates/buzz-acp/src/pool/pi_prompt_tests.rs \
      --replace-fail '#!/bin/bash' '#!${lib.getExe bash}'
    # This integration test clears its child's environment, including the CA
    # bundle required by reqwest even when the fixture only uses local endpoints.
    substituteInPlace crates/buzz-acp/tests/git_bootstrap.rs \
      --replace-fail '.env_clear()' \
      '.env_clear().env("SSL_CERT_FILE", "${cacert}/etc/ssl/certs/ca-bundle.crt")'
  '';
  preCheck = ''
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    export HOME=$(mktemp -d)
  '';

  meta = {
    description = "Buzz ACP harness, agent CLI, and MCP tools";
    homepage = "https://github.com/block/buzz";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "buzz-acp";
  };
}
