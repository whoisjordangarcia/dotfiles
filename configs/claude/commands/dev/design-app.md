---
allowed-tools: Task, Read, Write, TodoWrite
description: Design Next.js full-stack application architecture from PRD with test-first specifications
argument-hint: <prd-file-path>
---

# Next.js Full-Stack Application Design Command

Create a comprehensive Next.js application design with test-first specifications based on a Product Requirements Document (PRD).

## Usage Examples

Analyze PRD file referenced from `$ARGUMENTS`. It may be passed directly as text, or as a file reference, or with parameters.

```bash
# Design from PRD file
/design-app --prd=docs/projects/analytics/prd.md

# Design with specific data sources
/design-app --prd=projects/analytics/prd.md --data=.claude/outputs/data/latest

# Design with custom output location
/design-app --prd=specs/chat-app.md --output=designs/chat-app
```

## PRD-Driven Design Philosophy

The command analyzes a Product Requirements Document to create a complete Next.js application design:

1. **PRD Analysis**: Extract features, user stories, and technical requirements
2. **Test-First Design**: Write acceptance tests based on PRD user stories
3. **Next.js Architecture**: Design specifically for Next.js App Router patterns
4. **Visual Component Planning**: Select shadcn/ui components with aesthetic excellence for all UI requirements

## Enhanced Visual Design Integration

The **shadcn-expert** agent now provides comprehensive visual design capabilities:

### Visual Excellence Focus

- **Aesthetic Component Selection**: Choose components that enhance visual appeal and user experience
- **Design Context Integration**: Leverage wireframes, color schemes, and visual patterns from ui-designer output
- **Beautiful Composition Planning**: Ensure components work together harmoniously for stunning interfaces
- **Responsive Beauty**: Maintain visual excellence across all breakpoints and devices

### Enhanced Deliverables with Concrete Specifications

The shadcn-expert agent now produces **5 output files** with mandatory concrete values:

1. `component-selection.md` - Component choices with **visual design rationale**
2. `composition-plan.md` - **Beautiful interface composition** strategies
3. `design-system-strategy.md` - **Color harmony, typography scales, spacing systems**
4. `customization-specifications.md` - **Animation patterns, styling variants, responsive beauty guidelines**
5. `implementation-values.md` - **Exact hex codes, Tailwind classes, CSS variables for THIS app**

### Required Concrete Deliverables (App-Specific)

Each design agent MUST provide:

- Exact hex/RGB values CHOSEN FOR THIS APP (not copied from examples)
- Rationale for why these colors suit THIS application's purpose and audience
- Specific Tailwind classes that implement THIS design system
- WCAG contrast validation results for all text/background combinations

Examples showing proper variety (avoiding AI clichés):

- E-commerce platform: Trustworthy deep blues (#1e3a8a) and conversion oranges (#ea580c)
- Developer dashboard: High-contrast terminal blacks (#0a0a0a) and code greens (#22c55e)
- Learning platform: Warm earth tones (#92400e) and focus-friendly grays (#64748b)
- Healthcare app: Calming teals (#0f766e) and professional whites (#fafafa)
- Finance platform: Conservative navy (#1e3a8a) and accent gold (#d97706)

**Explicitly Avoid AI Design Clichés:**

- ❌ Purple-blue gradients (from-purple-600 to-blue-600)
- ❌ Generic violet/indigo schemes
- ❌ Predictable "AI tool" color patterns
- ✅ Industry-appropriate, user-expected color choices

### Design Quality Standards

Every component selection considers:

- ✅ **Visual Impact** and color integration
- ✅ **Spacing Harmony** and typography hierarchy
- ✅ **Interactive Delight** with thoughtful animations
- ✅ **Accessibility Elegance** without compromising beauty

## Workflow (Orchestrator-Managed Sequential then Parallel Coordination)

Following orchestrator-initialized workflow with structured project setup and validation:

### Phase 1: Orchestrator Initialization (Sequential - Project Setup)

**Agent**: `orchestrator`
**Output**: `.claude/outputs/design/projects/[project-name]/[timestamp]/`
**Purpose**:

- Analyze PRD and confirm project scope
- Generate consistent project name and timestamp
- Create initial MANIFEST.md with requirements baseline
- Note: Agent outputs go directly to shared `.claude/outputs/design/agents/` location

### Phase 2: UI Design Foundation (Sequential - Foundation Required)

**Agent**: `ui-designer`
**Output**: `.claude/outputs/design/agents/ui-designer/[project-name]-[timestamp]/` (pre-created)
**Purpose**: Read PRD, create wireframes, component hierarchy, and user flows

### Phase 3: Parallel Component & Testing Design

**Executed Simultaneously** after Phase 2 completion:

You **MUST** execute Phase 3A and Phase 3B in parallel using sub-agents.

#### Phase 3A: Component System Design

```bash
- shadcn-expert → visual component selection, beautiful composition strategy, design system aesthetics (uses ui-designer output for visual design context)
```

#### Phase 3B: Test Specification Design

```bash
- browserbase-stagehand-expert → E2E test specifications (uses ui-designer output)
```

### Phase 4: Orchestrator Synthesis & Validation (Sequential - Requires All Inputs)

**Agent**: `orchestrator` (final validation)
**Output**: `.claude/outputs/design/projects/[project-name]/[timestamp]/`

**Purpose**: Synthesize all agent outputs into coherent implementation plan
**Input**: All agent outputs from Phases 2-3 + initial MANIFEST from Phase 1
**Validates**:

- ✓ All PRD requirements have corresponding design outputs
- ✓ UI wireframes cover all user stories
- ✓ Component plan addresses all UI requirements
- ✓ Test specifications cover all acceptance criteria
- ✓ Cross-agent consistency and integration points
- ✓ All color specifications include exact hex values with contrast ratios
- ✓ All text/background combinations pass WCAG AA (4.5:1 ratio minimum)
- ✓ CSS variables are defined with precise values for this specific app
- ✓ Tailwind classes are specified for each visual element
  **Output**:
- `MANIFEST.md` - Final registry linking all agent outputs with requirements traceability
- `IMPLEMENTATION_PLAN.md` - Single source of truth for implementation
  **TodoWrite Integration**: Creates final task list with requirement coverage validation

## Output Structure

**Phase 1 (Orchestrator Initialization)**:

```
.claude/outputs/design/projects/[project-name]/[timestamp]/
└── MANIFEST.md                   # Initial requirements baseline and agent registry
```

**Phase 2 (Sequential - UI Foundation)**:

```
.claude/outputs/design/agents/
└── ui-designer/[project-name]-[timestamp]/
    ├── wireframes.md
    ├── component-hierarchy.md
    └── user-flow-designs.md
```

**Phase 3 (Parallel Execution)**:

```
.claude/outputs/design/agents/
├── shadcn-expert/[project-name]-[timestamp]/
│   ├── component-selection.md
│   ├── composition-plan.md
│   ├── design-system-strategy.md
│   └── customization-specifications.md
├── browserbase-stagehand-expert/[project-name]-[timestamp]/
│   ├── test-plan.md
│   ├── playwright-tests.md
│   └── stagehand-tests.md
```

**Phase 4 (Sequential - Final Synthesis)**:

```
.claude/outputs/design/projects/[project-name]/[timestamp]/
├── MANIFEST.md                   # Complete registry of all agent outputs with requirements traceability
└── IMPLEMENTATION_PLAN.md        # Unified implementation plan
```

## Task Management & Orchestrator-Managed Execution

The command automatically:

- **Phase 1**: Orchestrator initialization with project setup and TodoWrite tracking
- **Phase 2**: Sequential UI design with TodoWrite tracking
- **Phase 3**: Parallel agent spawning with concurrent TodoWrite management
- **Phase 4**: Final orchestrator synthesis with validation against all outputs
- **Agent Coordination**: Uses **multiple Task tool calls in single message** to spawn agents simultaneously
- **Progress Tracking**: Individual TodoWrite entries for each agent's progress
- **Dependency Management**: Ensures Phase 4 waits for all Phase 3 agents to complete

### Critical Implementation Pattern for Phase 3

**Parallel Execution Requirements:**

```bash
# CORRECT: Two Task tool calls in single message for parallel execution
<invoke name="Task">
  # shadcn-expert task
</invoke>
<invoke name="Task">
  # browserbase-stagehand-expert task
</invoke>

# INCORRECT: Sequential Task calls (not parallel)
# Call shadcn-expert first, wait for completion, then call browserbase-stagehand-expert
```

### Execution Strategy

```bash
# Phase 1: Sequential (project initialization)
orchestrator → PRD analysis, project setup, folder creation, initial MANIFEST.md

# Phase 2: Sequential (UI foundation required)
ui-designer → wireframes, component hierarchy, user flows

# Phase 3: Parallel (spawn simultaneously, using ui-designer output)
# CRITICAL: Use TWO Task tool calls in SINGLE message for true parallelism
shadcn-expert (visual design + aesthetic components) + browserbase-stagehand-expert (E2E testing) (simultaneous Task calls)

# Phase 4: Sequential (requires all inputs)
orchestrator → synthesis, validation, finalize MANIFEST.md
```

## Input Parameters

- `--prd`: Path to PRD file (required)
- `--data`: Path to existing data specifications (optional)
- `--output`: Custom output directory (optional)

## PRD Requirements Coverage (Orchestrator-Managed Validation)

The design process ensures 100% PRD coverage across all agents:

- ✓ **orchestrator**: Initial PRD analysis & MANIFEST creation (initialization)
- ✓ **ui-designer**: UI requirements & user story mapping (foundation)
- ✓ **shadcn-expert**: Visual component selection, beautiful design systems & aesthetic integration (uses UI foundation for visual design context)
- ✓ **browserbase-stagehand-expert**: User acceptance criteria & E2E testing (uses UI foundation)
- ✓ **orchestrator**: Cross-agent validation & MANIFEST finalization (synthesis)

## Next.js Specific Design

The design is optimized for Next.js 14+ App Router:

- **Page Structure**: `/app` directory layout
- **Server Components**: Default for data fetching
- **Client Components**: Only when needed for interactivity
- **API Routes**: `/app/api` for backend endpoints
- **Layouts**: Shared layouts for common elements
- **Loading/Error**: Proper loading.tsx and error.tsx pages

## Success Criteria (Orchestrator-Managed Validation)

A complete design includes outputs from all phases:

- ✓ **Phase 1**: Project setup & initial MANIFEST (orchestrator initialization)
- ✓ **Phase 2**: UI wireframes & component hierarchy (ui-designer)
- ✓ **Phase 3A**: Visual shadcn/ui component selections, beautiful design systems & aesthetic customizations (shadcn-expert)
- ✓ **Phase 3B**: E2E test specifications covering all user stories (browserbase-stagehand-expert)
- ✓ **Phase 4**: Complete MANIFEST + unified IMPLEMENTATION_PLAN (orchestrator synthesis)

**Efficiency Gains**: Orchestrator setup enables consistent project structure and UI foundation enables parallel component and testing work

## Integration with Implementation

Output feeds directly into:

- `/implement-mvp` for TDD implementation
- Next.js project scaffolding
-
