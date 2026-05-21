# DSL representation and rendering for package lifecycles
import os

def print_mermaid(diagram, config=None):
    output = ["```mermaid"]
    if config:
        output.append(config.strip())
    output.append("sequenceDiagram")

    # Participants
    for group_name, prefix, stages in diagram["participants"]:
        output.append(f"    box {group_name}")
        for stage in stages:
            var = f"{prefix}{stage.replace(' ', '')}"
            label = f"{stage} Stage ({group_name.split()[-1]})"
            output.append(f"      participant {var} as {label}")
        output.append("    end\n")

    # Steps
    for step in diagram["steps"]:
        output.append("    rect pink")
        output.append(f"      Note over {', '.join(step['notes_anchor'])}: [{step['action']}]")

        for entry in step["plans"]:
            kind = entry[0]
            if kind == "note":
                _, target, text = entry
                output.append(f"      Note over {target}: {text}")
            elif kind == "note_span":
                _, targets, text = entry
                output.append(f"      Note over {', '.join(targets)}: [{text}]")
            elif kind == "operation":
                _, src, dst, msg = entry
                output.append(f"      {src}->>{dst}: {msg}")
            elif kind == "activate":
                _, target = entry
                output.append(f"      activate {target}")
            elif kind == "deactivate":
                _, target = entry
                output.append(f"      deactivate {target}")

        
        output.append("    end\n")

    output.append("```")
    return "\n".join(output)

mermaid_init_config = """%%{ init: {
  'sequence': { 'showSequenceNumbers': true },
  'fontSize': '28px',
  'themeVariables': {
    'fontSize': '28px',
    'fontFamily': 'monospace',
    'textAlign': 'center',
    'wrap': true
  }
} }%%
"""

pip_diagram = {
    "participants": [
        ("Package Author", "Author", ["File", "Static Check", "Runtime"]),
        ("Package User", "User", ["File External", "Store", "Static Check", "Runtime"])
    ],
    "steps": [
        {
            "action": "Package Create",
            "notes_anchor": ["AuthorFile"],
            "plans": [
                ("note", "AuthorFile", "🧾 source code (std 1.1)"),
                ("operation", "AuthorFile", "AuthorFile", "prepare source, metadata (setup.py, requirements.txt)"),
                ("note", "AuthorFile", "📦 std 1.1")
            ]
        },
        {
            "action": "Package Deliver",
            "notes_anchor": ["AuthorFile", "UserFileExternal"],
            "plans": [
                ("note", "AuthorFile", "📦 std 1.1"),
                ("operation", "AuthorFile", "UserFileExternal", "transfer wheel/sdist"),
                ("note", "UserFileExternal", "📦 std 1.1")
            ]
        },
        {
            "action": "Package Install",
            "notes_anchor": ["UserFileExternal", "UserStore"],
            "plans": [
                ("note", "UserFileExternal", "📦 std 1.1"),
                ("operation", "UserFileExternal", "UserStore", "install wheel -> `site-packages/std`"),
                ("note", "UserStore", "📦 std 1.1")
            ]
        },
        {
            "action": "Package Load",
            "notes_anchor": ["UserStore", "UserRuntime"],
            "plans": [
                ("note", "UserRuntime", "🧾🔖 user code"),
                ("note", "UserStore", "📦 std 1.1"),
                ("note_span", ["UserStore", "UserRuntime"], "Package LUse"),
                ("operation", "UserRuntime", "UserStore", "load module `std`"),
                ("activate", "UserRuntime"),
                ("note", "UserStore", "📘 module std (1.1)"),
                ("operation", "UserStore", "UserRuntime", "provide module `std`"),
                ("note", "UserRuntime", "📖 module std (1.1)"),
                ("deactivate", "UserRuntime")
            ]
        }
    ]
}

opam_diagram = {
    "participants": [
        ("Package Author", "Author", ["File", "Static Check", "Runtime"]),
        ("Package User", "User", ["File External", "Store", "Static Check", "Runtime"])
    ],
    "steps": [
        {
            "action": "Package Create",
            "notes_anchor": ["AuthorFile"],
            "plans": [
                ("note", "AuthorFile", "🧾 source code (std 1.1)"),
                ("operation", "AuthorFile", "AuthorFile", "write opam file, dune file, and source"),
                ("note", "AuthorFile", "📦 std 1.1")
            ]
        },
        {
            "action": "Package Deliver",
            "notes_anchor": ["AuthorFile", "UserFileExternal"],
            "plans": [
                ("note", "AuthorFile", "📦 std 1.1"),
                ("operation", "AuthorFile", "UserFileExternal", "deliver source tree with opam metadata"),
                ("note", "UserFileExternal", "📦 std 1.1")
            ]
        },
        {
            "action": "Package Install",
            "notes_anchor": ["UserFileExternal", "UserStore"],
            "plans": [
                ("note", "UserFileExternal", "📦 std 1.1"),
                ("operation", "UserFileExternal", "UserStore", "pin and store source tree"),
                ("note", "UserStore", "📦 std 1.1")
            ]
        },
        {
            "action": "Package Load",
            "notes_anchor": ["UserStore", "UserStaticCheck"],
            "plans": [
                ("note", "UserStaticCheck", "🧾🔖 user code"),
                ("note", "UserStore", "📦 std 1.1"),
                ("operation", "UserStaticCheck", "UserStore", "read opam + dune metadata"),
                ("note", "UserStore", "📘 module std (1.1)"),
                ("operation", "UserStore", "UserStaticCheck", "provide module `std`"),
                ("note", "UserStaticCheck", "📚 module std (1.1)")
            ]
        },
        {
            "action": "Package Use",
            "notes_anchor": ["UserRuntime"],
            "plans": [
                ("activate", "UserRuntime"),
                ("operation", "UserRuntime", "UserRuntime", "use module `std`"),
                ("note", "UserRuntime", "📖 module std (1.1)"),
                ("deactivate", "UserRuntime")
            ]
        }
    ]
}

# Export to doc files
os.makedirs("doc", exist_ok=True)
with open("doc/pip.mmd", "w", encoding="utf-8") as f:
    f.write(print_mermaid(pip_diagram, config=mermaid_init_config))

with open("doc/opam.mmd", "w", encoding="utf-8") as f:
    f.write(print_mermaid(opam_diagram, config=mermaid_init_config))
