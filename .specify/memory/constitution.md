<!--
# Sync Impact Report
- **Version Change**: 1.1.0 -> 1.2.0
- **Principles Established / Modified**:
  - Principle VII: Code Reusability & DRY Helpers (Added: mandatory use of reusable helpers like auth-helper.feature for secondary authentication flows via karate.call)
  - Principle IV: Zero-Secret Exposure & Environment Parity (Clarified: formal inclusion of .env and credentials.properties layered resolution)
- **Added Sections / Constraints**:
  - Framework Ecosystem & Skills Compliance: Formalized mandatory compliance with .agents/skills/karate-* in Technical Constraints & Quality Standards
  - Secrets & Local Configuration: Documented .env and credentials.properties hierarchy and .env.example template
- **Removed Sections**: None
- **Deferred Items / TODOs**: None
-->

# Karate DSL Test Automation Architecture Constitution

## Core Principles

### I. Test Independence & Parallel Safety (NON-NEGOTIABLE)
Every test scenario MUST be completely self-contained, idempotent, and stateless. Scenarios MUST NOT depend on the execution order, data state, or side effects of preceding or concurrent scenarios. Tests execute concurrently in parallel (configured for 3 threads via JUnit 5 `TestRunner`); sharing mutable state across scenarios or threads is strictly forbidden.
*Rationale: Test suites must execute reliably and predictably in CI/CD without intermittent flakiness, order coupling, or cross-thread race conditions.*

### II. Payload Decoupling & Schema-Driven Payloads
Static request and response JSON structures MUST reside in external payload files under `src/test/resources/data/payloads/` and remain decoupled from test logic. Scenarios MUST load base templates and modify dynamic fields using `* set payload.field = value`. Response assertions MUST validate structural schemas and fuzzy matchers (`#string`, `#number`, `#regex`, etc.) rather than brittle exact values where dynamic data is involved.
*Rationale: Keeping data contracts externalized prevents bloated feature files, simplifies payload maintenance, and makes contract evolution transparent.*

### III. Dynamic Data & Synthetic Generation
All ephemeral and transient test data (names, emails, phone numbers, identifiers) MUST be generated dynamically at runtime using `DataGenerator` backed by Datafaker (`pt-BR`). Hardcoding synthetic personal data, static account credentials, or reused entity names directly in feature files is prohibited.
*Rationale: Dynamic data generation ensures record uniqueness, avoids database collision during parallel test runs, and enforces realistic data patterns without risking PII exposure.*

### IV. Zero-Secret Exposure & Environment Parity
Credentials, authorization tokens, API keys, and sensitive secrets MUST NOT be hardcoded in feature files, Java code, configuration JSON, or version control. Secrets MUST be loaded via `credentials-reader.js` and `CredentialUtils` following a strict resolution hierarchy: OS environment variables > JVM System Properties (`-Dkey=value`) > local `.env` or `credentials.properties` files (strictly ignored by `.gitignore`) > safe development fallbacks. Multi-environment targets (`dev`, `qa`, `e2e`) and connection timeouts MUST be declared centrally in `src/test/resources/config/environments.json` and activated via `-Dkarate.env`. The primary baseline endpoint for testing development and integration execution MUST target `http://100.75.210.114:8000` as the standard host for the Finance Organizer API under test.
*Rationale: Protects infrastructure credentials from accidental leakage and ensures the exact same test suites run across environments without code modifications.*

### V. Living Specifications & Tagging Discipline
Feature files MUST act as executable specifications. Scenarios and step descriptions MUST clearly articulate business intent and expected API behavior. Every scenario MUST assert HTTP status codes and valid payload responses. Suites MUST use structured tags (e.g., `@smoke`, `@regression`, `@users`). Incomplete, broken, or work-in-progress scenarios MUST be tagged with `@ignore` so they do not break continuous integration builds.
*Rationale: Bridges technical tests and domain specifications, providing reliable living documentation while enabling flexible, selective test execution.*

### VI. Mandatory QA Coverage Matrix & Status Code Assertions
Every feature specification generated for an endpoint MUST explicitly provide test scenarios for:
1. **Happy Path**: Successful creation/retrieval (200/201/204) asserting the complete response schema against `openapi.json`.
2. **Payload & Boundary Validations**: Negative flows (400 or 422) for missing required fields, empty strings, invalid types, and business boundary limits defined.
3. **Authentication & Authorization**: Missing/invalid token (401) and forbidden access (403), where secured.
4. **Resource Non-Existence**: Not found flows (404) for random or non-existent IDs.
5. **Business Conflict**: Duplicate resource or unique-constraint violation (409 Conflict), where applicable.
*Rationale: Guarantees comprehensive, contract-level test coverage across all HTTP status codes, edge cases, and failure modes.*

### VII. Code Reusability & DRY Helpers (NON-NEGOTIABLE)
Test scenarios MUST eliminate boilerplate and repetitive operational setup by leveraging modular, reusable helper features (tagged with `@ignore` and located under `src/test/java/features/helpers/`, such as `auth-helper.feature`). For any scenario testing downstream business logic (e.g., account management, transactions) where authentication is a prerequisite rather than the target under test, scenarios MUST consume the canonical authentication helper using `karate.call` to provision a fresh, isolated user and session on-the-fly. Inline duplication of registration and login HTTP calls within secondary scenarios is strictly forbidden. The use of `karate.callonce` is restricted to strictly immutable, read-only global contexts to preserve Principle I (Test Independence).
*Rationale: Prevents massive code duplication, simplifies scenario maintenance, and accelerates authoring without sacrificing scenario isolation and parallel execution safety.*

## Technical Constraints & Quality Standards

- **Target Environment & Host**: The authoritative test execution target for the Finance Organizer API under test is `http://100.75.210.114:8000`, configured as the baseline `baseUrl` in `src/test/resources/config/environments.json`.
- **Runtime & Language**: Java 21 LTS with Maven compiler source and target set to version 21.
- **Framework Ecosystem & Skills Compliance**: Karate DSL (`karate-junit5` 1.5.2), Net Datafaker (2.4.2), and JUnit 5 test platform. All test authoring, secret management, reusability patterns, and execution routines MUST strictly comply with the architectural runbooks and guidelines defined in `.agents/skills/karate-*` (`karate-dsl`, `karate-authoring`, `karate-data-and-secrets`, `karate-reusability-and-dry`, `karate-execution-and-ops`).
- **Directory Layout**: Dedicated test architecture organized under `src/test/` (`java/features/`, `java/utils/`, `resources/config/`, `resources/data/payloads/`, `resources/utils/`). No application production code under `src/main/`.
- **Logging & Privacy**: Karate logging managed via `src/test/resources/logback-test.xml`. Authorization headers and sensitive payload fields MUST NOT be emitted in plain text within persistent test logs.
- **Execution Reports**: Standard HTML execution summaries MUST be generated under `target/karate-reports/karate-summary.html` upon suite completion.

## Development Workflow & Quality Gates

- **Specification-First Cycle**: Before implementing or extending test suites, features MUST be specified and planned using Spec Kit workflows (`/speckit-specify` -> `/speckit-plan` -> `/speckit-tasks`).
- **Skills-Driven Authoring**: Automated agents and engineers implementing tasks MUST activate and enforce the relevant `.agents/skills/karate-*` skills during planning and execution phases.
- **Pre-Commit Verification**: Developers and QA engineers MUST verify test execution locally with `mvn test` (or scoped tags via `mvn test -Dkarate.tags="@<tag>"`) before opening a pull request.
- **Zero-Failure Standard**: CI test runs MUST complete with zero failures (`results.getFailCount() == 0`). Any broken test MUST be resolved immediately or temporarily flagged with `@ignore` alongside an associated tracking ticket.
- **Code Review Verification**: Every pull request MUST be reviewed for thread safety, proper payload isolation, DRY helper usage, and zero-secret exposure before merging into main branches.

## Governance

This Constitution is the authoritative source of architectural principles, testing rules, and quality standards for the `karate-speckit-poc` repository. It supersedes all informal team practices or ad-hoc conventions.

- **Amendments**: Amendments require a formal pull request modifying this document, explicit justification of changes, a semantic version bump, and peer approval.
- **Versioning Policy**:
  - **MAJOR**: Incompatible principle removals, fundamental structural overhauls, or relaxing mandatory safety constraints.
  - **MINOR**: Addition of new principles, new quality gates, or material expansion of existing guidance.
  - **PATCH**: Clarifications, grammatical fixes, formatting updates, and non-semantic refinements.
- **Compliance & Auditing**: All code reviews and automated checks MUST enforce compliance with this constitution. Any deviation or technical debt MUST be documented with an issue ticket and bounded time frame.

**Version**: 1.2.0 | **Ratified**: 2026-09-21 | **Last Amended**: 2026-09-28
