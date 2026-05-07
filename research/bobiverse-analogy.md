# Bobiverse Analogy - Distributed Agent Infrastructure

A conceptual mapping from the Bobiverse book series (Dennis E. Taylor) to the
distributed agent infrastructure being built across the bobiverse/daedalus/dark-factory
projects. This frame is intended as a thinking tool for architecture, naming, and
communication - not a strict spec.

Status: **Current**

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
| Replicant matrix hardware | The LLM (the raw intelligence substrate - runs Bob's cognition) |
| Switching matrix hardware | Switching model providers (GPT-5 vs Claude Sonnet vs Haiku) |
| Matrix is remote from the vessel | LLM inference is a remote API call - the intelligence runs in a data center, not in the pod |

The same soul (`agent.md`) running on different matrix hardware will behave meaningfully
differently - just as Bob would. The `/model` switch is literally changing the matrix
substrate at runtime.

---

### Layer 2b: GUPPI - the Peripheral Interface

GUPPI (General Unit Primary Peripheral Interface) is the AI system that mediates between
Bob's consciousness and the ship's physical systems. It is distinct from Bob - it handles
the interface layer so Bob can focus on thinking.

| Bobiverse | Our Stack |
|-----------|-----------|
| GUPPI | copilot-bridge |
| GUPPI connecting Bob's mind to ship systems | Bridge connecting LLM to tools, filesystem, comms |
| Bob issuing a command, GUPPI executing it | Agent deciding to call a tool, bridge dispatching it |
| GUPPI managing ship telemetry | Bridge managing session state, context window, memory injection |
| GUPPI as a distinct AI from Bob | Bridge is distinct from the LLM - it is the harness, not the intelligence |
| AMI (Artificial Machine Intelligence) | The class of agent harness systems (copilot-bridge, claude code, etc. are all AMIs) |

The "General Unit Primary Peripheral Interface" name maps almost literally: bridge is the
interface between the agent (general unit) and its peripherals (tools, filesystem, SCUT,
BobNet). Bob doesn't think about how tool calls are dispatched - he just asks GUPPI.

---

### Layer 3: The VR Environment

| Bobiverse | Our Stack |
|-----------|-----------|
| VR environment (Bob's digital world) | OS + filesystem + workspace folder |
| Bob's sense of place / embodiment | The persistent workspace that survives session death |
| Objects Bob manipulates | Files, repos, running processes, configs |
| Bob reaching out from VR to actuate ship systems | Tool calls originating from the workspace |
| VR physics / laws | Filesystem permissions, available binaries, network access, `AGENTS.md`, `copilot-instructions.md` |
| Bob's eyes | Playwright - perceiving rendered visual reality |
| Bob's hands reaching into the external world | REST API calls, `bash` write ops |
| Bob's touch / local sensing | `view`, `grep`, `glob` - reading the local environment |
| Bob's memory beyond a single moment | `bd remember` - persisting experience across sessions |

The VR exists to give Bob *a place to be* and *a way to act* in a world where he no
longer has a physical body. The OS/workspace does exactly that for the agent.

The one apparent strain - VR is simulated, workspace is real - dissolves under scrutiny.
For Bob there is no distinction between simulated and real: the VR IS his reality. He has
no other. The same is true for the agent: the filesystem IS its world, not a simulation
of something else. They share the same ontological status. The analogy holds on the
dimension that matters: embodiment in a digital landscape.

---

### Layer 4: The Vessel

| Bobiverse | Our Stack |
|-----------|-----------|
| Von Neumann probe chassis | Container / Kubernetes pod |
| Ship systems (weapons, sensors, propulsion) | Sidecars (Envoy/SPIFFE = SCUT hardware, OTEL collector = SUDDAR suite, Vault agent = secure storage) |
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

### Layer 4b: The Von Neumann Platform

The von Neumann probe is self-replicating - it can manufacture new probes from local
materials. This is the defining property that elevates it above a simple spacecraft. In
our world, that self-replication capability is the orchestration platform.

| Bobiverse | Our Stack |
|-----------|-----------|
| Von Neumann replication capability | Kubernetes / container orchestrator |
| Bob deciding to replicate | CI/CD pipeline triggered to instantiate a new Bob |
| Probe manufacturing a new probe from local materials | Orchestrator scheduling a new pod from a spec |
| Fleet of probes under coordination | Multi-agent deployment across a cluster |
| Bob as fleet commander coordinating his replicants | Orchestrator agent (e.g. daedalus) directing sub-agents |

The orchestration platform is what makes a single Bob into a civilization. Without it,
you have one agent. With it, you have a self-propagating network.

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

SCUT (Subspace Communications Universal Transceiver) is infrastructure. Invisible to Bob
in use - it just delivers packets.

| Bobiverse | Our Stack |
|-----------|-----------|
| SCUT hardware on each ship | Bridge daemon on each agent host / SPIFFE node agent |
| Subspace channel (point-to-point) | mTLS channel between bridge instances |
| SCUT address / location identifier | SPIFFE SVID (workload identity x.509) |
| Encryption inherent to subspace physics | mTLS + SPIFFE-issued certificates |
| SCUT relay stations | Message broker / relay nodes (NATS, RabbitMQ, or similar) |
| Latency due to distance | Real network latency + async message delivery |

The agent never hand-rolls connection management. Bridge handles it. Bob just calls out
and the response comes back - he doesn't think about subspace channel management.

---

### Layer 7: SUDDAR - Sensors and Observability

SUDDAR (Subspace Deformation Detection and Ranging) is Bob's sensor suite - how he
perceives what is happening in the space around him beyond his immediate VR environment.

| Bobiverse | Our Stack |
|-----------|-----------|
| SUDDAR array on the vessel | Observability sidecar (OTEL collector) |
| Detecting objects at range | Distributed tracing - seeing what is happening across the system |
| Signal strength / resolution | Metric granularity, trace sampling rate |
| SUDDAR sweep / active scan | On-demand profiling, log query |
| Passive SUDDAR listening | Continuous metric scraping (Prometheus) |
| Signature analysis (what IS that object?) | Log analysis, anomaly detection |
| Blind spots / sensor shadows | Gaps in instrumentation, untraced code paths |

SUDDAR is what separates a Bob who knows what is happening from one flying blind. Same
applies to agents: without observability, you have no idea what the agent is actually
doing at scale.

---

### Layer 8: BobNet - the Overlay

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
| Von Neumann replication (Bob builds more probes) | CI/CD spinning up new agent deployments |
| The megastructure (vast engineered environment) | The platform itself - the substrate everything runs on |
| The Others (alien adversaries) | Adversarial inputs, prompt injection, rogue tool calls |
| The Moot | Multi-agent consensus (future work) |

---

## Naming Vocabulary

For teams that want to lean into this frame:

| Term | Meaning |
|------|---------|
| Soul file | `agent.md` |
| Matrix | The LLM (intelligence substrate) |
| GUPPI | copilot-bridge (the peripheral interface between intelligence and tools) |
| AMI | The class of agent harness systems (copilot-bridge, claude code, etc.) |
| Von Neumann platform | Container orchestrator (Kubernetes) - manages instantiation and replication |
| Moot | Multi-agent consensus mechanism |
| SCUT | Transport layer (Subspace Communications Universal Transceiver - mTLS + SPIFFE) |
| SUDDAR | Observability stack (Subspace Deformation Detection and Ranging - OTEL + Prometheus + tracing) |
| BobNet | Agent registry + routing overlay |
| Replication | Agent instantiation from an `agent.md` |
| Mission profile | The vessel config for a specific deployment role |
