{ ... }:

{
  # A separate tsnet node owns idp.manx-in.ts.net and its HTTPS listener.
  # First startup prints an enrollment URL in the journal; state persists here.
  services.tsidp = {
    enable = true;
    settings = {
      hostName = "idp";
      useLocalTailscaled = false;
      enableFunnel = false;
      enableSts = false;
    };
  };
}
