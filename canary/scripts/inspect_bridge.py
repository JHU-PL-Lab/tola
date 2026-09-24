#!/usr/bin/env python3
"""Record what a package-manager BRIDGE is, and what it does, in this world.

A bridge is package content that exists for cooperation between two
package managers (canary's Canary_bridge). For an opam conf package:

- what it IS: the version installed, and the system packages its
  depexts map it to;
- what it DOES: its build predicate, a check against the system. This
  script DISPATCHES that check in the current world -- the capability
  query the predicate makes -- and records the answers, so a run can say
  what the bridge did here instead of that nothing was recorded.

It asks no package manager anything by itself. Every such question
arrives as a shell command TEMPLATE built by canary's drivers
(src/canary/tool/canary_pm_*.ml and canary_bridge_driver.ml), so how to
ask opam or apt is spelled in one place; a template may contain {} where
a package name or a path goes. The one tool it runs on its own account
is the one the predicate names, pkg-config, because dispatching the
predicate is the point.

Exit status is the CHECK's verdict, and the record is written whatever
it is:
  0  the predicate's capability query holds
  1  it does not hold (the record says whether the predicate has a
     fallback canary did not dispatch)
  3  canary cannot dispatch this predicate: it makes no pkg-config query

A predicate is written for every platform at once -- each command and
each argument may carry an opam FILTER ({os != "win32"}) -- so the
dispatch keeps only what applies here, evaluating each filter against
the answers `opam var` gives (asked through --var-cmd). conf-zlib is why:
its Windows-only --personality flags come AFTER "pkg-config" in the one
flat command it has.

Usage:
  inspect_bridge.py --package conf-gmp --kind conf_package --pm opam \\
      --sys-pm apt --installed-cmd CMD --depexts-cmd CMD \\
      --predicate-cmd CMD --var-cmd CMD_WITH_{} \\
      [--binding-package zarith --depends-cmd CMD] \\
      [--sys-version-cmd CMD_WITH_{}] [--owner-cmd CMD_WITH_{}]
  inspect_bridge.py --parse-predicate [--var os=linux ...] < build.txt
      prints the query canary would dispatch for that predicate; a
      variable neither given nor answered by --var-cmd is unknown, and a
      comparison with it is false. --var also fixes a variable when
      recording, which is how a test pins the platform.
"""
import argparse
import json
import re
import shlex
import subprocess
import sys


def run(cmd):
    """(rc, stdout, stderr) of a shell command."""
    p = subprocess.run(["sh", "-c", cmd], capture_output=True, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def fill(template, value):
    return template.replace("{}", shlex.quote(value))


# -- filters: the subset of opam's filter language predicates use


def eval_filter(src, var):
    """Does an opam filter hold? [var] answers a variable's value (a
    string) or None when it is unknown; a comparison with an unknown side
    is false, and a version comparison, which no predicate measured uses,
    is false too -- a filter canary cannot decide keeps its argument out,
    because running a command meant for another platform is the worse
    error."""
    toks = re.findall(r'"[^"]*"|!=|<=|>=|[=<>!&|()]|[^\s"=<>!&|()]+', src)
    pos = [0]

    def peek():
        return toks[pos[0]] if pos[0] < len(toks) else None

    def take():
        t = toks[pos[0]]
        pos[0] += 1
        return t

    def value(t):
        return t[1:-1] if t.startswith('"') else var(t)

    def atom():
        t = take()
        if t == "(":
            v = expr()
            if peek() == ")":
                take()
            return v
        if t == "!":
            return not atom()
        left = value(t)
        if peek() in ("=", "!=", "<", ">", "<=", ">="):
            op, right = take(), value(take())
            if left is None or right is None:
                return False
            if op == "=":
                return left == right
            if op == "!=":
                return left != right
            return False
        return left == "true"

    def term():
        v = atom()
        while peek() == "&":
            take()
            w = atom()
            v = v and w
        return v

    def expr():
        v = term()
        while peek() == "|":
            take()
            w = term()
            v = v or w
        return v

    try:
        return bool(expr())
    except Exception:
        return False


# -- the predicate: opam's value syntax, as `opam show --field=build` prints it


def skip_filter(text, i):
    """(the filter's source, the index after it), for text[i] == '{'."""
    depth, j, in_str = 1, i + 1, False
    while j < len(text) and depth > 0:
        if text[j] == '"':
            in_str = not in_str
        elif not in_str:
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
        j += 1
    return text[i + 1:j - 1], j


def tokens(text):
    """Split an opam field value into [kind, value, filter] tokens, kind
    'str' | 'word' | 'open' | 'close'. A filter attaches to the token
    before it: an argument's own, or a whole command's after its ']'."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j, buf = i + 1, []
            while j < n and text[j] != '"':
                if text[j] == "\\" and j + 1 < n:
                    buf.append(text[j + 1])
                    j += 2
                    continue
                buf.append(text[j])
                j += 1
            out.append(["str", "".join(buf), None])
            i = j + 1
        elif c == "{":
            src, i = skip_filter(text, i)
            if out:
                out[-1][2] = src
        elif c == "[":
            out.append(["open", c, None])
            i += 1
        elif c == "]":
            out.append(["close", c, None])
            i += 1
        elif c == "#":
            while i < n and text[i] != "\n":
                i += 1
        elif c.isspace():
            i += 1
        else:
            j = i
            while j < n and not text[j].isspace() and text[j] not in '[]{}"':
                j += 1
            out.append(["word", text[i:j], None])
            i = j
    return out


def commands(text, var):
    """The commands of a build field that apply on this platform: each
    innermost [ ... ] group, plus the arguments outside any group as one
    command (a field that is a single flat command, like conf-libffi's),
    each keeping only the arguments whose own filter holds."""
    def keep(tok):
        return tok[2] is None or eval_filter(tok[2], var)

    cmds, stack, flat = [], [], []
    for tok in tokens(text):
        kind = tok[0]
        if kind == "open":
            stack.append([])
        elif kind == "close":
            if stack:
                group = stack.pop()
                if group and keep(tok):
                    cmds.append(group)
        elif not keep(tok):
            continue
        elif stack:
            stack[-1].append(tok[1])
        else:
            flat.append(tok[1])
    if flat:
        cmds.insert(0, flat)
    return cmds


SEPARATORS = {"||", "&&", ";", "|"}
# flags whose value is the NEXT argument, so it is not a module name
VALUE_FLAGS = {
    "--atleast-version", "--exact-version", "--max-version",
    "--atleast-pkgconfig-version", "--define-variable", "--variable",
}
COMPARATORS = {">=", "<=", "=", "<", ">", "!="}


def words_of(cmd):
    """A command's words, with each shell-string argument split the way
    sh would split it (conf-gmp's predicate is one `sh -c` string)."""
    words = []
    for arg in cmd:
        if any(ch.isspace() for ch in arg):
            try:
                words.extend(shlex.split(arg, posix=True))
            except ValueError:
                words.extend(arg.split())
        else:
            words.append(arg)
    return words


def query_of_predicate(text, var):
    """The first pkg-config invocation in the predicate as it applies on
    this platform: its argv, the modules it asks about (with any version
    comparison), and what the command falls back to when the query
    fails. None when the predicate makes no pkg-config query."""
    for cmd in commands(text, var):
        words = words_of(cmd)
        for i, w in enumerate(words):
            if w != "pkg-config":
                continue
            argv, j = [w], i + 1
            while j < len(words) and words[j] not in SEPARATORS:
                argv.append(words[j])
                j += 1
            fallback = None
            if j < len(words) and words[j] == "||":
                fallback = " ".join(words[j + 1:]) or None
            modules, skip = [], False
            args = argv[1:]
            for k, a in enumerate(args):
                if skip:
                    skip = False
                    continue
                if a.startswith("-"):
                    skip = a in VALUE_FLAGS
                    continue
                if a in COMPARATORS and modules and k + 1 < len(args):
                    modules[-1] = "%s %s %s" % (modules[-1], a, args[k + 1])
                    skip = True
                    continue
                modules.append(a)
            return {"tool": "pkg-config", "argv": argv, "modules": modules,
                    "fallback": fallback}
    return None


# -- the record --------------------------------------------------------------


def split_list(text):
    """opam's printed list: quoted or bare names, whitespace/comma
    separated."""
    names = []
    for part in text.replace(",", " ").split():
        part = part.strip('"[]')
        if part:
            names.append(part)
    return names


def capability(module, owner_cmd):
    name = module.split()[0]
    def ask(flag):
        rc, out, _ = run("pkg-config %s %s" % (flag, shlex.quote(name)))
        return out if rc == 0 and out else None
    pcfiledir = ask("--variable=pcfiledir")
    pcfile = "%s/%s.pc" % (pcfiledir, name) if pcfiledir else None
    owner = None
    if pcfile and owner_cmd:
        _, out, _ = run(fill(owner_cmd, pcfile))
        owner = out.splitlines()[0] if out else None
    return {"module": name, "version": ask("--modversion"),
            "libdir": ask("--variable=libdir"), "pcfile": pcfile,
            "owner": owner}


def opam_vars(template, pairs=None):
    """A lookup for opam variables: a value given on the command line
    first (a test fixes the platform this way), else opam's answer
    through [template], remembered — a predicate names the same few
    again and again."""
    cache = dict(p.split("=", 1) for p in pairs or [])

    def var(name):
        if name not in cache:
            rc, out, _ = run(fill(template, name)) if template else (1, "", "")
            cache[name] = out if rc == 0 and out else None
        return cache[name]

    return var


def record(args):
    var = opam_vars(args.var_cmd, args.var)
    _, installed, _ = run(args.installed_cmd)
    _, depexts_text, _ = run(args.depexts_cmd)
    _, predicate, _ = run(args.predicate_cmd)
    depexts = split_list(depexts_text)
    versions = {}
    for p in depexts:
        v = None
        if args.sys_version_cmd:
            _, out, _ = run(fill(args.sys_version_cmd, p))
            v = out or None
        versions[p] = v
    depends = None
    if args.depends_cmd:
        _, depends, _ = run(args.depends_cmd)
        depends = depends or None
    query = query_of_predicate(predicate, var) if predicate else None
    check = {"dispatched": False, "rc": None, "holds": None, "output": None}
    caps = []
    status = 3
    if query is not None:
        p = subprocess.run(query["argv"], capture_output=True, text=True)
        out = (p.stdout + p.stderr).strip()
        check = {"dispatched": True, "rc": p.returncode,
                 "holds": p.returncode == 0, "output": out[:400] or None}
        caps = [capability(m, args.owner_cmd) for m in query["modules"]]
        status = 0 if p.returncode == 0 else 1
    rec = {
        "kind": "bridge",
        "pm": args.pm,
        "bridge_kind": args.kind,
        "package": args.package,
        "installed_version": installed or None,
        "depexts": depexts,
        "depext_versions": versions,
        "sys_pm": args.sys_pm,
        "binding_package": args.binding_package,
        "binding_depends": depends,
        "binding_names_bridge": (None if depends is None
                                 else ('"%s"' % args.package) in depends),
        "predicate": predicate or None,
        "query": query,
        "check": check,
        "capability": caps,
    }
    json.dump(rec, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return status


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--parse-predicate", action="store_true")
    ap.add_argument("--package")
    ap.add_argument("--kind", default="conf_package")
    ap.add_argument("--pm", default="opam")
    ap.add_argument("--sys-pm", default="")
    ap.add_argument("--binding-package")
    ap.add_argument("--installed-cmd")
    ap.add_argument("--depexts-cmd")
    ap.add_argument("--predicate-cmd")
    ap.add_argument("--depends-cmd")
    ap.add_argument("--sys-version-cmd")
    ap.add_argument("--owner-cmd")
    ap.add_argument("--var-cmd")
    ap.add_argument("--var", action="append")
    args = ap.parse_args()
    if args.parse_predicate:
        json.dump(query_of_predicate(sys.stdin.read(),
                                     opam_vars(args.var_cmd, args.var)),
                  sys.stdout, sort_keys=True)
        sys.stdout.write("\n")
        return 0
    for need in ("package", "installed_cmd", "depexts_cmd", "predicate_cmd"):
        if getattr(args, need) is None:
            ap.error("--%s is required" % need.replace("_", "-"))
    return record(args)


if __name__ == "__main__":
    sys.exit(main())
