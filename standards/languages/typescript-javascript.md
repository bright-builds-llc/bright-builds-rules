# TypeScript and JavaScript

This page translates the core standards into TypeScript/JavaScript-specific guidance.

## Prefer Bun for New Standalone JS/TS Projects

- Level: `should`
- Intent: Keep greenfield JavaScript and TypeScript projects on a fast, simple default toolchain unless compatibility needs point elsewhere.
- Rule: For brand-new standalone JavaScript or TypeScript projects, prefer Bun as the default package manager and script execution surface when the project can reasonably stay on Bun-native paths. Use Bun for installs, lockfiles, and routine script entrypoints by default. Do not churn an existing npm, pnpm, or yarn repository just to satisfy this rule; existing repositories should keep their current package manager unless they intentionally choose to migrate.
- Rationale: A greenfield default only works if it reduces toolchain sprawl instead of creating migration churn. Bun is a good default when it can own the day-to-day package and script surface cleanly, but existing projects already encode real compatibility and workflow decisions in their current toolchain.
- Good example:

```text
New standalone TypeScript service
- initializes with Bun
- commits `bun.lock`
- uses Bun for install and routine script execution
- keeps framework-required tools only where they add real value
```

- Bad example:

```text
Existing pnpm monorepo
- replaces the lockfile and script surface with Bun midstream
- updates CI and local docs only to satisfy the preference
- adds churn without a deliberate migration decision
```

- Exceptions or escape hatches: If a framework, hosting platform, dependency stack, workspace tool, or deployment contract is not Bun-friendly, use the compatible toolchain and document the local reason when it matters. This rule does not ban framework-required tools; it sets the default package-manager and script/runtime surface for greenfield standalone projects.
- Review questions: Is this actually a new standalone JS/TS project, or an existing repo that already standardized on another package manager? Can Bun own the routine install and script surface cleanly here, or is there a clear compatibility reason not to use it?
- Automation potential: Project scaffolds and templates can default to Bun, but compatibility decisions still need repo-level judgment.

## Do Not Add Python Scripts To Bun-Friendly JS/TS Repositories

- Level: `must`
- Intent: Keep repo-owned scripting in one language/runtime surface so scripts are easier to run, typecheck, review, and maintain.
- Rule: In JavaScript or TypeScript repositories where Bun can reasonably own the repo's script/runtime surface, do not add new Python scripts for repo-owned automation, build helpers, code generation, validation, or maintenance tasks. Prefer TypeScript or JavaScript run by Bun. Rare exceptions require a concrete compatibility reason, such as an external dependency or platform contract that is only practical in Python, and that reason should be documented in repo-local guidance when it matters.
- Rationale: Mixing Bun/TS with ad hoc Python helpers creates avoidable toolchain sprawl, duplicated verification surfaces, and onboarding friction. If the repo already depends on Bun/TS for script execution, keeping repo-owned automation there is the simpler long-term default.
- Good example:

```text
Bun-friendly TypeScript repository
- adds `scripts/generate-site-badge.ts`
- runs it with `bun run badge:site`
- typechecks the script with the rest of the repo-owned tooling
```

- Bad example:

```text
Bun-friendly TypeScript repository
- introduces `scripts/measure-badge-text.py` for one helper task
- requires both Bun and Python for routine local verification
- duplicates the script toolchain without a documented compatibility reason
```

- Exceptions or escape hatches: Existing repositories may keep already-established Python tooling until they intentionally migrate it. Repositories whose real compatibility surface is Python-first should keep Python. Narrow Python exceptions inside a Bun/TS-friendly repo are acceptable only when the underlying dependency or runtime contract genuinely requires it.
- Review questions: Could this script live as TypeScript/JavaScript run by Bun instead? Is Python being added for convenience rather than a real compatibility constraint? If Python remains, is the reason explicit and durable?
- Automation potential: Repo linting and file globs can flag new `.py` files in Bun-friendly repos, but exception handling still needs review judgment.

## Prefer Composition Over Class Inheritance

- Level: `must`
- Intent: Keep behavior modular and explicit instead of spreading it across class hierarchies.
- Rule: For our own types, do not use class inheritance. Prefer composition, plain objects, small functions, and explicit collaborators.
- Rationale: Inheritance tends to hide behavior behind base classes and lifecycle coupling. Composition keeps dependencies visible and makes units easier to test, replace, and reason about.
- Good example:

```ts
type PaymentGateway = {
  charge: (request: ChargeRequest) => Promise<ChargeReceipt>;
};

type CheckoutService = {
  submit: (request: CheckoutRequest) => Promise<CheckoutResult>;
};

function createCheckoutService(deps: {
  gateway: PaymentGateway;
  now: () => Date;
}): CheckoutService {
  return {
    async submit(request) {
      const priced = priceCheckout(request, deps.now());
      const charge = await deps.gateway.charge(priced.chargeRequest);
      return finalizeCheckout(priced, charge);
    },
  };
}
```

- Bad example:

```ts
class BaseCheckoutService {
  protected now(): Date {
    return new Date();
  }
}

class StripeCheckoutService extends BaseCheckoutService {
  async submit(request: CheckoutRequest): Promise<CheckoutResult> {
    const priced = priceCheckout(request, this.now());
    return this.chargeAndFinalize(priced);
  }
}
```

- Exceptions or escape hatches: Framework-required inheritance is acceptable at the boundary if the inherited type is effectively infrastructure glue. Do not let the inheritance model leak into business logic.
- Review questions: Does behavior depend on hidden base-class state or overrides? Could the same result be expressed with plain functions and explicit dependencies?
- Automation potential: Linters can ban project-defined class inheritance patterns.

## Keep Business Logic as Data-In, Data-Out Functions

- Level: `should`
- Intent: Make TS/JS business behavior easy to unit test without standing up the framework or runtime environment.
- Rule: Keep core decision logic in plain functions that accept structured data and return structured data. Push API calls, storage, DOM work, and framework glue into thin shells.
- Rationale: TS/JS projects easily drift into framework-centric code. A functional core prevents every change from requiring integration-heavy test setup.
- Good example:

```ts
type Quote = { subtotalCents: number; taxRate: number };

function totalCents(quote: Quote): number {
  return Math.round(quote.subtotalCents * (1 + quote.taxRate));
}
```

- Bad example:

```ts
async function totalCents(controller: QuoteController): Promise<number> {
  const quote = await controller.loadQuote();
  return Math.round(quote.subtotalCents * (1 + quote.taxRate));
}
```

- Exceptions or escape hatches: UI event handlers and framework lifecycle code are shells by definition. Extract the business decision from them once the logic becomes reusable or non-trivial.
- Review questions: Could the same logic be tested with plain objects in a unit test? Is framework state management obscuring a simple transformation?
- Automation potential: Some framework-specific patterns can be flagged, but identifying business logic still depends on review context.

## Encode Invariants with Tagged Unions, Branded Types, or Parsers

- Level: `should`
- Intent: Use the language's type features and parsing layer to reduce invalid states and ambiguous primitives.
- Rule: Parse untrusted input into stronger types before it reaches business logic. Use tagged unions, discriminated states, branded types, or factory/parser modules when they make an illegal state impossible or substantially harder to create. When a TS/JS function returns `T | null | undefined`, or a `Promise` of that shape, prefer a `maybe...` name so the nullable path is obvious at the callsite.
- Rationale: TS/JS cannot enforce as much at runtime as Rust can, but a deliberate parsing layer and stronger types still prevent a large class of mistakes.
- Good example:

```ts
type TeamSlug = string & { readonly __brand: "TeamSlug" };

function maybeParseTeamSlug(value: string): TeamSlug | null {
  if (!/^[a-z0-9-]+$/.test(value)) {
    return null;
  }

  return value as TeamSlug;
}

async function maybeLoadSession(token: string): Promise<Session | undefined> {
  // ...
}
```

- Bad example:

```ts
function parseTeamSlug(value: string): TeamSlug | null {
  if (!/^[a-z0-9-]+$/.test(value)) {
    return null;
  }

  return value as TeamSlug;
}

async function loadSession(token: string): Promise<Session | undefined> {
  // ...
}
```

- Exceptions or escape hatches: Avoid over-modeling trivial fields. Introduce stronger types where they pull real error-checking forward or clarify domain meaning. Rare framework or public-API contracts that already spell absence out explicitly, such as `...OrNull`, may stay non-`maybe`.
- Review questions: Is the same string or object shape re-validated in multiple layers? Could a tagged union or parser remove nullable or impossible combinations? If the parser or loader returns `null` or `undefined`, does the name advertise that with `maybe`?
- Automation potential: Static tools can catch some unsafe casts or ad hoc runtime checks, but the right boundary model is still a design decision.

## Prefix Nullish Internal Names with `maybe`

- Level: `should`
- Intent: Make nullable and optional flows obvious at the use site, not just in the type annotation.
- Rule: In internal TypeScript and JavaScript code, use `maybe...` for functions, locals, parameters, destructured bindings, and object properties when their value may legitimately be `null` or `undefined`, including Promise-wrapped forms. When a reusable alias materially clarifies a repeated nullable surface, names like `MaybeSession` are appropriate. Do not force a one-off alias when `Session | null` or similar is already clear in place. Public JSON fields, GraphQL schema fields, framework-owned props, and third-party interface names are narrow exceptions; keep their contract name and map them to internal `maybe...` names when helpful.
- Rationale: TS/JS call sites often lose nullable context in the middle of object flow and async code. Consistent `maybe...` naming keeps the absence signal visible even when the type annotation is not in view.
- Good example:

```ts
type MaybeSession = Session | null;

async function maybeLoadSession(maybeToken: string): Promise<MaybeSession> {
  const maybeSession = await loadFromStore(maybeToken);
  return maybeSession;
}

const { profile: maybeProfile } = payload;
const state = { maybeConfigPath: maybeSession?.configPath };
```

- Bad example:

```ts
type SessionOrNull = Session | null;

async function loadSession(token: string | null): Promise<Session | null> {
  const session = await loadFromStore(token);
  return session;
}

const { profile } = payload;
const state = { configPath: session?.configPath };
```

- Exceptions or escape hatches: External contract fields, framework-required prop names, and established third-party interface shapes may keep their original spelling. Keep that exception at the boundary rather than letting non-`maybe` names spread through internal code.
- Review questions: Do nullish locals, params, destructured bindings, and internal properties advertise that possibility in their names? Is a `MaybeX` alias clarifying a repeated surface, or just renaming a one-off union? Is a non-`maybe` name truly forced by an external contract?
- Automation potential: Linters and static analysis can often match `null` or `undefined` types to internal names, but contract exceptions and alias usefulness still need reviewer judgment.

## Testing Notes

Follow the shared testing standard in [../core/testing.md](../core/testing.md). For unit tests, explicit Arrange/Act/Assert sections are the default unless the structure is unmistakable without them.

## Verification Notes

Follow the shared verification standard in [../core/verification.md](../core/verification.md). In TypeScript and JavaScript repositories, prefer repo-owned scripts or task runners first. For new standalone projects, Bun is the preferred default package-manager and script surface; for existing repositories, follow the established local toolchain unless the repo intentionally migrates. Linting, typechecking, build, and test commands are common examples, not a required universal set, and affected-package or changed-path modes are preferred when the repository provides them.
