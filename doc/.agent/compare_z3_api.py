#!/usr/bin/env python3
import json
import re
from pathlib import Path

JSON_PATH = Path("/home/ex/code/tola/_out/z3_h.json")
HEADER_PATH = Path("/home/ex/code/tola/_out/z3_h.i")


def type_qual_type(node):
    t = node.get("type")
    if isinstance(t, dict):
        return t.get("qualType") or t.get("desugaredQualType")
    return None


def is_z3_enum_typedef(node):
    qt = type_qual_type(node)
    return isinstance(qt, str) and qt.startswith("enum Z3_")


def walk(node, enums, funcs):
    if isinstance(node, dict):
        kind = node.get("kind")
        name = node.get("name")
        if isinstance(name, str) and name.startswith("Z3_"):
            if kind == "FunctionDecl":
                funcs.add(name)
            elif kind == "EnumDecl":
                enums.add(name)
            elif kind == "TypedefDecl" and is_z3_enum_typedef(node):
                enums.add(name)
        inner = node.get("inner")
        if isinstance(inner, list):
            for item in inner:
                walk(item, enums, funcs)
    elif isinstance(node, list):
        for item in node:
            walk(item, enums, funcs)


def parse_json_api(path):
    data = json.loads(path.read_text())
    enums = set()
    funcs = set()
    walk(data, enums, funcs)
    return enums, funcs


def parse_header_api(path):
    text = path.read_text(errors="ignore")
    flat = text.replace("\n", " ")

    enum_names = set(re.findall(r"(?:typedef[ \t\r\n]+)?enum[ \t\r\n]+(Z3_\w+)", text))
    enum_names.update(
        re.findall(r"enum[ \t\r\n]*\{[^}]*\}[ \t\r\n]*(Z3_\w+)[ \t\r\n]*;", text, flags=re.S)
    )

    func_names = set(
        m.group(1)
        for m in re.finditer(
            r"(Z3_[A-Za-z0-9_]+)[ \t\r\n]*\([^;]*?\)[ \t\r\n]*;",
            flat,
        )
    )

    return enum_names, func_names


def main():
    json_enums, json_funcs = parse_json_api(JSON_PATH)
    hdr_enums, hdr_funcs = parse_header_api(HEADER_PATH)

    missing_enums = sorted(json_enums - hdr_enums)
    missing_funcs = sorted(json_funcs - hdr_funcs)
    extra_enums = sorted(hdr_enums - json_enums)
    extra_funcs = sorted(hdr_funcs - json_funcs)

    print("parsed_enums", len(json_enums))
    print("parsed_funcs", len(json_funcs))
    print("header_enums", len(hdr_enums))
    print("header_funcs", len(hdr_funcs))
    print("missing_enums", len(missing_enums))
    print("missing_funcs", len(missing_funcs))
    print("extra_enums", len(extra_enums))
    print("extra_funcs", len(extra_funcs))

    print("\nMISSING_ENUMS_SAMPLE")
    print("\n".join(missing_enums[:50]))
    print("\nMISSING_FUNCS_SAMPLE")
    print("\n".join(missing_funcs[:50]))
    print("\nEXTRA_ENUMS_SAMPLE")
    print("\n".join(extra_enums[:50]))
    print("\nEXTRA_FUNCS_SAMPLE")
    print("\n".join(extra_funcs[:50]))


if __name__ == "__main__":
    main()
