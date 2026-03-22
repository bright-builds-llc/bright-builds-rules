# TypeScript and JavaScript

This page translates the core standards into TypeScript/JavaScript-specific guidance.

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
- Rule: Parse untrusted input into stronger types before it reaches business logic. Use tagged unions, discriminated states, branded types, or factory/parser modules when they make an illegal state impossible or substantially harder to create.
- Rationale: TS/JS cannot enforce as much at runtime as Rust can, but a deliberate parsing layer and stronger types still prevent a large class of mistakes.
- Good example:

```ts
type TeamSlug = string & { readonly __brand: "TeamSlug" };

function parseTeamSlug(value: string): TeamSlug | null {
  if (!/^[a-z0-9-]+$/.test(value)) {
    return null;
  }

  return value as TeamSlug;
}
```

- Bad example:

```ts
function createTeam(slug: string): Team {
  if (!/^[a-z0-9-]+$/.test(slug)) {
    throw new Error("invalid slug");
  }

  return { slug };
}
```

- Exceptions or escape hatches: Avoid over-modeling trivial fields. Introduce stronger types where they pull real error-checking forward or clarify domain meaning.
- Review questions: Is the same string or object shape re-validated in multiple layers? Could a tagged union or parser remove nullable or impossible combinations?
- Automation potential: Static tools can catch some unsafe casts or ad hoc runtime checks, but the right boundary model is still a design decision.

## Testing Notes

Follow the shared testing standard in [../core/testing.md](../core/testing.md). For unit tests, explicit Arrange/Act/Assert sections are the default unless the structure is unmistakable without them.

## Verification Notes

Follow the shared verification standard in [../core/verification.md](../core/verification.md). In TypeScript and JavaScript repositories, prefer repo-owned scripts or task runners first, then Bun/npm/pnpm/yarn script surfaces, then framework-native checks when needed. Linting, typechecking, build, and test commands are common examples, not a required universal set, and affected-package or changed-path modes are preferred when the repository provides them.
