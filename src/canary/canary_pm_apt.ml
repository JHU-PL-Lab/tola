let install_cmd ~pkg = [%string "sudo apt-get install -y %{pkg}"]

let verify_installed_cmd ~pkg = [%string "dpkg -s %{pkg}"]

let query_version_cmd ~pkg =
  [%string "dpkg -s %{pkg} 2>/dev/null | grep '^Version:' | cut -d' ' -f2"]

let check_available_cmd ~pkg =
  [%string "apt-cache show %{pkg} >/dev/null 2>&1"]

let list_available_versions_cmd ~pkg =
  [%string "apt-cache madison %{pkg} 2>/dev/null | awk '{print $3}'"]
