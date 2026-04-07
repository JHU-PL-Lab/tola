(* PM ops for pip (lang PM, isolated stores via venv).
   Each venv is an independent store. Without venv, pip installs
   to the global/user site-packages (stateful global).

   Uniform PM ops:
   - install, remove, verify, query_version  (package ops)
   - check_available                          (remote query)
   - active_venv, create_venv, activate_venv  (store switching) *)

let install_cmd ~pkg = [%string "pip install %{pkg}"]

let remove_cmd ~pkg = [%string "pip uninstall -y %{pkg}"]

let verify_installed_cmd ~pkg =
  [%string "pip show %{pkg} >/dev/null 2>&1"]

let query_version_cmd ~pkg =
  [%string "pip show %{pkg} 2>/dev/null | grep '^Version:' | cut -d' ' -f2"]

let check_available_cmd ~pkg =
  [%string "pip index versions %{pkg} >/dev/null 2>&1"]

let list_installed_cmd =
  "pip list --format=columns"

(* Store switching: venv *)
let active_venv_cmd =
  "echo \"${VIRTUAL_ENV:-<none>}\""

let create_venv_cmd ~path =
  [%string "python3 -m venv %{path}"]

let activate_venv_cmd ~path =
  [%string "source %{path}/bin/activate"]
