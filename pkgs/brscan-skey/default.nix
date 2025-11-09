{
  fetchUrl,
  stdenv,
  writeTextFile,
}:

stdenv.mkDerivation rec {
  pname = "brscan-skey";
  version = "0.3.4-0";

  src = fetchUrl {
    url = "http://download.brother.com/welcome/dlf006650/${pname}-${version}.x86_64.rpm";
    sha256 = "";
  };

  # Patch brscan-skey so that it doesn't have hardcoded paths to brscan-skey-exe
  patchPhase = ''
    sed -i 's|/opt/brother/scanner/brscan-skey/brscan-skey-exe|${out}/bin/brscan-skey-exe|g' brscan-skey
  '';

  # Expose configuration file as /opt/brother/scanner/brscan-skey/brscan-skey.config
  configFile = writeTextFile {
    name = "brscan-skey.config";
    text = ''
      password=
      IMAGE=
      OCR=
      EMAIL=
      FILE=
      SEMID=b
    '';
  };
  
  installPhase = ''
    mkdir -p $out/bin
    cp brscan-skey $out/bin
    cp brscan-skey-exe $out/bin
    cp ${configFile} $out/brscan-skey.config
    chmod +x $out/bin/brscan-skey $out/bin/brscan-skey-exe
  '';
}
