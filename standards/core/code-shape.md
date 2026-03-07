# Code Shape

This page covers the default expectations for local code structure and readability.

## Prefer Early Returns Over Nesting

- Level: `should`
- Intent: Keep control flow shallow so the main path remains obvious.
- Rule: Prefer guard clauses and early returns over nested conditionals. Exit invalid or boring paths first and keep the main behavior at the left margin.
- Rationale: Deep nesting hides the core behavior, makes refactors riskier, and increases the amount of state a reader has to carry through the function.
- Good example:

```rust
fn send_receipt(maybe_order: Option<Order>) -> Result<(), Error> {
    let Some(order) = maybe_order else {
        return Ok(());
    };

    if !order.is_paid {
        return Ok(());
    }

    deliver(order)
}
```

- Bad example:

```rust
fn send_receipt(maybe_order: Option<Order>) -> Result<(), Error> {
    if let Some(order) = maybe_order {
        if order.is_paid {
            deliver(order)?;
        }
    }

    Ok(())
}
```

- Exceptions or escape hatches: A small amount of nesting is acceptable when it matches the shape of the problem better than a sequence of guard clauses. The goal is clarity, not mechanical flattening.
- Review questions: Can the unhappy path exit sooner? Is the main behavior indented because guards were left inline?
- Automation potential: Linters can catch some unnecessary nesting patterns, but readability still needs reviewer judgment.

## Use Language-Native Guard Constructs

- Level: `should`
- Intent: Express guard-style exits with the clearest construct each language offers.
- Rule: When a language has dedicated guard constructs, prefer them over more indirect control flow. In Rust, use `let...else` when destructuring or extracting values for an early exit makes the function easier to read.
- Rationale: Guard constructs communicate intent directly and reduce ceremony around the "continue only when this value is present or valid" pattern.
- Good example:

```rust
fn issue_refund(maybe_payment: Option<Payment>) -> Result<(), Error> {
    let Some(payment) = maybe_payment else {
        return Ok(());
    };

    if !payment.is_refundable() {
        return Ok(());
    }

    process_refund(payment)
}
```

- Bad example:

```rust
fn issue_refund(maybe_payment: Option<Payment>) -> Result<(), Error> {
    if maybe_payment.is_none() {
        return Ok(());
    }

    let payment = maybe_payment.unwrap();

    if !payment.is_refundable() {
        return Ok(());
    }

    process_refund(payment)
}
```

- Exceptions or escape hatches: If `match`, `if let`, or another form is genuinely clearer for multiple branches, use it. This rule is about clarity, not forcing every extraction through the same syntax.
- Review questions: Is the guard expression direct, or is the function split between a presence check and a later extraction? Does the code use the clearest language feature for the shape of the control flow?
- Automation potential: Rust-specific linting or review tooling can flag some `let...else` opportunities, but not all cases are equally readable.

## Split Large Functions Into Named Pieces

- Level: `should`
- Intent: Keep functions small enough that a reader can understand one concern at a time.
- Rule: When a function grows beyond roughly 200 lines, treat that as a refactor trigger. Break it into sensible helpers, steps, or sub-workflows with names that reveal intent.
- Rationale: Oversized functions usually mix responsibilities, bury important transitions, and make testing harder because the seams are implicit instead of named.
- Good example:

```text
handleCheckout()
  -> parseRequest()
  -> priceCart()
  -> reserveInventory()
  -> buildResponse()
```

- Bad example:

```text
handleCheckout()
  // 230+ lines that parse input, calculate discounts, mutate stock,
  // call payment APIs, map errors, log metrics, and build the response
```

- Exceptions or escape hatches: Generated code and intentionally linear scripts may exceed the threshold. If a larger function is still the clearest representation, leave a short note explaining why splitting it would hurt clarity.
- Review questions: Does the function still represent a single concern? Could named helpers reveal the workflow better than comments or blank lines?
- Automation potential: Length checks are easy to automate, but whether the split is sensible still requires review.

## Split Oversized Files Into Modules

- Level: `should`
- Intent: Keep file boundaries aligned with coherent responsibilities instead of turning one file into a dumping ground.
- Rule: When a source file grows beyond roughly 628 lines of code, treat that as a refactor trigger. Split it into smaller modules organized around clear responsibilities.
- Rationale: Very large files slow navigation, hide architectural seams, and often signal that unrelated concerns have accumulated in one place.
- Good example:

```text
checkout/
  pricing.rs
  validation.rs
  orchestration.rs
  tests.rs
```

- Bad example:

```text
checkout.rs
  // request parsing
  // pricing rules
  // tax logic
  // API adapter
  // persistence
  // error mapping
  // tests
```

- Exceptions or escape hatches: Some files act as intentionally central registries or protocol definitions. Keep those rare, obvious, and documented.
- Review questions: Does the file contain multiple clusters of logic that would be easier to navigate as separate modules? Are tests, adapters, and domain rules all mixed together?
- Automation potential: File-length checks are easy to automate; good module boundaries are not.
