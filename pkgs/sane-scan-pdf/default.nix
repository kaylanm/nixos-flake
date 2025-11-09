{
  bc,
  fetchFromGitHub,
  ghostscript,
  imagemagick,
  netpbm,
  parallel,
  poppler,
  stdenv,
  tesseract,
  units,
  unpaper,
  util-linux,
}:

stdenv.mkDerivation rec {
  pname = "sane-scan-pdf";
  version = "1.4";

  src = fetchFromGitHub {
    owner = "rocketraman";
    repo = "sane-scan-pdf";
    rev = "v${version}";
    sha256 = "";
  };

  buildInputs = [
    bc
    ghostscript
    imagemagick
    netpbm
    parallel
    poppler
    tesseract
    units
    unpaper
    util-linux
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp scan $out/bin
    cp scan_perpage $out/bin
    chmod +x $out/bin/*
  '';
}
