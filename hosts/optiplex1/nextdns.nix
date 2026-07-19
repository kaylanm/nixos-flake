{
  services.nextdns = {
    enable = true;

    arguments = [
      "--listen"
      "0.0.0.0:53"
      "--profile"
      "e34544"
    ];
  };
}
