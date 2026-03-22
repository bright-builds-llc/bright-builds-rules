# Rust

This page translates the core standards into Rust-specific guidance.

## Use `let...else` for Guard-Style Extraction

- Level: `should`
- Intent: Keep Rust control flow shallow and make early exits obvious.
- Rule: When a function needs to extract from `Option`, `Result`, or pattern-matched input before proceeding, prefer `let...else` if it expresses the guard more directly than `match` or a split presence check.
- Rationale: Rust offers a concise construct for "continue only if this value fits the shape I need." Using it well reinforces the broader early-return rule and avoids scattered extraction logic.
- Good example:

```rust
fn load_customer_id(maybe_customer: Option<Customer>) -> Result<CustomerId, Error> {
    let Some(customer) = maybe_customer else {
        return Err(Error::NotFound);
    };

    Ok(customer.id)
}
```

- Bad example:

```rust
fn load_customer_id(maybe_customer: Option<Customer>) -> Result<CustomerId, Error> {
    if maybe_customer.is_none() {
        return Err(Error::NotFound);
    }

    Ok(maybe_customer.unwrap().id)
}
```

- Exceptions or escape hatches: Use `match` for true multi-branch logic or when the branch bodies are the point of the code. `let...else` is for the focused guard case.
- Review questions: Is extraction and guard logic split apart? Is there a later `unwrap` that should have been eliminated by a guard?
- Automation potential: Static analysis can catch obvious `is_none` plus `unwrap` sequences, but readable use still needs reviewer judgment.

## Encode Invariants with Newtypes and Enums

- Level: `must`
- Intent: Use Rust's type system to move business guarantees out of comments and into code.
- Rule: Prefer newtypes, enums, and fallible constructors for domain invariants. Parse raw values into richer domain types before they reach core business functions.
- Rationale: Rust gives strong affordances for making illegal states unrepresentable. Lean on them to prevent accidental misuse and to make function signatures communicate real guarantees.
- Good example:

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
struct EmailAddress(String);

impl TryFrom<String> for EmailAddress {
    type Error = EmailError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        if !value.contains('@') {
            return Err(EmailError::Invalid);
        }

        Ok(Self(value))
    }
}

fn send_invite(email: EmailAddress) -> InviteJob {
    InviteJob { email }
}
```

- Bad example:

```rust
fn send_invite(email: String) -> Result<InviteJob, EmailError> {
    if !email.contains('@') {
        return Err(EmailError::Invalid);
    }

    Ok(InviteJob { email })
}
```

- Exceptions or escape hatches: Do not create wrappers with no semantic value. Introduce them when they clarify business meaning, guarantee an invariant, or prevent confusion between similar primitives.
- Review questions: Does a `String`, `Vec`, or `u64` stand in for a richer domain concept? Are invariants enforced once during parsing or re-checked throughout the workflow?
- Automation potential: Clippy cannot infer business meaning, so this remains primarily a design review rule.

## Keep Adapters Thin Around a Pure Core

- Level: `should`
- Intent: Preserve a clean split between Rust domain logic and infrastructure code.
- Rule: Organize Rust modules so domain decisions are pure where practical, while HTTP handlers, CLI entrypoints, database adapters, and background jobs remain thin imperative shells.
- Rationale: This structure makes Rust code faster to test and easier to evolve because the volatile framework layer does not own the core business decisions.
- Good example:

```text
src/
  domain/
    pricing.rs
    promotions.rs
  adapters/
    postgres.rs
    http.rs
  application/
    checkout.rs
```

- Bad example:

```text
src/
  checkout.rs
    // pricing logic
    // SQL
    // HTTP mapping
    // telemetry
```

- Exceptions or escape hatches: Small command-line utilities may live in a single file if the behavior is still obvious and effect-light. Even there, extract pure helpers once the logic becomes reusable or business-critical.
- Review questions: Can the pricing, validation, or state-transition logic run without an adapter present? Are modules grouped by framework instead of by business meaning?
- Automation potential: Module structure can be inspected mechanically, but architectural quality still needs human review.

## Testing Notes

Follow the shared testing standard in [../core/testing.md](../core/testing.md). In Rust, explicit Arrange/Act/Assert comments are the default for unit tests, especially once setup grows beyond a line or two.

## Verification Notes

Follow the shared verification standard in [../core/verification.md](../core/verification.md). In Rust repositories, common verification surfaces include `cargo fmt`, `cargo clippy`, `cargo build`, and `cargo test`, but treat those as examples rather than a mandatory universal sequence. Prefer the repo's own Rust-oriented verify/check entrypoint when it exists, and scope runs to the affected crate, package, or workspace when the repository supports that.
