{
  environment.shellAliases = {
    ju = "journalctl -u";
    jfu = "journalctl -f -u";
    jru = "journalctl -r -u";
    ssr = "sudo systemctl restart";
    sss = "sudo systemctl stop";
  };
}
