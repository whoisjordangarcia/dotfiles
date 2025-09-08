---
allowed-tools: Task, Bash, Read, Write, Edit, MultiEdit, TodoWrite
description: Build MVP from design specifications using test-driven development cycles
argument-hint: <design-folder-output-path> <mvp-folder>
---

# App Implementation from Design Specifications

Build production-ready app from `/design-app` outputs using modern Test-Driven Development () with Playwright and Stagehand.

## Core Philosophy

This command demonstrates modern TDD practices by:

- **Design-First**: All implementation decisions derive from design phase outputs
- **Test-First**: Write tests before code (Red → Green → Verify cycles)
- **Progressive Testing**: Playwright for fundamentals, Playwright+Stagehand hybrid for UI
- **No Assumptions**: Implementation follows design specifications exactly

## Prerequisites

This command requires design outputs from `/design-app`:

- `.claude/outputs/design/projects/[project-name]/[timestamp]/IMPLEMENTATION_PLAN.md` - Technical roadmap
- `.claude/outputs/design/projects/[project-name]/[timestamp]/MANIFEST.md` - Requirements registry
- UI designer outputs (wireframes, component hierarchy, user flows)
- shadcn-expert outputs (component selections, composition strategies)
- browserbase-stagehand-expert outputs (test specifications)

## Arguments

Parse `$ARGUMENTS` to extract the path to:

- <design-folder-output-path> the design folder containing the design outputs. The path should point to a folder like `.claude/outputs/design/projects/[project-name]/[timestamp]/`

- <mvp-folder> (optional) the folder that the mvp should be built in.

The command will automatically read:

- `MANIFEST.md` - Registry of all design agent outputs with requirements traceability
- `IMPLEMENTATION_PLAN.md` - Unified implementation strategy and technical approach
- Reference all related design agent outputs as indexed by the `MANIFEST.md`
- Check if the `mvp-folder` is specified. Otherwise, make an intelligent guess where to start build the app. If existing files are there, perform an assessment to know the starting point (likely to be a boilerplate next-js app)

## Usage Example

```bash
# Implement from design folder path
/implement-mvp .claude/outputs/design/projects/[project-name]/[timestamp]
```

## Modern TDD Workflow with Design Integration

### Phase 1: Design Analysis & Project Setup (5-10 minutes)

**1. Read ALL Design Specifications First**

Before writing any code or tests, thoroughly analyze the design outputs:

**1.1. Visual Specification Extraction (CRITICAL)**

BEFORE implementation, extract concrete values from design outputs:

```typescript
// Extract from design outputs - example structure
interface DesignTokens {
  colors: {
    [key: string]: {
      hex: string; // #1e40af (exact value for this app)
      rgb: string; // rgb(30, 64, 175)
      tailwind: string; // bg-blue-700 (specific class)
      contrast: number; // 8.2 (measured ratio)
      purpose: string; // "Primary CTA for finance app trust"
    };
  };
}
```

**Pre-Implementation Validation Checklist**:

- [ ] All colors have exact hex values (no abstract descriptions)
- [ ] All color combinations validated for contrast (minimum 4.5:1)
- [ ] Tailwind classes specified for each visual element
- [ ] CSS variables defined with precise values for THIS app
- [ ] No abstract descriptions remain ("beautiful", "modern", "sophisticated")

**If design outputs lack concrete values**:

1. HALT implementation immediately
2. Request specific hex codes, RGB values, and Tailwind classes
3. Document missing specifications before proceeding
4. Never assume or improvise color values

**Then proceed with design analysis:**

- `MANIFEST.md` - Understand complete project scope and requirements coverage
- `IMPLEMENTATION_PLAN.md` - Extract technical specifications, NOT code snippets
- `ui-designer/wireframes.md` - Visual structure and layout specifications
- `ui-designer/component-hierarchy.md` - Component organization and relationships
- `shadcn-expert/component-selection.md` - Exact shadcn/ui components to use
- `browserbase-stagehand-expert/test-plan.md` - Test scenarios and coverage strategy

**1.1. Data Integration Patterns**

For apps using external data sources (JSON files, APIs):

- **Static JSON Files**: Import with proper TypeScript interfaces
- **API Integration**: Plan fetch patterns and error handling
- **Type Safety**: Create interfaces matching data structure

**Example for Static Data**:

```typescript
import episodesData from "@/data/episodes.json";
interface Episode {
  id: string;
  title: string;
  status: "ideas" | "production" | "editing" | "published";
}
const episodes: Episode[] = episodesData.episodes;
```

**2. Initialize Project Based on Design Specs**

Let the IMPLEMENTATION_PLAN.md guide setup, not predetermined patterns:

- Check if the target mvp-folder already exists
- Assess current state if boilerplate exists
- Install dependencies specified in design outputs
- Configure testing framework (Playwright + Stagehand)

**3. Write Baseline Playwright Test**

**🔴 RED Phase**: Write the simplest Playwright test based on design requirements:

- Test derives from actual project requirements in MANIFEST.md
- Use Playwright for this fundamental smoke test
- Test must fail initially with clear error message

**🟢 GREEN Phase**: Implement minimal code to pass the test:

- Create only what's needed to satisfy the test
- No extra features or anticipatory code

**✅ VERIFY Phase**: Confirm test passes and app loads

### Phase 2: UI Scaffolding with Hybrid Testing (10-15 minutes)

**Testing Strategy for UI Components**

Based on the design outputs, create a hybrid testing approach:

- **Playwright Tests**: For component existence, structure, and technical validation
- **Stagehand Tests**: For natural language interaction and user intent validation
- Tests derive from `wireframes.md` and `component-hierarchy.md` specifications

**🔴 RED Phase - Write Scaffolding Tests**

Create tests that verify the UI structure from design specs:

- Component existence tests (Playwright)
- Layout structure tests (Playwright)
- Basic interaction tests (Stagehand for natural language)
- All tests must fail initially with clear component-not-found errors

**Test Distribution Guidelines**:

- **Standard Apps**: 60% Playwright (structure), 40% Stagehand (interactions)
- **Interactive Apps** (drag & drop, kanban, games): 30% Playwright (structure), 70% Stagehand (natural language interactions)
- **Data-Heavy Apps**: 50% Playwright (data validation), 50% Stagehand (user workflows)

### Phase 3: UI Implementation from Design (15-20 minutes)

**🟢 GREEN Phase - Implement Components to Pass Tests**

Using ONLY the design specifications as reference:

- Implement components specified in `shadcn-expert/component-selection.md`
- Follow exact composition patterns from `composition-plan.md`
- Match wireframe layouts from `ui-designer/wireframes.md`
- Create minimal implementation to satisfy tests

**Key Principle**: The design outputs are the single source of truth:

- No improvisation or "better ideas" during implementation
- Every decision traces back to a design specification
- If something is unclear, refer back to design outputs, not assumptions

**✅ VERIFY Phase - Confirm All Scaffolding Tests Pass**

Run the hybrid test suite:

- All Playwright structure tests should pass
- All Stagehand interaction tests should pass
- Visual verification against wireframes

### Phase 4: Feature Implementation with Progressive TDD (20-30 minutes)

**Progressive Testing Strategy**

Implement features using increasingly sophisticated testing:

1. **Playwright Tests (40%)**: Technical validation, exact values, performance
2. **Stagehand Tests (50%)**: Natural language scenarios, user intent
3. **Hybrid Tests (10%)**: Combine both for complex validations

**Feature-by-Feature TDD Cycles**

For EACH feature from `browserbase-stagehand-expert/test-plan.md`:

**🔴 RED Phase - Write Feature Test**

- Select test type based on feature nature (technical → Playwright, user-centric → Stagehand)
- Write test directly from specifications in `test-plan.md`
- Run test to confirm it fails with expected error

**🟢 GREEN Phase - Minimal Implementation**

- Implement ONLY what's needed to pass the current test
- Reference design outputs for implementation details
- No anticipation of future features

**✅ VERIFY Phase - User Confirmation**

- Run test suite to confirm new test passes
- Verify feature works as designed
- Get user confirmation before proceeding to next feature
- Document any deviations from design (should be rare)

### Phase 5: Integration & Production Readiness (10-15 minutes)

**Integration Testing**

Create comprehensive tests based on the complete user journeys outlined in:

- `browserbase-stagehand-expert/test-plan.md` user scenarios
- `ui-designer/user-flow-designs.md` interaction flows

**Production Readiness**

Verify against IMPLEMENTATION_PLAN.md success criteria:

- All tests passing (unit → Playwright → Stagehand)
- TypeScript compilation clean
- App builds successfully
- Responsive design working per wireframes

## Implementation Strategy

### Modern TDD with Design-First Approach

The implementation strategy prioritizes design outputs and test-driven development:

**Core Workflow**:

1. Read design specifications completely before any implementation
2. Write tests before code (Red → Green → Verify for every feature)
3. Use Playwright for technical tests, Stagehand for user-centric tests
4. Let design outputs guide ALL implementation decisions

**Testing Philosophy**:

- **Playwright**: Component structure, exact values, performance metrics
- **Stagehand**: Natural language interactions, user journeys, intent-based testing
- **Hybrid**: Combine both for comprehensive coverage

**Design Integration**:

- `MANIFEST.md`: Requirements and coverage tracking
- `IMPLEMENTATION_PLAN.md`: Technical approach (guidance, not code)
- `ui-designer outputs`: Component structure and visual design
- `shadcn-expert outputs`: Component library integration
- `stagehand-expert outputs`: Test scenarios and automation strategy

### Design Integration Points

**Phase 1 - Project Setup:**

- Read MANIFEST.md to understand project scope and requirements
- Extract project name and technical specifications from design folder
- Follow IMPLEMENTATION_PLAN.md for setup requirements and dependencies
- Assess existing project state if mvp-folder already contains code

**Phase 2 - Scaffolding from Actual Design:**

- Load wireframes.md and component-hierarchy.md from ui-designer outputs
- Extract actual component structure (not example components)
- Create scaffolding tests based on real wireframe specifications
- Use data-testid patterns from design documentation

**Phase 3 - UI Implementation:**

- Follow specific component selections from shadcn-expert/component-selection.md
- Implement composition strategy from shadcn-expert/composition-plan.md
- Match exact wireframe layout from ui-designer outputs
- Use design system strategy from shadcn-expert/design-system-strategy.md

**Phase 4 - Progressive Feature Testing:**

- Start with simple unit tests for basic component behavior
- Progress to playwright-tests.md specifications for interaction testing
- Implement stagehand-tests.md for natural language E2E automation
- Follow red-green-verify cycle for each feature from test-plan.md

**Phase 5 - Integration:**

- Verify user scenarios from browserbase-stagehand-expert/test-plan.md
- Test user flows from ui-designer/user-flow-designs.md
- Ensure production readiness per IMPLEMENTATION_PLAN.md success criteria

## Input

- **Design folder path** (required) - Path to design outputs folder containing MANIFEST.md and IMPLEMENTATION_PLAN.md

The command automatically determines project setup requirements and implementation approach from the design specifications.

## Success Metrics

### Design Integration Success

✅ Next.js app initialized with correct dependencies
✅ Baseline smoke test passes
✅ Scaffolding tests cover all wireframe components
✅ UI implementation matches design specifications
✅ shadcn/ui components properly integrated

### TDD Cycle Success

✅ Each feature follows strict RED → GREEN → VERIFY cycle
✅ Scaffolding tests fail appropriately, then pass after UI implementation
✅ Feature tests fail initially, pass after minimal implementation
✅ User verifies each feature works before proceeding
✅ Tests align with browserbase-stagehand-expert specifications

### Production Readiness

✅ All tests passing (scaffolding + features + integration)
✅ TypeScript compilation clean
✅ App builds for production successfully
✅ Matches IMPLEMENTATION_PLAN.md requirements
✅ Ready for deployment

## Design-Driven TDD Rules

### Phase Integration Requirements

- **Must** read design outputs before starting implementation
- **Must** follow UI designer component hierarchy in scaffolding tests
- **Must** use shadcn-expert component selections in implementation
- **Must** implement browserbase-stagehand-expert test specifications

### RED Phase (Test First)

- Write failing tests based on design specifications
- Scaffolding tests check component existence (Phase 2)
- Feature tests check behavior expectations (Phase 4)
- Tests must fail for clear, expected reasons

### GREEN Phase (Minimal Implementation)

- Implement minimal code to pass current test
- Follow design wireframes for component structure
- Use shadcn-expert component selections
- No additional features beyond current test

### VERIFY Phase (User Confirmation)

- Show working feature matches design expectations
- Demonstrate test passing
- Get user approval before next RED cycle
- Ensure design fidelity maintained

## Testing Patterns

### Design-to-Test Pattern

Extract test requirements directly from design outputs:

**Component Testing Strategy**:

1. Read `ui-designer/wireframes.md` for visual structure
2. Read `ui-designer/component-hierarchy.md` for component relationships
3. Create tests that verify the EXACT specifications from design

**Test Type Selection**:

- **Structural elements** → Playwright (can verify exact DOM structure)
- **User interactions** → Stagehand (natural language intent)
- **Complex validations** → Hybrid approach

### Progressive Testing Pattern

Build test complexity incrementally based on design outputs:

**Test Progression**:

1. **Foundation**: Playwright tests for app initialization and basic structure
2. **Scaffolding**: Mixed Playwright/Stagehand for UI components
3. **Features**: Primarily Stagehand with Playwright for technical validation
4. **Integration**: Full user journeys using Stagehand natural language

**Key Principle**: Every test scenario comes from design outputs:

- Use exact scenarios from `browserbase-stagehand-expert/test-plan.md`
- Follow test specifications from `playwright-tests.md` and `stagehand-tests.md`
- No improvised test cases - all tests trace to design requirements

## Troubleshooting Integration Issues

### Design Files Not Found

- Verify the provided design folder path exists
- Check for MANIFEST.md in the specified folder
- Ensure design phase completed successfully with `/design-app`

### Scaffolding Tests Too Complex

- Break down wireframes into smaller components
- Focus on existence tests first, behavior tests later
- Use data-testid attributes from UI designer specs

### Feature Tests Don't Match Stagehand Specs

- Re-read browserbase-stagehand-expert test specifications
- Align natural language actions with test implementation
- Use Stagehand-compatible element selection strategies

## Philosophy

### Modern TDD Principles

1. **Design as Single Source of Truth** - All implementation decisions derive from design outputs
2. **Test Before Code** - Every feature follows Red → Green → Verify discipline
3. **Progressive Test Complexity** - Start with Playwright basics, evolve to Stagehand sophistication
4. **No Assumptions** - If it's not in the design, don't implement it
5. **Continuous Verification** - User confirms each feature before proceeding

### Testing Framework Strategy

**Playwright Usage (Foundation & Technical)**:

- Component existence and structure verification
- Exact value validation (RGB values, hex codes)
- Performance metrics and timing
- DOM structure and data attributes
- Accessibility compliance checks

**Stagehand Usage (User Intent & Natural Language)**:

- Natural language user interactions ("make the color warmer")
- User journey validation ("create a sunset color")
- Intent-based testing ("find and click the save button")
- Emotional color validation ("verify the color feels calming")

**Hybrid Approach (Best of Both)**:

- Stagehand for user action, Playwright for validation
- Natural language setup, technical verification
- Complex scenarios requiring both frameworks

### Implementation Excellence

The goal is to demonstrate that modern TDD with Playwright/Stagehand creates superior MVPs by:

- Following design specifications exactly (no drift)
- Writing tests first (quality built-in)
- Using the right tool for each test type
- Maintaining continuous user feedback loops
-
