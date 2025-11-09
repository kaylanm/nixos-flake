{ stdenv }:

stdenv.mkDerivation rec {
  pname = "hello-example";
  version = "1.0";
  
  src = ./.;
  
  installPhase = ''
    mkdir -p $out/bin
    echo '#!/bin/sh' > $out/bin/hello
    echo 'echo "Hello from custom package!"' >> $out/bin/hello
    chmod +x $out/bin/hello
  '';
}
