{
  lib,
  stdenvNoCC,
  python3,
  openssl,
  gh,
  makeWrapper,
  cacert,
}:

stdenvNoCC.mkDerivation {
  pname = "github-app-auth";
  version = "1.0.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./auth.py
      ./test_auth.py
    ];
  };
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ python3 ];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 -m unittest discover -v
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    install -Dm644 auth.py "$out/lib/github-app-auth/auth.py"
    makeWrapper ${python3}/bin/python3 "$out/bin/gh-app" \
      --add-flags "$out/lib/github-app-auth/auth.py gh" \
      --set GITHUB_APP_OPENSSL ${openssl}/bin/openssl \
      --set GITHUB_APP_GH ${gh}/bin/gh \
      --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
    makeWrapper ${python3}/bin/python3 "$out/bin/git-credential-github-app" \
      --add-flags "$out/lib/github-app-auth/auth.py credential" \
      --set GITHUB_APP_OPENSSL ${openssl}/bin/openssl \
      --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
    runHook postInstall
  '';
  meta = {
    description = "Ephemeral GitHub App installation authentication for gh and Git";
    mainProgram = "gh-app";
    platforms = lib.platforms.unix;
  };
}
