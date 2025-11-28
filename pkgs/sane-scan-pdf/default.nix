{
  bc,
  fetchFromGitHub,
  ghostscript,
  imagemagick,
  lib,
  makeWrapper,
  netpbm,
  parallel,
  poppler-utils,
  stdenv,
  tesseract,
  units,
  unpaper,
  util-linux,
}:

let
  binPath = lib.makeBinPath [
    bc
    ghostscript
    imagemagick
    netpbm
    parallel
    poppler-utils
    tesseract
    units
    unpaper
    util-linux
  ];
in
stdenv.mkDerivation rec {
  pname = "sane-scan-pdf";
  version = "1.4";

  src = fetchFromGitHub {
    owner = "rocketraman";
    repo = "sane-scan-pdf";
    rev = "v${version}";
    sha256 = "sha256-WGtg+B11lKjTwTVICldz16UfjAk4l7pftukbfXb3S3c=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp scan $out/bin
    cp scan_perpage $out/bin
    chmod +x $out/bin/*
    wrapProgram $out/bin/scan --prefix PATH : ${binPath}
    wrapProgram $out/bin/scan_perpage --prefix PATH : ${binPath}
  '';
}
