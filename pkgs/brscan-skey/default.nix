{
  cpio,
  fetchurl,
  rpm,
  stdenv,
  writeTextFile,
}:

stdenv.mkDerivation rec {
  pname = "brscan-skey";
  version = "0.3.4-0";

  brscanRpm = fetchurl {
    url = "http://download.brother.com/welcome/dlf006650/${pname}-${version}.x86_64.rpm";
    sha256 = "sha256-oK2Y9n+btlKQJUSZK58lHlKKQQ7hsbDzfpTznxsCJi4=";
  };

  buildInputs = [ rpm cpio ];

  unpackPhase = ''
    rpm2cpio ${brscanRpm} | cpio -idmv
  '';

  # Patch brscan-skey so that it doesn't have hardcoded paths to brscan-skey-exe
  patchPhase = ''
    sed -i "s|/opt/brother/scanner/brscan-skey/brscan-skey-exe|$out/bin/brscan-skey-exe|g" ./opt/brother/scanner/brscan-skey/brscan-skey
  '';

  # # Expose configuration file as /opt/brother/scanner/brscan-skey/brscan-skey.config
  # configFile = writeTextFile {
  #   name = "brscan-skey.config";
  #   text = ''
  #     password=
  #     IMAGE=
  #     OCR=
  #     EMAIL=
  #     FILE=
  #     SEMID=b
  #   '';
  # };
  
  installPhase = ''
    mkdir -p $out/bin
    cp ./opt/brother/scanner/brscan-skey/brscan-skey $out/bin
    cp ./opt/brother/scanner/brscan-skey/brscan-skey-exe $out/bin
    chmod +x $out/bin/brscan-skey $out/bin/brscan-skey-exe
  '';
}
