{ fetchzip, lib }:

fetchzip rec {
  pname = "alarmo";
  version = "1.10.19";

  url = "https://github.com/nielsfaber/alarmo/releases/download/v${version}/alarmo.zip";
  hash = "sha256-nkfzMcYaeOtQsZM3LLhvN7t9yIlLx2WYRvGlTFhwd/8=";
  # The release archive contains the integration files at its root.
  stripRoot = false;

  meta = {
    description = "Alarm system custom integration for Home Assistant";
    homepage = "https://github.com/nielsfaber/alarmo";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
