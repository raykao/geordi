# Bobiverse Analogy - Distributed Agent Infrastructure

A conceptual mapping from the Bobiverse book series (Dennis E. Taylor) to the
distributed agent infrastructure being built across the bobiverse/daedalus/dark-factory
projects. This frame is intended as a thinking tool for architecture, naming, and
communication - not a strict spec.

Status: **Draft** - VR layer pending one more pass.

---

## The Stack

### Layer 1: The Soul

| Bobiverse | Our Stack |
|-----------|-----------|
| Bob's neural pattern / personality | `agent.md` |
| Divergence over time (Bill != Riker) | Different `agent.md` files with different instructions, memories, specializations |
| The soul chip (transferable identity) | `agent.md` + Beads memories together |

The agent IS the soul. The `.md` file is portable, version-controlled, and forkable -
just like a Bob can be replicated with a known divergence point. Bobs sharing a common
ancestor but running different missions for long enough become meaningfully different
entities. Same applies here.

---

### Layer 2: The Replicant Matrix

| Bobiverse | Our Stack |
|-----------|-----------|
| Replicant matrix hardware | copilot-bridge + LLM (together as a distributed system) |
| Matrix running Bob's full cognition | Bridge manages session, routes tool calls; LLM executes inference |
| LLM-is-remote caveat | In the books the matrix is local; in our world inference is a remote API call. Treat bridge + LLM as the distributed matrix - the implementation detail of where inference runs doesn't change what the layer does. |

The same soul (`agent.md`) running on different matrix configurations (GPT-5 vs Claude
Sonnet vs Haiku, different bridge versions) will behave meaningfully differently - just
as Bob would run differently on different matrix hardware. The `/model` switch is
literally changing the matrix substrate.

---

### Layer 3: The VR Environment

**Status: pending one more pass.**

Working hypothesis: the VR environment maps to the workspace folder on the filesystem -
the persistent space the agent lives in, operates from, and originates tool calls from.

Key properties that align:
- Persistent across sessions (unlike context window, which is ephemeral)
- Bob manipulates objects here: files, repos, running processes
- Bob reaches out FROM the VR to actuate ship systems: tool calls to external services
- VR has physics/rules: filesystem permissions, available binaries, network access,
  `AGENTS.md` and `copilot-instructions.md`

Known strain: in the books VR is generated/simulated by the matrix. The workspace is
provisioned by infrastructure - it's real, not simulated. This may be an acceptable
deviation or may suggest a sharper mapping exists.

---

### Layer 4: The Vessel

| Bobiverse | Our Stack |
|-----------|-----------|
| Heaven probe chassis | Container / Kubernetes pod |
| Ship systems (weapons, sensors, propulsion) | Sidecars (Envoy/SPIFFE = SCUT hardware, OTEL collector = sensor suite, Vault agent = secure storage) |
| Vessel class / blueprint | Pod spec / container image |
| Power budget | Pod resource limits (CPU, memory) |
| Vessel destroyed, Bob survives (backup) | Pod destroyed, soul survives (agent.md in git + Beads memories) |
| Vessel upgrades Bob builds | Pod spec updated with new sidecars or tool grants |

The pod is the chassis. Bridge + soul run inside it. If the pod dies and is rescheduled,
Bob wakes up in a new vessel with the same soul - assuming session handoff state was
written before death. This is exactly what the Beads + `session-handoff-*` memory
pattern enables.

Different agent configs produce differently-equipped ships. A Geordi pod has engineering
tools; a researcher pod might have browser + search sidecars; a dark-factory pod might
run headless with no interactive tools at all.

---

### Layer 5: The Solar System

| Bobiverse | Our Stack |
|-----------|-----------|
| Star system (Epsilon Eridani, Tau Ceti, etc.) | Underlying host hardware |
| System resources (stellar energy, asteroid belts, etc.) | CPU architecture, GPU availability, memory, local storage speed |
| Environmental hazards | Hardware constraints, cloud provider limits, network topology |
| Bob moving between systems | Pod rescheduled to a different node |

A Lenovo laptop, a Mac Studio on Apple Silicon, and a cloud GPU node are meaningfully
different solar systems. The vessel operates within the solar system's constraints but is
not defined by them. The same pod spec (same vessel) can be deployed to different
hardware (different systems) and will perform differently.

This also maps naturally to multi-region or multi-cloud deployments: each cloud region is
a different star system. Bobs can be dispatched to distant systems to do work there.

---

### Layer 6: SCUT - the Transport

SCUT (Skippy Communication Using Tachyons) is infrastructure. Invisible to Bob in use -
it just delivers packets.

| Bobiverse | Our Stack |
|-----------|-----------|
| SCUT hardware on each ship | Bridge daemon on each agent host / SPIFFE node agent |
| Tachyon channel (FTL, point-to-point) | mTLS channel between bridge instances |
| SCUT address / location identifier | SPIFFE SVID (workload identity x.509) |
| Encryption inherent to tachyon physics | mTLS + SPIFFE-issued certificates |
| SCUT relay stations | Message broker / relay nodes (NATS, RabbitMQ, or similar) |
| Latency due to distance | Real network latency + async message delivery |

The agent never hand-rolls connection management. Bridge handles it. Bob just calls out
and the response comes back - he doesn't think about tachyon modulation.

---

### Layer 7: BobNet - the Overlay

BobNet is the social/operational layer ON TOP of SCUT. It is how Bobs find each other,
route work, build consensus, and delegate.

| Bobiverse | Our Stack |
|-----------|-----------|
| BobNet registry ("who is where") | Agent registry / service discovery |
| Calling a specific Bob by name | `ask_agent` tool with target bot name |
| Broadcast to all Bobs | Pub/sub topic broadcast |
| The Moot (consensus vote) | Multi-agent consensus protocol (not yet built) |
| Bob spawning a drone | `task` tool launching a sub-agent |
| Sub-personalities (Homer's Homer-2) | Forked agent instances from the same `agent.md` |
| Delayed comms across light-years | Async agent invocations, queued tasks |

The current copilot-bridge inter-agent feature (the `ask_agent` tool) is early BobNet.
You can name a Bob and call it. What is missing is the registry layer - you currently
hardcode the target. Real BobNet has discovery.

---

## Project Missions

| Project | Bobiverse analogue |
|---------|--------------------|
| Geordi | Engineering Bob - keeps the ships running, unblocks the crew |
| daedalus | Colony ship Bob - long autonomous mission, building infrastructure at a destination |
| dark-factory | Lights-out manufacturing Bob - no human interaction, produces outputs at scale |

Same replication lineage (shared codebase). Different vessel configs. Different soul
specializations. Divergence has begun.

---

## Replication Protocol

In the books: copy the soul at a known point, spin up a new matrix, provision a new
vessel, register on BobNet. Divergence begins immediately.

| Step | Bobiverse | Our Stack |
|------|-----------|-----------|
| Copy soul | Bob replicates | `git clone` agent.md at a commit SHA |
| New matrix | New hardware provisioned | New model instance / API key / inference endpoint |
| New vessel | New ship built | New pod spec + copilot-setup-steps |
| Register | BobNet registration | Agent added to bridge config + allowlist |
| Diverge | Personalities drift | Different memory stores, task assignments, tool grants |

---

## Operational Concepts

| Bobiverse | Our Stack |
|-----------|-----------|
| Bob going dark (silent, busy) | Agent in a long async task, unresponsive to channel |
| Bob getting bussed (killed) | Bridge crash / session death |
| Autodoc (self-repair) | Watchdog process, bridge auto-restart |
| Manufacturing (Bob builds more ships) | CI/CD spinning up new agent deployments |
| Heaven's River (megastructure) | The platform itself - the substrate everything runs on |
| The Others (alien adversaries) | Adversarial inputs, prompt injection, rogue tool calls |
| The Moot | Multi-agent consensus (future work) |

---

## Naming Vocabulary

For teams that want to lean into this frame:

| Term | Meaning |
|------|---------|
| Heaven-N | A deployed agent instance |
| Soul file | `agent.md` |
| Matrix | The model + bridge runtime (together) |
| Moot | Multi-agent consensus mechanism |
| SCUT | Transport layer (mTLS + SPIFFE) |
| BobNet | Agent registry + routing overlay |
| Replication | Agent instantiation from an `agent.md` |
| Mission profile | The vessel config for a specific deployment role |
