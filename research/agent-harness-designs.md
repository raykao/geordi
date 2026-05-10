# Agent Harness Designs - Research Document
*Generated: 2025-07-06*

## Overview

### What is an Agent Harness?

An **agent harness** is the software infrastructure that manages, coordinates, and interfaces one or more LLM-powered agents with their environment, tools, and each other. It is the orchestration layer between raw model capability and practical execution -- the "runtime" that turns an LLM from a text-completion engine into a goal-pursuing system.

The harness is responsible for:

- **Lifecycle management**: initializing, running, pausing, and terminating agents
- **Tool orchestration**: registering tools, routing tool calls, collecting results
- **State tracking**: maintaining conversation history, memory, and intermediate results
- **Control flow**: deciding when to loop, branch, delegate, or terminate
- **Policy enforcement**: guardrails, rate limits, token budgets, safety checks
- **Observability**: logging, tracing, step-by-step audit trails

The harness is distinct from the agent itself. The agent is the reasoning component (typically an LLM with a system prompt). The harness is the code that wraps, invokes, and governs that reasoning component. A well-designed harness is agent-agnostic: you should be able to swap the LLM (GPT-4, Claude, Gemini, Llama) without rewriting the harness.

### Why It Matters

Without a harness, an LLM is stateless and reactive -- it answers one prompt at a time. The harness is what gives an LLM the ability to:

1. Pursue multi-step goals (loop until done)
2. Use external tools (function calling, APIs, code execution)
3. Maintain context across turns (memory, state)
4. Collaborate with other agents (delegation, messaging)
5. Operate safely (budgets, guardrails, human-in-the-loop checkpoints)

Every production agent system -- from a simple chatbot with tool access to a multi-agent research pipeline -- has a harness, whether explicit (a framework like LangGraph) or implicit (a while loop in a script).

### How the 6 Patterns Form a Taxonomy

These six harness patterns form a spectrum along two axes: **control flow complexity** and **agent autonomy**.

```
Low Autonomy                                              High Autonomy
     |                                                          |
     v                                                          v
 [General Purpose] --> [Specialized] --> [DAG] --> [Hierarchical] --> [Multi-Agent] --> [Autonomous]
     ^                      ^              ^            ^                  ^                ^
  Simple loop          Constrained     Structured    Delegated        Collaborative    Self-directed
  Single agent         Single agent    Multi-step    Multi-level      Peer agents      Goal-driven
```

The patterns are not mutually exclusive. Real systems often compose them: a Hierarchical harness might use DAG workflows internally, with each worker being a Specialized agent. The taxonomy helps you identify which pattern dominates your design and what tradeoffs you are accepting.

### Quick Comparison Table

| Pattern | Control Flow | Autonomy Level | Best For | Example Framework |
|---------|-------------|----------------|----------|-------------------|
| General Purpose | Linear loop (reason-act-observe) | Low-Medium | Chatbots, tool-using assistants, general Q&A | OpenAI Assistants, LangChain AgentExecutor |
| Specialized | Constrained loop with domain rules | Low | Domain-specific tasks (medical, legal, finance) | Semantic Kernel, custom RAG pipelines |
| Autonomous | Self-directed goal loop | High | Open-ended research, exploration, creative tasks | AutoGPT, BabyAGI, Claude Code |
| Hierarchical | Tree (orchestrator delegates to workers) | Medium-High | Complex decomposable tasks, enterprise workflows | CrewAI (hierarchical), Google ADK, Anthropic orchestrator-worker |
| Multi-Agent | Peer-to-peer or conversation-based | Medium-High | Debate, review, collaborative writing, simulation | AutoGen, CrewAI, LangGraph multi-agent |
| DAG | Directed acyclic graph (structured pipeline) | Low-Medium | Data pipelines, ETL, deterministic multi-step workflows | LlamaIndex Workflows, LangGraph, Prefect/Airflow-style |

---

## 1. General Purpose Harness

### Definition

The General Purpose Harness is the foundational agent pattern: a single LLM in a loop that can reason about a problem, decide to use tools, observe the results, and continue until it produces a final answer. It is the software equivalent of the ReAct (Reason + Act) paradigm.

This is the pattern most people encounter first. When someone says "I built an agent," they almost always mean a General Purpose Harness. It is the default architecture of OpenAI's Assistants API, LangChain's AgentExecutor, and the basic loop described in Anthropic's "Building Effective Agents" guide.

The key characteristic: **one agent, one loop, general-purpose tools**. The harness does not constrain what the agent can do -- it provides a tool registry and lets the LLM decide which tools to use and when to stop.

### Architecture

```
                    +------------------+
                    |   User Input     |
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |   Harness Loop   |<-----------+
                    |   Controller     |            |
                    +--------+---------+            |
                             |                      |
                             v                      |
                    +--------+---------+            |
                    |   LLM (Reason)   |            |
                    |   "What next?"   |            |
                    +--------+---------+            |
                             |                      |
                        +----+----+                 |
                        |         |                 |
                   tool_call   final_answer         |
                        |         |                 |
                        v         v                 |
               +--------+--+  +--+--------+        |
               | Tool Exec |  | Return to |        |
               | (observe) |  |   User    |        |
               +--------+--+  +-----------+        |
                        |                           |
                        +---------------------------+
                        (append observation to history)
```

### How It Works (step-by-step)

1. **Initialize**: Create a message history with the user's input and a system prompt that describes the agent's role and available tools.
2. **Invoke LLM**: Send the full message history to the LLM. The LLM returns either a tool call or a final text response.
3. **Parse response**: The harness inspects the LLM's output structure.
   - If it contains a **tool call**: extract the function name and arguments.
   - If it contains a **final answer**: exit the loop and return the answer to the user.
4. **Execute tool**: Call the specified function with the provided arguments. Capture the result (or error).
5. **Append observation**: Add the tool call and its result to the message history as a new turn.
6. **Loop**: Go back to step 2. The LLM now sees the tool result and can reason about it, call another tool, or produce a final answer.
7. **Termination**: The loop exits when the LLM produces a final answer, or when a safety limit is reached (max iterations, token budget, timeout).

### Key Components

- **Tool Registry**: A mapping of tool names to callable functions, with JSON Schema descriptions the LLM can read.
- **Message History**: The accumulated conversation (system prompt + user messages + assistant messages + tool results). This is the agent's "working memory."
- **Output Parser**: Logic to distinguish tool calls from final answers in the LLM's response. With function-calling APIs (OpenAI, Anthropic), this is built into the response format. With open models, you may need to parse structured text.
- **Loop Controller**: The while loop with termination conditions (max steps, token budget, error handling).
- **Error Handler**: What to do when a tool call fails (retry, tell the LLM about the error, abort).

### Real-World Implementations

| Framework | Implementation | Notes |
|-----------|---------------|-------|
| **OpenAI Assistants API** | Built-in agent loop with `requires_action` polling | The canonical cloud-hosted General Purpose Harness. The API manages the loop server-side; the client polls for tool call requests. |
| **Anthropic Claude** | Tool use with `tool_use` content blocks | Client-side loop. Claude returns tool_use blocks; the client executes tools and sends results back as `tool_result` blocks. |
| **LangChain AgentExecutor** | `AgentExecutor.invoke()` wraps the ReAct loop | The original Python framework for this pattern. Now considered legacy in favor of LangGraph, but still widely used. |
| **Semantic Kernel** | `Kernel` with auto-function-calling | Microsoft's framework. The kernel automatically detects function call requests from the LLM and invokes registered plugins. |
| **LlamaIndex ReAct Agent** | `ReActAgent` class | Implements the classic ReAct paper's reason/act/observe cycle with LlamaIndex's tool abstractions. |

### Code Skeleton (Python pseudocode)

```python
import json
from dataclasses import dataclass, field
from typing import Any, Callable

@dataclass
class Tool:
    name: str
    description: str
    parameters_schema: dict
    function: Callable[..., str]

@dataclass
class Message:
    role: str          # "system", "user", "assistant", "tool"
    content: str
    tool_call_id: str | None = None
    tool_calls: list | None = None

class GeneralPurposeHarness:
    def __init__(self, llm_client, system_prompt: str, tools: list[Tool],
                 max_iterations: int = 10):
        self.llm = llm_client
        self.tools = {t.name: t for t in tools}
        self.max_iterations = max_iterations
        self.messages: list[Message] = [
            Message(role="system", content=system_prompt)
        ]

    def _build_tool_schemas(self) -> list[dict]:
        return [
            {
                "type": "function",
                "function": {
                    "name": t.name,
                    "description": t.description,
                    "parameters": t.parameters_schema,
                }
            }
            for t in self.tools.values()
        ]

    def run(self, user_input: str) -> str:
        self.messages.append(Message(role="user", content=user_input))

        for step in range(self.max_iterations):
            # 1. Call LLM with full history + tool definitions
            response = self.llm.chat(
                messages=self.messages,
                tools=self._build_tool_schemas(),
            )

            assistant_msg = response.message
            self.messages.append(assistant_msg)

            # 2. Check if the LLM wants to call a tool
            if not assistant_msg.tool_calls:
                # Final answer -- return it
                return assistant_msg.content

            # 3. Execute each tool call
            for tool_call in assistant_msg.tool_calls:
                fn_name = tool_call.function.name
                fn_args = json.loads(tool_call.function.arguments)

                tool = self.tools.get(fn_name)
                if tool is None:
                    result = f"Error: unknown tool '{fn_name}'"
                else:
                    try:
                        result = tool.function(**fn_args)
                    except Exception as e:
                        result = f"Error: {e}"

                # 4. Append tool result to history
                self.messages.append(Message(
                    role="tool",
                    content=result,
                    tool_call_id=tool_call.id,
                ))

        return "Error: max iterations reached without a final answer."
```

### Tradeoffs

**Strengths:**

- Simple to understand, implement, and debug
- Flexible: the LLM decides tool usage dynamically
- Works well for 80% of use cases (chatbots, assistants, Q&A)
- Easy to add new tools without changing the harness

**Weaknesses:**

- **No planning**: the LLM reasons one step at a time. It can get stuck in loops or take inefficient paths.
- **Context window pressure**: every tool call and result accumulates in the message history. Long tasks can blow the context window.
- **Single point of failure**: one LLM does all the reasoning. If it hallucinates a tool name or argument, the whole loop can derail.
- **Cost scales with steps**: each iteration is a full LLM call with the entire history. A 10-step task costs 10x a single call.

**Failure modes:**

- Infinite loops (agent keeps calling the same tool with the same arguments)
- Tool argument hallucination (agent invents parameters that don't match the schema)
- Premature termination (agent gives a final answer before gathering enough information)
- Context overflow (history exceeds the model's context window)

### When to Use / Avoid

**Use when:**

- The task is open-ended but bounded (answer a question, complete a form, look up information)
- You need flexibility in tool selection (the agent should decide what to do)
- The task typically completes in fewer than 10 tool calls
- You are building a general-purpose assistant or chatbot

**Avoid when:**

- The task has a known, fixed sequence of steps (use a DAG or workflow instead)
- You need multiple specialized experts (use Hierarchical or Multi-Agent)
- The task requires long-running autonomous exploration (use Autonomous)
- Latency is critical (each loop iteration adds latency)

### Article Angle

The General Purpose Harness is the "Hello World" of agent architecture. An article about it should demystify what happens inside the loop that makes an LLM feel "agentic." The angle: **"Your agent is just a while loop"** -- showing readers that the magic of tool-using agents is surprisingly simple mechanically, and that the real engineering challenge is in the details (error handling, context management, termination conditions). Walk through building one from scratch without a framework, then show how frameworks like OpenAI Assistants or LangChain abstract the same loop.

---

## 2. Specialized Harness

### Definition

A Specialized Harness is a General Purpose Harness that has been deliberately constrained for a specific domain, task type, or workflow. Instead of giving the LLM open-ended tool access and letting it figure things out, the Specialized Harness enforces domain-specific rules, restricts the tool set, adds validation layers, and shapes the agent's behavior through structured prompts and guardrails.

The key distinction from the General Purpose Harness: **the harness itself encodes domain knowledge**, not just the prompt. The control flow may include domain-specific preprocessing (query classification, entity extraction), postprocessing (output validation, compliance checks), and constrained tool routing (the agent can only use approved tools in approved sequences).

This pattern is what Anthropic calls "workflows" in their "Building Effective Agents" guide: systems where LLMs and tools are orchestrated in **predefined code paths** rather than letting the LLM drive everything dynamically.

### Architecture

```
                    +------------------+
                    |   User Input     |
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    | Input Enrichment |  <-- domain-specific parsing,
                    | (classify, parse)|      entity extraction, validation
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |  Domain Router   |  <-- deterministic routing based
                    |  (rule-based)    |      on input classification
                    +--------+---------+
                             |
                    +--------+--------+
                    |                 |
                    v                 v
           +-------+------+  +------+-------+
           | Workflow A   |  | Workflow B   |  <-- each workflow is a
           | (constrained |  | (constrained |      constrained sub-loop
           |  tool set)   |  |  tool set)   |      with specific tools
           +-------+------+  +------+-------+
                    |                 |
                    v                 v
                    +--------+--------+
                             |
                    +--------+---------+
                    | Output Validator |  <-- domain rules, compliance,
                    | (post-process)   |      formatting, safety checks
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |   User Output    |
                    +------------------+
```

### How It Works (step-by-step)

1. **Input enrichment**: The harness preprocesses the user's input with domain-specific logic -- classifying intent, extracting entities, normalizing terminology. This is deterministic code, not LLM reasoning.
2. **Route to workflow**: Based on the classification, the harness routes to a specific sub-workflow. Each workflow has its own constrained tool set and prompt template.
3. **Constrained agent loop**: Within the selected workflow, the LLM operates in a loop similar to the General Purpose Harness, but with a restricted tool set and domain-specific system prompt. The harness may also inject retrieved context (RAG) at this stage.
4. **Output validation**: Before returning the result to the user, the harness validates the output against domain rules (e.g., "medical responses must include a disclaimer," "financial calculations must be verified against a reference," "legal citations must be real").
5. **Fallback handling**: If validation fails or the agent cannot complete the task within the constrained workflow, the harness can escalate to a human, retry with a different workflow, or return a structured error.

### Key Components

- **Intent Classifier**: Deterministic or ML-based routing layer that categorizes user input before the LLM sees it.
- **Domain Prompt Templates**: Pre-written system prompts tailored to specific task types (not a generic "you are a helpful assistant").
- **Constrained Tool Sets**: Each workflow exposes only the tools relevant to that domain. A medical Q&A workflow gets access to a drug database but not a code executor.
- **RAG Pipeline**: Retrieval-augmented generation is almost always present in specialized harnesses, providing domain-specific context.
- **Output Validators**: Post-processing rules that check format, compliance, accuracy, and safety before the response reaches the user.
- **Guardrails**: Hard limits on what the agent can say or do (content filters, PII redaction, citation requirements).

### Real-World Implementations

| Framework | Implementation | Notes |
|-----------|---------------|-------|
| **Anthropic prompt chaining + routing** | Composing simple LLM calls with deterministic routing | Anthropic's recommended approach for production. Each step is a focused LLM call, not an open-ended agent loop. |
| **Semantic Kernel** | Kernel + Plugins + Planner | Microsoft's framework. Plugins are domain-specific skill sets; the Planner decomposes goals into plugin calls. |
| **LlamaIndex RAG Pipelines** | QueryEngine + ResponseSynthesizer | Specialized for retrieval-heavy domains. The harness manages chunking, retrieval, reranking, and synthesis. |
| **AWS Bedrock Agents** | Action groups with constrained tool definitions | Cloud-hosted specialized agents with IAM-controlled tool access. |
| **Custom enterprise agents** | Most production agents are specialized | Banks, hospitals, law firms build custom harnesses with strict domain rules rather than using general-purpose frameworks. |

### Code Skeleton (Python pseudocode)

```python
from dataclasses import dataclass
from enum import Enum
from typing import Protocol

class TaskType(Enum):
    MEDICAL_QA = "medical_qa"
    DRUG_INTERACTION = "drug_interaction"
    SYMPTOM_TRIAGE = "symptom_triage"
    UNKNOWN = "unknown"

class OutputValidator(Protocol):
    def validate(self, output: str, task_type: TaskType) -> tuple[bool, str]: ...

@dataclass
class DomainWorkflow:
    task_type: TaskType
    system_prompt: str
    tools: list          # constrained tool set for this workflow
    validators: list[OutputValidator]
    max_iterations: int = 5

class SpecializedHarness:
    def __init__(self, llm_client, classifier, retriever,
                 workflows: dict[TaskType, DomainWorkflow]):
        self.llm = llm_client
        self.classifier = classifier      # intent classification model/rules
        self.retriever = retriever         # domain knowledge retrieval
        self.workflows = workflows

    def _classify_intent(self, user_input: str) -> TaskType:
        """Deterministic or ML-based intent classification."""
        return self.classifier.classify(user_input)

    def _retrieve_context(self, user_input: str, task_type: TaskType) -> str:
        """RAG: retrieve relevant domain documents."""
        docs = self.retriever.search(user_input, filters={"domain": task_type.value})
        return "\n".join(doc.text for doc in docs)

    def _run_workflow(self, workflow: DomainWorkflow,
                      user_input: str, context: str) -> str:
        """Run a constrained agent loop within the domain workflow."""
        messages = [
            {"role": "system", "content": workflow.system_prompt},
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {user_input}"},
        ]

        for _ in range(workflow.max_iterations):
            response = self.llm.chat(
                messages=messages,
                tools=[t.schema for t in workflow.tools],
            )
            if not response.tool_calls:
                return response.content

            # Execute constrained tool calls
            for call in response.tool_calls:
                tool = next((t for t in workflow.tools if t.name == call.name), None)
                if tool is None:
                    raise ValueError(f"Tool '{call.name}' not in workflow tool set")
                result = tool.execute(**call.arguments)
                messages.append({"role": "tool", "content": result, "id": call.id})

        return "Could not complete within iteration limit."

    def _validate_output(self, output: str, workflow: DomainWorkflow) -> str:
        """Run domain-specific validators on the output."""
        for validator in workflow.validators:
            valid, corrected = validator.validate(output, workflow.task_type)
            if not valid:
                output = corrected  # apply correction or raise
        return output

    def run(self, user_input: str) -> str:
        # 1. Classify intent
        task_type = self._classify_intent(user_input)
        workflow = self.workflows.get(task_type)
        if workflow is None:
            return "I'm not able to help with that type of question."

        # 2. Retrieve domain context
        context = self._retrieve_context(user_input, task_type)

        # 3. Run constrained workflow
        raw_output = self._run_workflow(workflow, user_input, context)

        # 4. Validate and return
        return self._validate_output(raw_output, workflow)
```

### Tradeoffs

**Strengths:**

- **Predictable**: deterministic routing and validation make behavior more consistent
- **Safe**: domain guardrails prevent the agent from going off-script
- **Efficient**: constrained tool sets reduce the LLM's decision space, leading to fewer wasted steps
- **Auditable**: clear separation of concerns makes it easy to trace what happened and why
- **Lower cost**: fewer iterations needed when the path is constrained

**Weaknesses:**

- **Rigid**: adding new capabilities requires modifying the harness code, not just adding a tool
- **Upfront investment**: building the classifier, validators, and domain-specific prompts takes time
- **Brittle routing**: if the intent classifier gets it wrong, the agent is in the wrong workflow with the wrong tools
- **Limited generalization**: the agent cannot handle out-of-domain requests gracefully

**Failure modes:**

- Misclassification sends the user down the wrong workflow path
- Over-constrained tool sets prevent the agent from completing legitimate tasks
- Domain knowledge goes stale if the RAG corpus is not updated
- Validators reject valid outputs due to overly strict rules

### When to Use / Avoid

**Use when:**

- You are building for a specific domain with clear rules (healthcare, finance, legal, customer support)
- Compliance, safety, or auditability requirements demand predictable behavior
- You want to minimize LLM hallucination by constraining the output space
- You have domain experts who can define the workflows and validation rules

**Avoid when:**

- The task is genuinely open-ended (use General Purpose)
- You need the agent to handle a wide variety of unrelated requests
- You are prototyping and don't yet know what the domain rules should be
- The overhead of building domain-specific components is not justified by the use case

### Article Angle

The Specialized Harness is where agents go from demo to production. The article angle: **"The boring agent that actually works"** -- contrasting the excitement of general-purpose agents with the reality that most production deployments are highly constrained. Walk through converting a General Purpose Harness into a Specialized one for a specific domain (e.g., medical triage), showing how each constraint you add (intent classification, tool restriction, output validation) makes the system more reliable but less flexible. This is the Anthropic "start with workflows, not agents" philosophy in action.

---

## 3. Autonomous Harness

### Definition

The Autonomous Harness is the pattern where the agent is given a high-level goal and operates with minimal human intervention, self-directing its own planning, execution, and iteration. Unlike the General Purpose Harness (which typically handles one user request per loop) or the Specialized Harness (which follows constrained workflows), the Autonomous Harness features **goal decomposition, persistent memory, and self-correction loops**.

This is the pattern that captured the public imagination in 2023 with AutoGPT and BabyAGI. The agent does not just respond to prompts -- it maintains a task queue, creates sub-goals, executes them, evaluates progress, and adjusts its plan. It is the closest software analogy to a human working independently on a project.

The key characteristic: **the agent drives its own agenda**. The harness provides the infrastructure (memory, tool access, planning scaffolding), but the LLM decides what to do, when to do it, and when it is done.

### Architecture

```
                    +------------------+
                    |   User Goal      |
                    |   (high-level)   |
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |   Goal Decomposer|  <-- LLM breaks goal into sub-tasks
                    |   (Planner)      |
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |   Task Queue     |  <-- priority queue of sub-tasks
                    |   (persistent)   |
                    +--------+---------+
                             |
                    +--------+---------+
                    |  Execution Loop  |<-----------+
                    +--------+---------+            |
                             |                      |
                             v                      |
                    +--------+---------+            |
                    |   LLM (Execute)  |            |
                    |   current task   |            |
                    +--------+---------+            |
                             |                      |
                        +----+----+                 |
                        |         |                 |
                   tool_call   task_complete         |
                        |         |                 |
                        v         v                 |
               +--------+--+  +--+-----------+     |
               | Tool Exec |  | Evaluator    |     |
               +--------+--+  | (assess      |     |
                        |     |  progress)    |     |
                        |     +--+-----------+     |
                        |        |                  |
                        |        v                  |
                        |     +--+-----------+     |
                        |     | Re-Planner   |     |
                        |     | (adjust plan,|     |
                        |     |  add tasks)  |     |
                        |     +--+-----------+     |
                        |        |                  |
                        +--------+------------------+
                             |
                    +--------+---------+
                    |  Long-Term Memory|  <-- vector DB, file system,
                    |  (persistent)    |      structured storage
                    +------------------+
```

### How It Works (step-by-step)

1. **Goal intake**: The user provides a high-level objective (e.g., "Research the competitive landscape for X and produce a report").
2. **Goal decomposition**: The harness asks the LLM to break the goal into a prioritized list of sub-tasks. These are stored in a persistent task queue.
3. **Task selection**: The harness picks the highest-priority incomplete task from the queue.
4. **Task execution**: The LLM executes the current task using available tools (web search, file I/O, code execution, API calls). This is a standard tool-calling loop within a single task.
5. **Result storage**: The output of each task is stored in long-term memory (vector DB, file system, or structured storage) so future tasks can reference it.
6. **Progress evaluation**: After each task completes, the harness (or a separate evaluator LLM) assesses whether the overall goal is making progress, whether the remaining task list is still correct, and whether new sub-tasks are needed.
7. **Re-planning**: Based on the evaluation, the harness may add new tasks, reprioritize existing ones, or modify the plan. This is the self-correction capability.
8. **Termination**: The loop ends when the evaluator determines the goal is achieved, when all tasks are complete, or when a hard limit (time, cost, iteration count) is reached.

### Key Components

- **Goal Decomposer / Planner**: An LLM call (or chain of calls) that converts a high-level goal into actionable sub-tasks with dependencies and priorities.
- **Task Queue**: A persistent, prioritized list of tasks. Unlike the General Purpose Harness's message history, this is a structured data store that survives across sessions.
- **Long-Term Memory**: Vector database (Chroma, Pinecone, Weaviate), file system, or structured DB that stores the results of completed tasks and any context the agent accumulates.
- **Evaluator**: A separate LLM call (or the same LLM with a different prompt) that assesses progress and decides whether to continue, re-plan, or terminate.
- **Re-Planner**: Logic that modifies the task queue based on evaluation feedback. This closes the self-correction loop.

### Real-World Implementations

| Framework | Implementation | Notes |
|-----------|---------------|-------|
| **AutoGPT** | Python CLI with LLM loop, plugin system, vector DB memory | The original viral autonomous agent (2023). Demonstrated the pattern but exposed its failure modes (cost, loops, drift). |
| **BabyAGI** | Minimal Python script: task creation, prioritization, execution | Stripped-down version of the pattern. Educational value in showing how little code is needed. |
| **Claude Code** | Anthropic's agentic coding tool | Operates autonomously on codebases: plans changes, edits files, runs tests, iterates. One of the most polished production autonomous agents. |
| **Devin (Cognition)** | Autonomous software engineer | Full-stack autonomous agent that can plan, code, debug, and deploy. Demonstrated both the promise and limits of autonomous coding agents. |
| **OpenAI Deep Research** | Long-running research agent | Given a research question, autonomously searches the web, reads sources, synthesizes findings over minutes to hours. |
| **GPT Researcher** | Open-source autonomous research agent | Decomposes research questions, searches multiple sources, synthesizes reports. |

### Code Skeleton (Python pseudocode)

```python
from dataclasses import dataclass, field
from typing import Optional
import uuid

@dataclass
class Task:
    id: str = field(default_factory=lambda: str(uuid.uuid4())[:8])
    description: str = ""
    priority: int = 0           # lower = higher priority
    status: str = "pending"     # pending, in_progress, complete, failed
    result: Optional[str] = None
    dependencies: list[str] = field(default_factory=list)

class AutonomousHarness:
    def __init__(self, llm_client, tools: list, memory_store,
                 max_total_steps: int = 50, max_cost_usd: float = 5.0):
        self.llm = llm_client
        self.tools = tools
        self.memory = memory_store           # vector DB or similar
        self.task_queue: list[Task] = []
        self.max_total_steps = max_total_steps
        self.max_cost_usd = max_cost_usd
        self.total_steps = 0
        self.total_cost = 0.0

    def _decompose_goal(self, goal: str) -> list[Task]:
        """Ask the LLM to break the goal into sub-tasks."""
        prompt = f"""Break this goal into 3-7 concrete, actionable sub-tasks.
Return as a JSON array of objects with 'description' and 'priority' (0=highest).

Goal: {goal}"""
        response = self.llm.chat([{"role": "user", "content": prompt}])
        tasks_data = parse_json(response.content)
        return [Task(description=t["description"], priority=t["priority"])
                for t in tasks_data]

    def _get_next_task(self) -> Optional[Task]:
        """Get the highest-priority pending task with satisfied dependencies."""
        completed_ids = {t.id for t in self.task_queue if t.status == "complete"}
        candidates = [
            t for t in self.task_queue
            if t.status == "pending"
            and all(dep in completed_ids for dep in t.dependencies)
        ]
        if not candidates:
            return None
        return min(candidates, key=lambda t: t.priority)

    def _execute_task(self, task: Task) -> str:
        """Run a single task using the standard tool-calling loop."""
        # Retrieve relevant context from memory
        context = self.memory.search(task.description, top_k=5)
        context_str = "\n".join(c.text for c in context)

        messages = [
            {"role": "system", "content": f"You are executing a specific task. "
             f"Use the available tools to complete it.\n\nPrior context:\n{context_str}"},
            {"role": "user", "content": task.description},
        ]

        for _ in range(10):  # per-task iteration limit
            response = self.llm.chat(messages=messages, tools=self.tools)
            self.total_steps += 1

            if not response.tool_calls:
                return response.content

            for call in response.tool_calls:
                result = execute_tool(call)
                messages.append({"role": "tool", "content": result, "id": call.id})

        return "Task execution reached iteration limit."

    def _evaluate_and_replan(self, goal: str) -> bool:
        """Assess progress and adjust the task queue. Returns True if goal is met."""
        completed = [t for t in self.task_queue if t.status == "complete"]
        pending = [t for t in self.task_queue if t.status == "pending"]

        prompt = f"""Original goal: {goal}

Completed tasks and results:
{chr(10).join(f'- {t.description}: {t.result[:200]}' for t in completed)}

Remaining tasks:
{chr(10).join(f'- {t.description}' for t in pending)}

Questions:
1. Is the goal fully achieved? (yes/no)
2. Should any new tasks be added? If so, list them.
3. Should any remaining tasks be removed or reprioritized?"""

        response = self.llm.chat([{"role": "user", "content": prompt}])
        evaluation = parse_evaluation(response.content)

        if evaluation.goal_achieved:
            return True

        # Apply re-planning
        for new_task in evaluation.new_tasks:
            self.task_queue.append(Task(description=new_task))

        return False

    def run(self, goal: str) -> str:
        # 1. Decompose goal into tasks
        self.task_queue = self._decompose_goal(goal)

        # 2. Main execution loop
        while self.total_steps < self.max_total_steps:
            task = self._get_next_task()
            if task is None:
                break

            # 3. Execute task
            task.status = "in_progress"
            task.result = self._execute_task(task)
            task.status = "complete"

            # 4. Store result in long-term memory
            self.memory.store(task.description, task.result)

            # 5. Evaluate and re-plan
            if self._evaluate_and_replan(goal):
                return self._synthesize_final_output(goal)

        return self._synthesize_final_output(goal)
```

### Tradeoffs

**Strengths:**

- **Handles complex, multi-step goals** that are too large for a single agent loop
- **Self-correcting**: the evaluation/re-planning loop lets the agent adapt when initial plans are wrong
- **Persistent memory** allows resuming work across sessions
- **Impressive demos**: when it works, it feels like magic

**Weaknesses:**

- **Expensive**: many LLM calls (decomposition + per-task execution + evaluation + re-planning). A single goal can cost dollars to tens of dollars.
- **Unreliable**: planning quality degrades with goal complexity. LLMs are mediocre planners for multi-step tasks.
- **Drift**: over many iterations, the agent can drift from the original goal, especially if re-planning introduces tangential tasks.
- **Hard to debug**: when something goes wrong 20 steps in, tracing the failure back to the root cause is difficult.
- **Safety risk**: an autonomous agent with tool access (especially code execution or web access) can cause real harm if guardrails are insufficient.

**Failure modes:**

- **Infinite re-planning**: the evaluator keeps finding the goal "not achieved" and adds more tasks indefinitely
- **Goal drift**: re-planning introduces tasks that are tangentially related but don't advance the original goal
- **Catastrophic tool use**: the agent executes a destructive action (deletes files, sends emails, makes API calls with side effects)
- **Cost explosion**: token usage grows geometrically with task count and iteration depth
- **Hallucinated progress**: the agent reports tasks as "complete" but the results are fabricated

### When to Use / Avoid

**Use when:**

- The goal genuinely requires exploration and cannot be pre-decomposed (research, creative projects)
- Human supervision is available to monitor progress and intervene
- The cost of automation is justified (the alternative is hours of human work)
- You have robust guardrails (sandboxed execution, cost limits, approval gates for destructive actions)

**Avoid when:**

- The task has a known procedure (use Specialized or DAG)
- Reliability is more important than flexibility
- You cannot afford the cost or latency of many LLM calls
- The agent has access to tools with irreversible side effects and no sandbox
- You are building for end users who cannot monitor agent behavior

### Article Angle

The Autonomous Harness is the most exciting and most dangerous pattern. The article angle: **"The agent that runs while you sleep -- and why that's terrifying"**. Tell the story of AutoGPT's viral moment (millions of GitHub stars, massive hype) followed by the sobering reality of cost, reliability, and safety problems. Then show how the pattern has matured in production systems like Claude Code and Devin, which add guardrails, sandboxing, and human checkpoints to make autonomy practical. The narrative arc: from naive autonomy to responsible autonomy.

---

## 4. Hierarchical Harness

### Definition

The Hierarchical Harness organizes agents into a tree structure where an **orchestrator agent** delegates tasks to **worker agents**, each with their own capabilities and tool sets. The orchestrator is responsible for planning, task assignment, and result synthesis. Workers are responsible for executing specific sub-tasks and reporting results.

This pattern mirrors how human organizations work: a manager decomposes a project into tasks, assigns them to specialists, reviews their output, and synthesizes the final deliverable. It is Anthropic's "Orchestrator-Workers" workflow pattern and the default architecture of CrewAI's hierarchical process.

The key distinction from the Autonomous Harness: **the orchestrator reasons about delegation, not execution**. It does not try to complete tasks itself -- it breaks them down and routes them to agents better suited for each sub-task. The key distinction from Multi-Agent: the hierarchy is explicit and fixed, not emergent.

### Architecture

```
                    +------------------+
                    |   User Request   |
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |   Orchestrator   |  <-- planning, delegation,
                    |   Agent          |      result synthesis
                    +--------+---------+
                             |
                +------------+------------+
                |            |            |
                v            v            v
         +------+---+  +----+-----+  +---+------+
         | Worker A |  | Worker B |  | Worker C |
         | (search) |  | (code)   |  | (write)  |
         +------+---+  +----+-----+  +---+------+
                |            |            |
                v            v            v
           [search tools] [sandbox]   [doc tools]
                |            |            |
                +------------+------------+
                             |
                             v
                    +--------+---------+
                    |   Orchestrator   |  <-- synthesize results,
                    |   (synthesize)   |      may re-delegate
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |   Final Output   |
                    +------------------+
```

### How It Works (step-by-step)

1. **Task intake**: The orchestrator receives a complex request from the user.
2. **Planning**: The orchestrator reasons about how to decompose the request. It identifies which worker agents are needed and what each should do.
3. **Delegation**: The orchestrator sends specific sub-tasks to worker agents. Each worker has its own system prompt, tool set, and potentially its own model (a cheaper model for simple tasks, a more capable model for complex ones).
4. **Worker execution**: Each worker operates as a self-contained agent (typically a General Purpose or Specialized Harness) to complete its assigned sub-task.
5. **Result collection**: Workers return their results to the orchestrator.
6. **Synthesis**: The orchestrator reviews the worker outputs, combines them into a coherent response, and decides whether the overall task is complete.
7. **Re-delegation** (optional): If the orchestrator identifies gaps, contradictions, or quality issues in the worker outputs, it can send follow-up tasks to the same or different workers.
8. **Final output**: The orchestrator produces the final deliverable and returns it to the user.

### Key Components

- **Orchestrator Agent**: An LLM with a planning-focused system prompt. Has access to a "delegate" tool that can invoke worker agents. Does NOT have direct access to domain tools.
- **Worker Agents**: Each is a self-contained harness (General Purpose or Specialized) with its own tool set. Workers do not communicate with each other -- only with the orchestrator.
- **Worker Registry**: A mapping of worker names/descriptions to their capabilities, so the orchestrator can make informed delegation decisions.
- **Result Aggregator**: Logic in the orchestrator for combining multiple worker outputs into a coherent whole.
- **Delegation Protocol**: The message format used between orchestrator and workers (task description, expected output format, context passing).

### Real-World Implementations

| Framework | Implementation | Notes |
|-----------|---------------|-------|
| **CrewAI (hierarchical process)** | `Crew(process=Process.hierarchical)` with a manager agent | The manager LLM decides task order, assignment, and reviews output. Workers are `Agent` instances with specific roles and tools. |
| **Google ADK** | `SequentialAgent` / `ParallelAgent` with sub-agents | Parent agents orchestrate child agents. Supports `LlmAgent`, `BaseAgent` subclasses, and workflow primitives. |
| **Anthropic Orchestrator-Workers** | Custom implementation following the pattern from "Building Effective Agents" | Not a framework -- a design pattern. The orchestrator uses tool_use to call worker functions. |
| **LangGraph** | StateGraph with supervisor node routing to worker nodes | The supervisor node uses conditional edges to delegate to specialized sub-graphs. |
| **Copilot Bridge (this system)** | Geordi orchestrator delegates to Implement, Review, and Explore sub-agents | A real-world production example. The orchestrator never writes code -- it delegates to sub-agents and manages the review-fix loop. |

### Code Skeleton (Python pseudocode)

```python
from dataclasses import dataclass
from typing import Any

@dataclass
class WorkerConfig:
    name: str
    description: str
    system_prompt: str
    tools: list
    model: str = "gpt-4o-mini"    # workers can use cheaper models

@dataclass
class DelegationResult:
    worker_name: str
    task: str
    result: str
    success: bool

class HierarchicalHarness:
    def __init__(self, orchestrator_llm, workers: list[WorkerConfig],
                 max_delegation_rounds: int = 3):
        self.orchestrator_llm = orchestrator_llm
        self.workers = {w.name: w for w in workers}
        self.max_rounds = max_delegation_rounds

    def _build_orchestrator_prompt(self) -> str:
        worker_descriptions = "\n".join(
            f"- {w.name}: {w.description}" for w in self.workers.values()
        )
        return f"""You are an orchestrator. You break tasks into sub-tasks and
delegate them to specialized workers. You NEVER do the work yourself.

Available workers:
{worker_descriptions}

To delegate, use the 'delegate' tool with the worker name and task description.
After receiving results, synthesize a final answer or delegate follow-up tasks."""

    def _run_worker(self, worker_name: str, task: str,
                    context: str = "") -> DelegationResult:
        """Run a worker agent as a self-contained sub-harness."""
        config = self.workers[worker_name]
        worker_harness = GeneralPurposeHarness(
            llm_client=get_llm(config.model),
            system_prompt=config.system_prompt,
            tools=config.tools,
        )
        try:
            result = worker_harness.run(f"{task}\n\nContext: {context}")
            return DelegationResult(worker_name, task, result, success=True)
        except Exception as e:
            return DelegationResult(worker_name, task, str(e), success=False)

    def _delegate_tool(self, worker_name: str, task: str,
                       context: str = "") -> str:
        """Tool function the orchestrator LLM can call."""
        if worker_name not in self.workers:
            return f"Error: unknown worker '{worker_name}'"
        result = self._run_worker(worker_name, task, context)
        return result.result

    def run(self, user_request: str) -> str:
        orchestrator_tools = [
            Tool(
                name="delegate",
                description="Delegate a task to a worker agent.",
                parameters_schema={
                    "type": "object",
                    "properties": {
                        "worker_name": {"type": "string",
                                        "enum": list(self.workers.keys())},
                        "task": {"type": "string"},
                        "context": {"type": "string", "default": ""},
                    },
                    "required": ["worker_name", "task"],
                },
                function=self._delegate_tool,
            )
        ]

        # Use the GeneralPurposeHarness for the orchestrator itself
        orchestrator = GeneralPurposeHarness(
            llm_client=self.orchestrator_llm,
            system_prompt=self._build_orchestrator_prompt(),
            tools=orchestrator_tools,
            max_iterations=self.max_rounds * len(self.workers),
        )
        return orchestrator.run(user_request)
```

### Tradeoffs

**Strengths:**

- **Separation of concerns**: each worker is specialized and testable in isolation
- **Cost optimization**: workers can use cheaper, faster models for simple tasks; only the orchestrator needs a high-capability model
- **Scalable**: adding a new capability means adding a new worker, not modifying the orchestrator
- **Parallel execution**: independent worker tasks can run concurrently
- **Mirrors human organization**: intuitive mental model for teams and managers

**Weaknesses:**

- **Orchestrator bottleneck**: all communication flows through the orchestrator. If it makes a bad delegation decision, the entire system fails.
- **Context loss**: workers only see the task the orchestrator gives them, not the full user request. Important nuance can be lost in translation.
- **Overhead**: the orchestrator's planning step adds latency and cost before any real work begins.
- **Fixed hierarchy**: the tree structure is rigid. You cannot easily have workers collaborating peer-to-peer without going through the orchestrator.

**Failure modes:**

- Orchestrator delegates to the wrong worker (e.g., sends a coding task to the research worker)
- Orchestrator under-specifies the task, and the worker produces irrelevant output
- Workers produce contradictory results that the orchestrator cannot reconcile
- The orchestrator tries to do the work itself instead of delegating
- Deep hierarchies (orchestrator -> sub-orchestrator -> worker) amplify context loss

### When to Use / Avoid

**Use when:**

- The task naturally decomposes into distinct, parallelizable sub-tasks
- You have clearly different capability requirements (search vs. code vs. write)
- You want to optimize cost by using different models for different sub-tasks
- The system needs to scale to many capabilities without a monolithic agent

**Avoid when:**

- The task is a single coherent flow that does not decompose well (use General Purpose)
- Workers need to collaborate iteratively (use Multi-Agent)
- The task sequence is fixed and deterministic (use DAG)
- The overhead of orchestration is not justified by the task complexity

### Article Angle

The Hierarchical Harness is the enterprise pattern. The article angle: **"Your AI agent needs a manager (and that manager is also an AI)"**. Draw the analogy between human organizational hierarchies and agent hierarchies. Show how Copilot Bridge, CrewAI, and Google ADK all implement the same fundamental pattern with different abstractions. The key insight: the orchestrator is just a General Purpose Harness whose only tool is "delegate to another agent." This recursive composition is what makes the pattern powerful and what makes it fragile (the orchestrator is a single point of failure with a hard job).

---

## 5. Multi-Agent Harness

### Definition

The Multi-Agent Harness enables multiple agents to collaborate through direct communication -- conversations, shared state, or message passing -- without a strict hierarchical relationship. Unlike the Hierarchical pattern where one agent controls the others, Multi-Agent systems feature **peer agents** that interact, debate, critique, and build on each other's work.

This is the pattern used when you want diversity of perspective: a code writer and a code reviewer, a proposer and a critic, multiple specialists working together on a shared artifact. The agents may take turns (sequential conversation), work in parallel, or engage in structured debate.

The key distinction from Hierarchical: **no fixed boss**. Agents communicate peer-to-peer, though a routing mechanism may coordinate turn-taking. The key distinction from DAG: the interaction pattern is dynamic and conversational, not a fixed pipeline.

### Architecture

```
                    +------------------+
                    |   User Request   |
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |  Conversation    |  <-- manages turn-taking,
                    |  Manager / Router|      message routing, termination
                    +--------+---------+
                             |
                    +--------+--------+--------+
                    |                 |        |
                    v                 v        v
              +-----+----+    +------+---+ +--+------+
              | Agent A  |    | Agent B  | | Agent C |
              | (writer) |    | (critic) | | (editor)|
              +-----+----+    +------+---+ +--+------+
                    |                 |        |
                    +--------+--------+--------+
                             |
                    +--------+---------+
                    |  Shared State /  |  <-- shared memory, artifacts,
                    |  Blackboard      |      conversation history
                    +------------------+
```

### How It Works (step-by-step)

1. **Initialization**: The harness creates multiple agent instances, each with a distinct role, system prompt, and potentially different tool sets.
2. **Conversation start**: The user's request is injected into a shared conversation (or sent to the first agent in the sequence).
3. **Turn-taking**: The conversation manager determines which agent speaks next. This can be:
   - **Round-robin**: agents take turns in a fixed order
   - **Role-based**: specific triggers activate specific agents (e.g., after code is written, the reviewer speaks)
   - **LLM-routed**: a routing LLM decides who should speak next based on the conversation state
   - **Self-selected**: agents decide whether they have something to contribute
4. **Agent response**: The active agent reads the conversation history (or a filtered view of it), reasons about its role, and produces a response. This response may include tool calls, critique of another agent's output, or contributions to a shared artifact.
5. **Shared state update**: The agent's response is added to the shared conversation history. If there is a shared artifact (e.g., a document being collaboratively written), it is updated.
6. **Iteration**: Steps 3-5 repeat until a termination condition is met.
7. **Termination**: The conversation ends when:
   - A consensus is reached (agents agree on a final answer)
   - A maximum number of turns is reached
   - A specific agent signals completion
   - The conversation manager detects convergence (agents are no longer making substantive changes)

### Key Components

- **Conversation Manager**: The turn-taking coordinator. Not an "orchestrator" in the hierarchical sense -- it manages logistics (who speaks next) but does not plan or assign tasks.
- **Agent Instances**: Each agent has its own identity (name, role, system prompt). They share a conversation but have independent reasoning.
- **Shared State / Blackboard**: A common data structure that all agents can read from and write to. This can be the conversation history itself, or a structured artifact (code file, document, data table).
- **Termination Detector**: Logic to decide when the conversation should end. This prevents infinite back-and-forth.
- **Message Protocol**: The format for agent-to-agent communication. Can be natural language (agents read each other's text) or structured (agents pass typed objects).

### Real-World Implementations

| Framework | Implementation | Notes |
|-----------|---------------|-------|
| **AutoGen (Microsoft)** | `GroupChat` with multiple `AssistantAgent` / `UserProxyAgent` instances | The canonical multi-agent conversation framework. Agents converse in a group chat, with a GroupChatManager handling turn-taking. |
| **CrewAI (sequential process)** | `Crew(process=Process.sequential)` with role-based agents | Agents execute in sequence, each building on the previous agent's output. The "crew" metaphor emphasizes collaboration over hierarchy. |
| **LangGraph Multi-Agent** | Multiple agent nodes in a StateGraph with message-passing edges | Flexible: can model both structured and conversational multi-agent interactions. |
| **ChatDev** | Software development simulation with CEO, CTO, Programmer, Reviewer agents | Multi-agent conversation that produces code through role-playing. Demonstrated the debate/review pattern. |
| **Camel** | Two-agent role-playing conversations | Minimal multi-agent framework focused on the proposer-critic dynamic. |

### Code Skeleton (Python pseudocode)

```python
from dataclasses import dataclass, field
from typing import Callable, Optional

@dataclass
class AgentConfig:
    name: str
    role: str
    system_prompt: str
    tools: list = field(default_factory=list)
    model: str = "gpt-4o"

@dataclass
class ConversationMessage:
    agent_name: str
    content: str
    turn: int

class MultiAgentHarness:
    def __init__(self, agents: list[AgentConfig], llm_client_factory,
                 turn_strategy: str = "round_robin",
                 max_turns: int = 10,
                 termination_fn: Optional[Callable] = None):
        self.agents = {a.name: a for a in agents}
        self.agent_order = [a.name for a in agents]
        self.llm_factory = llm_client_factory
        self.turn_strategy = turn_strategy
        self.max_turns = max_turns
        self.termination_fn = termination_fn or self._default_termination
        self.conversation: list[ConversationMessage] = []

    def _default_termination(self, conversation: list[ConversationMessage]) -> bool:
        """Check if the last message signals completion."""
        if not conversation:
            return False
        last = conversation[-1].content.lower()
        return "FINAL ANSWER:" in conversation[-1].content

    def _select_next_agent(self, turn: int) -> str:
        """Determine which agent speaks next."""
        if self.turn_strategy == "round_robin":
            return self.agent_order[turn % len(self.agent_order)]
        elif self.turn_strategy == "llm_routed":
            # Use a routing LLM to decide who speaks next
            history = self._format_conversation()
            names = ", ".join(self.agent_order)
            response = self.llm_factory("gpt-4o-mini").chat([
                {"role": "user",
                 "content": f"Given this conversation, who should speak next? "
                            f"Choose from: {names}\n\n{history}"}
            ])
            return response.content.strip()
        return self.agent_order[0]

    def _format_conversation(self) -> str:
        """Format conversation history for agent consumption."""
        return "\n".join(
            f"[{msg.agent_name}]: {msg.content}"
            for msg in self.conversation
        )

    def _run_agent_turn(self, agent_name: str, turn: int) -> str:
        """Run a single agent's turn in the conversation."""
        config = self.agents[agent_name]
        history = self._format_conversation()

        messages = [
            {"role": "system", "content": config.system_prompt},
            {"role": "user",
             "content": f"Conversation so far:\n{history}\n\n"
                        f"It is your turn. Respond as {config.role}."},
        ]

        llm = self.llm_factory(config.model)
        # Standard tool-calling loop for this agent's turn
        for _ in range(5):
            response = llm.chat(messages=messages, tools=config.tools)
            if not response.tool_calls:
                return response.content
            for call in response.tool_calls:
                result = execute_tool(call)
                messages.append({"role": "tool", "content": result, "id": call.id})

        return "Turn limit reached."

    def run(self, user_request: str) -> str:
        # Seed the conversation with the user's request
        self.conversation.append(
            ConversationMessage(agent_name="user", content=user_request, turn=0)
        )

        for turn in range(1, self.max_turns + 1):
            # 1. Select next agent
            agent_name = self._select_next_agent(turn)

            # 2. Run agent's turn
            response = self._run_agent_turn(agent_name, turn)
            self.conversation.append(
                ConversationMessage(agent_name=agent_name,
                                    content=response, turn=turn)
            )

            # 3. Check termination
            if self.termination_fn(self.conversation):
                return response

        # Extract final state from conversation
        return self.conversation[-1].content
```

### Tradeoffs

**Strengths:**

- **Diversity of perspective**: multiple agents with different roles catch errors and blind spots a single agent would miss
- **Natural review process**: the writer-reviewer dynamic is built into the architecture
- **Emergent quality**: iterative refinement through debate can produce higher-quality output than a single pass
- **Flexible interaction**: agents can adapt their behavior based on what other agents say
- **Modular**: adding a new perspective means adding a new agent, not changing the existing ones

**Weaknesses:**

- **Token-expensive**: every agent reads the full conversation history. With N agents and T turns, total tokens scale as O(N * T * history_length).
- **Convergence is not guaranteed**: agents can get stuck in infinite disagreement loops
- **Turn-taking complexity**: deciding who speaks next is a non-trivial problem, especially with more than 3 agents
- **Coordination overhead**: agents may repeat work or give contradictory instructions
- **Hard to evaluate**: it is difficult to measure whether multi-agent collaboration actually produces better results than a single, well-prompted agent

**Failure modes:**

- **Echo chamber**: agents agree with each other too quickly without genuine critique
- **Infinite debate**: agents keep disagreeing without converging on a solution
- **Role confusion**: agents start acting outside their defined roles
- **Context overflow**: conversation history grows too large for the LLM's context window
- **Lowest common denominator**: the final output is a watered-down compromise rather than a sharp, coherent answer

### When to Use / Avoid

**Use when:**

- The task benefits from multiple perspectives (code review, fact-checking, creative brainstorming)
- You need a built-in quality check (writer + reviewer is a natural multi-agent pattern)
- The task involves negotiation or synthesis of different viewpoints
- You are building a simulation or role-playing scenario

**Avoid when:**

- A single well-prompted agent can do the job (most tasks)
- Latency matters (multi-agent adds turns and LLM calls)
- You cannot afford the token cost of full-history conversations
- The task is purely procedural with no room for debate or review

### Article Angle

The Multi-Agent Harness is the "team" pattern. The article angle: **"When one AI is not enough: building teams of agents that actually argue"**. Focus on the writer-reviewer dynamic as the simplest and most practical multi-agent pattern. Show how AutoGen's GroupChat implements it, then build a minimal two-agent reviewer pattern from scratch. Address the elephant in the room: does multi-agent actually produce better results than a single agent with a good prompt? (The honest answer: sometimes, especially for review/critique tasks, but not always.)

---

## 6. DAG Harness

### Definition

The DAG (Directed Acyclic Graph) Harness structures agent workflows as a graph of nodes (processing steps) connected by edges (dependencies), with no cycles. Each node is a discrete operation -- an LLM call, a tool invocation, a data transformation, or a sub-agent -- and the graph defines the execution order and data flow between them.

This is the most structured of the six patterns. Unlike the General Purpose Harness (which lets the LLM decide what to do at runtime), the DAG Harness has a **predetermined execution plan**. The graph is defined in code before execution begins. The LLM operates within specific nodes but does not control the overall flow.

The DAG pattern borrows directly from data engineering (Apache Airflow, Prefect, Dagster) and applies it to agent workflows. It is Anthropic's "Prompt Chaining" and "Parallelization" patterns combined into a general structure.

### Architecture

```
                    +------------------+
                    |   User Input     |
                    +--------+---------+
                             |
                             v
                    +--------+---------+
                    |   DAG Engine     |  <-- topological sort,
                    |   (scheduler)    |      dependency resolution,
                    +--------+---------+      parallel execution
                             |
              +--------------+--------------+
              |              |              |
              v              v              v
         +----+----+   +----+----+   +-----+---+
         | Node A  |   | Node B  |   | Node C  |
         | (extract|   | (search)|   | (fetch  |
         |  entities)  | (web)   |   |  data)  |
         +----+----+   +----+----+   +-----+---+
              |              |              |
              +---------+----+              |
                        |                   |
                        v                   |
                   +----+----+              |
                   | Node D  |              |
                   | (analyze|<-------------+
                   |  + merge)
                   +----+----+
                        |
                        v
                   +----+----+
                   | Node E  |
                   | (LLM    |
                   |  synth) |
                   +----+----+
                        |
                        v
                   +----+----+
                   | Output  |
                   +---------+
```

### How It Works (step-by-step)

1. **Graph definition**: The developer defines nodes (processing steps) and edges (dependencies) in code. Each node has an input schema, an output schema, and an execution function.
2. **Topological sort**: The DAG engine determines execution order by topologically sorting the graph. Nodes with no dependencies execute first.
3. **Parallel execution**: Nodes that are independent (no shared dependencies) can execute in parallel. The DAG engine manages this concurrency.
4. **Node execution**: Each node runs its function -- which might be an LLM call, a tool invocation, a data transformation, or a sub-agent call. The node receives inputs from its parent nodes and produces outputs for its child nodes.
5. **Data flow**: The output of each node is passed to its dependent nodes as input. The DAG engine manages this data routing.
6. **Conditional edges** (optional): Some edges may be conditional -- a node's output determines which downstream path is taken. This allows branching without cycles.
7. **Completion**: The graph execution completes when all terminal nodes (nodes with no outgoing edges) have finished.

### Key Components

- **DAG Engine / Scheduler**: The core runtime that manages execution order, parallelism, dependency resolution, and data flow. This is the harness itself.
- **Node**: A discrete processing step with typed inputs and outputs. Can be an LLM call, a tool, a function, or a sub-agent.
- **Edge**: A dependency between nodes. Can be unconditional (always follows) or conditional (follows only if a condition is met).
- **State Store**: Intermediate results are stored so downstream nodes can access them. This also enables retry/resume if a node fails.
- **Error Handler**: Per-node error handling (retry, skip, substitute default, abort graph).

### Real-World Implementations

| Framework | Implementation | Notes |
|-----------|---------------|-------|
| **LangGraph** | `StateGraph` with nodes and conditional edges | The most popular graph-based agent framework. Supports cycles (which technically makes it not a DAG), but can be used in DAG mode. |
| **LlamaIndex Workflows** | Event-driven workflow with `@step` decorators and typed events | Nodes emit events that trigger downstream nodes. DAG structure is defined by event types. |
| **Prefect / Airflow** | Traditional workflow orchestration with `@task` and `@flow` | Not agent-specific, but the DAG pattern originated here. Can orchestrate LLM calls as tasks. |
| **Haystack** | Pipeline with nodes and edges | NLP-focused pipeline framework. Nodes can be LLM calls, retrievers, or custom components. |
| **Semantic Kernel (Process Framework)** | Step-based workflows with typed inputs/outputs | Microsoft's structured approach to multi-step LLM workflows. |

### Code Skeleton (Python pseudocode)

```python
from dataclasses import dataclass, field
from typing import Any, Callable
from concurrent.futures import ThreadPoolExecutor, as_completed

@dataclass
class DAGNode:
    name: str
    function: Callable[..., Any]       # the processing logic
    dependencies: list[str] = field(default_factory=list)
    retry_count: int = 1

@dataclass
class ConditionalEdge:
    from_node: str
    to_node: str
    condition: Callable[[Any], bool]   # evaluated on from_node's output

class DAGHarness:
    def __init__(self, nodes: list[DAGNode],
                 conditional_edges: list[ConditionalEdge] | None = None,
                 max_parallelism: int = 4):
        self.nodes = {n.name: n for n in nodes}
        self.conditional_edges = conditional_edges or []
        self.max_parallelism = max_parallelism
        self.results: dict[str, Any] = {}

    def _topological_sort(self) -> list[list[str]]:
        """Sort nodes into execution layers (parallel batches)."""
        in_degree = {name: 0 for name in self.nodes}
        for node in self.nodes.values():
            for dep in node.dependencies:
                in_degree[node.name] = in_degree.get(node.name, 0)
                # Count dependencies
        # Compute in-degrees
        for node in self.nodes.values():
            in_degree[node.name] = len(node.dependencies)

        layers = []
        remaining = set(self.nodes.keys())
        while remaining:
            # Find all nodes with no unresolved dependencies
            layer = [
                name for name in remaining
                if all(dep not in remaining for dep in self.nodes[name].dependencies)
            ]
            if not layer:
                raise ValueError("Cycle detected in DAG")
            layers.append(layer)
            remaining -= set(layer)
        return layers

    def _should_execute(self, node_name: str) -> bool:
        """Check conditional edges to determine if this node should run."""
        for edge in self.conditional_edges:
            if edge.to_node == node_name:
                source_result = self.results.get(edge.from_node)
                if not edge.condition(source_result):
                    return False
        return True

    def _execute_node(self, node: DAGNode) -> Any:
        """Execute a single node, passing in dependency results."""
        dep_results = {dep: self.results[dep] for dep in node.dependencies}

        for attempt in range(node.retry_count):
            try:
                return node.function(**dep_results)
            except Exception as e:
                if attempt == node.retry_count - 1:
                    raise RuntimeError(
                        f"Node '{node.name}' failed after {node.retry_count} "
                        f"attempts: {e}"
                    )

    def run(self, initial_inputs: dict[str, Any] | None = None) -> dict[str, Any]:
        """Execute the DAG, returning all node results."""
        # Seed initial inputs as "virtual node results"
        if initial_inputs:
            self.results.update(initial_inputs)

        layers = self._topological_sort()

        for layer in layers:
            # Filter out nodes that should not execute (conditional edges)
            executable = [
                name for name in layer
                if name in self.nodes and self._should_execute(name)
            ]

            # Execute layer in parallel
            with ThreadPoolExecutor(max_workers=self.max_parallelism) as pool:
                futures = {
                    pool.submit(self._execute_node, self.nodes[name]): name
                    for name in executable
                }
                for future in as_completed(futures):
                    node_name = futures[future]
                    self.results[node_name] = future.result()

        return self.results


# --- Usage example: RAG pipeline as a DAG ---

def preprocess(user_input: str) -> str:
    """Clean and normalize the query."""
    return user_input.strip().lower()

def retrieve(preprocess: str) -> list[str]:
    """Retrieve relevant documents from vector store."""
    return vector_db.search(preprocess, top_k=5)

def rerank(retrieve: list[str], preprocess: str) -> list[str]:
    """Re-rank retrieved documents by relevance."""
    return reranker.rank(retrieve, query=preprocess)

def synthesize(rerank: list[str], preprocess: str) -> str:
    """LLM call to synthesize the final answer."""
    context = "\n".join(rerank)
    return llm.chat(f"Answer based on context:\n{context}\n\nQuery: {preprocess}")

pipeline = DAGHarness(nodes=[
    DAGNode(name="user_input", function=lambda: user_query, dependencies=[]),
    DAGNode(name="preprocess", function=preprocess, dependencies=["user_input"]),
    DAGNode(name="retrieve", function=retrieve, dependencies=["preprocess"]),
    DAGNode(name="rerank", function=rerank, dependencies=["retrieve", "preprocess"]),
    DAGNode(name="synthesize", function=synthesize,
            dependencies=["rerank", "preprocess"]),
])

results = pipeline.run(initial_inputs={"user_input": "What is quantum computing?"})
print(results["synthesize"])
```

### Tradeoffs

**Strengths:**

- **Predictable**: execution order is deterministic and defined at build time
- **Debuggable**: you can inspect the state at any node, replay failed nodes, and visualize the graph
- **Efficient**: independent branches execute in parallel automatically
- **Composable**: DAGs can be nested (a node can be a sub-DAG)
- **Resumable**: if a node fails, you can restart from that point without re-running earlier nodes
- **Familiar**: engineers who know Airflow, Prefect, or CI/CD pipelines already understand this pattern

**Weaknesses:**

- **Rigid**: the graph is defined at build time. The LLM cannot dynamically add or remove steps.
- **No loops**: by definition, a DAG has no cycles. If you need iterative refinement, you need to unroll the loop into fixed iterations or break out of the DAG pattern.
- **Over-engineering risk**: simple sequential tasks do not need a graph abstraction. A DAG for a 3-step chain is more complex than a for loop.
- **Conditional complexity**: complex branching logic in a DAG can become hard to reason about (the graph equivalent of spaghetti code).

**Failure modes:**

- **Over-specified**: the developer pre-defines a workflow that does not match what the task actually needs. Unlike a General Purpose Harness, the LLM cannot adapt.
- **Node failure cascade**: a failed node blocks all downstream nodes. Without good error handling, a single failure kills the entire pipeline.
- **Data shape mismatches**: nodes pass data to each other. If a node produces unexpected output, downstream nodes break.
- **Premature optimization**: building a DAG before understanding the task leads to a complex graph that does the wrong thing efficiently.

### When to Use / Avoid

**Use when:**

- The workflow has a known, fixed structure (ETL, RAG pipeline, document processing)
- You need parallelism and want the engine to manage concurrency
- You need resumability (restart from failure point, not from scratch)
- The task is data-pipeline-like: extract, transform, load, synthesize
- You want to visualize and reason about the workflow structure

**Avoid when:**

- The task requires dynamic decision-making about what steps to take (use General Purpose or Autonomous)
- The workflow needs iterative refinement with an unknown number of cycles (use Multi-Agent or Autonomous)
- The task is simple enough for a single LLM call or a linear chain
- You are prototyping and the workflow structure is not yet clear

### Article Angle

The DAG Harness is the engineering pattern. The article angle: **"From Airflow to agents: why your AI pipeline should be a graph"**. Draw the connection between traditional data engineering (Airflow, Prefect, Dagster) and modern agent workflows. Show how the same DAG pattern that orchestrates ETL jobs can orchestrate LLM calls, retrieval, and synthesis. The key insight: DAGs trade flexibility for reliability. When you know the steps in advance, a DAG gives you parallelism, resumability, and debuggability that no agent loop can match. But the moment you need the LLM to decide what to do next, the DAG breaks down -- and that's when you need one of the other patterns.

---

## Synthesis

### How the Patterns Relate

The six patterns are not isolated choices -- they compose, nest, and evolve into each other:

```
Composition relationships:

General Purpose  --constrain-->  Specialized
General Purpose  --add planning + memory-->  Autonomous
General Purpose  --nest as worker-->  Hierarchical
Hierarchical     --flatten hierarchy-->  Multi-Agent
DAG              --add LLM nodes-->  DAG with agent nodes
Any pattern      --compose into-->  DAG (as nodes)
```

**Common compositions in production systems:**

- **Hierarchical + Specialized workers**: An orchestrator delegates to Specialized agents, each with domain-specific tools and guardrails. This is the most common production pattern.
- **DAG + General Purpose nodes**: A fixed pipeline where some nodes are LLM agent loops. The DAG controls the macro flow; the agent controls the micro flow within each node.
- **Multi-Agent + Hierarchical**: A team of peer agents, managed by a supervising orchestrator that can intervene if the conversation stalls.
- **Autonomous + DAG**: The Autonomous harness's task queue can be modeled as a dynamically-constructed DAG, with the re-planner adding nodes at runtime.

**Evolution path**: Most teams start with a General Purpose Harness, constrain it into a Specialized Harness as they learn the domain, then graduate to Hierarchical or DAG as the system grows more complex. Multi-Agent and Autonomous patterns are adopted selectively for specific sub-problems, not as the primary architecture.

### Recommended Learning Order

For a reader encountering these patterns for the first time:

1. **General Purpose** -- understand the basic agent loop. Everything else builds on this.
2. **Specialized** -- learn how constraints make agents production-ready.
3. **DAG** -- understand structured workflows and when determinism beats autonomy.
4. **Hierarchical** -- learn how to compose agents into systems.
5. **Multi-Agent** -- explore collaboration and when multiple perspectives help.
6. **Autonomous** -- the most complex and least reliable pattern. Learn it last, use it cautiously.

### Open Questions and Gaps in the Literature

1. **Evaluation**: There is no standard benchmark for comparing harness patterns. "Does multi-agent produce better results than single-agent?" is an empirical question without a definitive answer. Most evidence is anecdotal.

2. **Cost modeling**: No framework provides good tooling for predicting the cost (in tokens and dollars) of a harness configuration before running it. This makes it hard to choose between patterns on economic grounds.

3. **Debugging and observability**: Tracing failures through multi-agent or autonomous systems is an unsolved UX problem. Current tools (LangSmith, Arize, Braintrust) provide traces, but interpreting them requires expertise.

4. **When to add agents vs. improve prompts**: The literature lacks rigorous guidance on when adding a second agent actually helps versus when a better prompt for a single agent would achieve the same result at lower cost.

5. **Safety and alignment**: As agents gain autonomy (Autonomous pattern), alignment becomes a systems problem, not just a model problem. The harness must enforce safety constraints that the LLM might not follow on its own. This is under-explored outside of specific labs (Anthropic, DeepMind).

6. **Naming inconsistency**: The community has not converged on consistent names for these patterns. What this document calls "General Purpose" might be "ReAct agent," "tool-use agent," "function-calling loop," or "agentic loop" elsewhere. This terminology fragmentation makes it harder to compare approaches across frameworks.

7. **Composability standards**: There is no standard protocol for composing agents across different frameworks. A LangGraph agent cannot easily delegate to a CrewAI agent. MCP (Model Context Protocol) addresses tool interoperability but not agent interoperability.

---

## Sources

### Primary References

- Anthropic. "Building Effective Agents." Dec 2024. https://www.anthropic.com/research/building-effective-agents
- OpenAI. "Assistants API - Implementing the Agent Loop." https://platform.openai.com/docs/assistants/tools
- OpenAI. "Function Calling Guide." https://platform.openai.com/docs/guides/function-calling
- Google. "Agent Development Kit (ADK) - Multi-Agent Architecture." https://github.com/google/adk-docs/blob/main/docs/agents/multi-agents.md
- Google. "Building Collaborative AI: A Developer's Guide to Multi-Agent Systems with ADK." https://cloud.google.com/blog/topics/developers-practitioners/building-collaborative-ai-a-developers-guide-to-multi-agent-systems-with-adk/
- Microsoft. "AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation." https://github.com/microsoft/autogen
- Microsoft. "Semantic Kernel Documentation." https://learn.microsoft.com/en-us/semantic-kernel/

### Frameworks and Tools

- LangGraph documentation. https://langchain-ai.github.io/langgraph/
- LangChain Agent documentation. https://python.langchain.com/docs/modules/agents/
- CrewAI documentation. https://docs.crewai.com/
- LlamaIndex Workflows documentation. https://docs.llamaindex.ai/en/latest/module_guides/workflows/
- Haystack documentation. https://docs.haystack.deepset.ai/
- Prefect documentation. https://docs.prefect.io/

### Agent Systems

- AutoGPT. https://github.com/Significant-Gravitas/Auto-GPT
- BabyAGI. https://github.com/yoheinakajima/babyagi
- ChatDev. https://github.com/OpenBMB/ChatDev
- GPT Researcher. https://github.com/assafelovic/gpt-researcher

### Research Papers and Articles

- Yao et al. "ReAct: Synergizing Reasoning and Acting in Language Models." 2022. https://arxiv.org/abs/2210.03629
- Wei et al. "Chain-of-Thought Prompting Elicits Reasoning in Large Language Models." 2022. https://arxiv.org/abs/2201.11903
- Wang et al. "A Survey on Large Language Model based Autonomous Agents." 2023. https://arxiv.org/abs/2308.11432
- Cloudflare. "Anthropic Agent Patterns - Implementation Examples." https://github.com/cloudflare/agents/tree/main/guides/anthropic-patterns

### Implementation Examples

- OpenAI Cookbook. "How to Call Functions with Chat Models." https://cookbook.openai.com/examples/how_to_call_functions_with_chat_models
- Anthropic. "Tool Use Documentation." https://docs.anthropic.com/claude/docs/tool-use
- Google Developers Blog. "Introducing ADK." https://developers.googleblog.com/en/agent-development-kit-easy-to-build-multi-agent-applications/
