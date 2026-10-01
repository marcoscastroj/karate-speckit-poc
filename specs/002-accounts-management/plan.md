# Implementation Plan: Gestão de Contas e Carteiras (Accounts API Test Automation)

**Branch**: `002-accounts-management` | **Date**: 2026-09-28 | **Spec**: [specs/002-accounts-management/spec.md](spec.md)

**Input**: Feature specification from `specs/002-accounts-management/spec.md`

## Summary

Implementação de uma suíte exaustiva de testes automatizados de API em Karate DSL cobrindo 100% dos contratos OpenAPI, regras de negócio, limites de schema, autenticação/autorização, multi-tenancy com isolamento de usuários (defesa contra IDOR/BOLA), cálculo dinâmico de saldo contábil (`saldo_calculado`) e integridade referencial para o módulo `Accounts` do sistema Finance Organizer.

A abordagem técnica adota Java 21 LTS e Karate DSL JUnit 5 com execução paralela (3 threads), desacoplamento de payloads externos sob `src/test/resources/data/payloads/accounts/`, schemas de contrato com Karate fuzzy matchers sob `src/test/resources/data/schemas/accounts/`, provisionamento dinâmico de usuários via `auth-helper.feature` em cumprimento ao Princípio VII da Constituição (DRY Helpers), e asserções estritas de caixa-preta via REST sem acoplamento a drivers JDBC.

## Technical Context

**Language/Version**: Java 21 LTS (Maven compiler source/target configurado para 21)

**Primary Dependencies**: Karate DSL (`karate-junit5` 1.5.2), Net Datafaker (`datafaker` 2.4.2), JUnit 5 Test Platform (`maven-surefire-plugin` 3.2.5)

**Storage**: N/A (Repositório exclusivo de testes de aceitação e contrato de API; o banco de dados da aplicação sob teste é verificado estritamente via camada HTTP sem dependência de drivers JDBC)

**Testing**: Karate DSL (`karate-junit5` 1.5.2) executado através de `features.TestRunner`

**Target Platform**: JVM 21 em ambiente Linux / CI-CD Runners (Maven CLI)

**Project Type**: Suíte de Automação de Testes de API (BDD / Especificação Executável em Karate DSL)

**Performance Goals**: Execução paralela em 3 threads; suíte completa de Contas executada em menos de 45 segundos localmente; 0% de falhas intermitentes por colisão de dados

**Constraints**:
- Princípio I: Independência e paralelismo estrito (cenários autocontidos, provisionamento dinâmico em runtime)
- Princípio II: Desacoplamento de payloads em `src/test/resources/data/payloads/accounts/`
- Princípio III: Geração dinâmica de dados via `DataGenerator`
- Princípio IV: Zero exposição de segredos em código versionado e logs
- Princípio V: Tagging padronizado (`@accounts`, `@smoke`, `@regression`, `@create`, `@list`, `@detail`, `@update`, `@delete`, `@idor`)
- Princípio VI: Matriz completa de cobertura de status codes (200, 201, 204, 400/409, 401, 404, 422)
- Princípio VII: Reusabilidade obrigatória via `auth-helper.feature` com `karate.call` (eliminação de duplicação inline de cadastro e login)

**Scale/Scope**: 5 endpoints (`POST /api/v1/accounts/`, `GET /api/v1/accounts/`, `GET /api/v1/accounts/{account_id}`, `PUT /api/v1/accounts/{account_id}`, `DELETE /api/v1/accounts/{account_id}`), 37 cenários BDD categorizados em 5 User Stories, 3 schemas contratuais principais (`AccountResponse`, `AccountCreate`, `AccountUpdate`, `HTTPValidationError`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio Constitucional | Requisito do Projeto | Status | Evidência / Mecanismo de Conformidade |
| :--- | :--- | :--- | :--- |
| **I. Test Independence & Parallel Safety** | Scenarios autocontidos, idempotentes, 3 threads paralelas | **PASS** | Cada cenário provisiona seus próprios usuários via `auth-helper.feature`; zero estado compartilhado entre threads. |
| **II. Payload Decoupling & Schema Payloads** | Payloads desacoplados em `src/test/resources/data/payloads/` | **PASS** | Payloads base `account-create-request.json` e `account-update-request.json` externalizados; schemas em `schemas/accounts/`. |
| **III. Dynamic Data & Synthetic Generation** | Uso de Datafaker (`pt-BR`) via `DataGenerator` | **PASS** | Nomes de contas e identificadores gerados dinamicamente; senhas e e-mails gerados via `DataGenerator.java`. |
| **IV. Zero-Secret Exposure & Parity** | Zero credenciais no git, configuração por ambiente | **PASS** | `environments.json` e `credentials-reader.js` com variáveis de ambiente e `.env`; mascaramento no `logback-test.xml`. |
| **V. Living Specifications & Tagging** | Especificações executáveis com tags estruturadas | **PASS** | Features organizadas com tags `@accounts`, `@smoke`, `@regression`, `@create`, `@list`, `@detail`, `@update`, `@delete`, `@idor`. |
| **VI. Mandatory QA Coverage Matrix** | Happy path, boundaries, 401, 403, 404, 409, 422 | **PASS** | Matriz com 37 cenários cobrindo 100% dos status codes definidos e regras de IDOR e saldo dinâmico. |
| **VII. Code Reusability & DRY Helpers** | Helpers reutilizáveis obrigatórios via `karate.call` | **PASS** | Todos os cenários que requerem contexto autenticado utilizam `auth-helper.feature` via `karate.call`. |

**Avaliação dos Gates**: Todos os 7 princípios constitucionais aprovados. Nenhuma violação detectada.

## Project Structure

### Documentation (this feature)

```text
specs/002-accounts-management/
├── spec.md              # Feature specification com 37 cenários BDD
├── plan.md              # Este arquivo (Implementation Plan)
├── research.md          # Phase 0: Decisões técnicas, IDOR e saldo dinâmico
├── data-model.md        # Phase 1: Entidades, diagramas e limites de dados
├── quickstart.md        # Phase 1: Guia prático de comandos Maven
└── contracts/           # Phase 1: Especificações e contratos de schema
    ├── accounts-endpoints.md
    ├── account-create-request.json
    ├── account-update-request.json
    └── account-response.json
```

### Source Code Layout (Implementação dos Testes)

```text
src/test/
├── java/
│   ├── features/
│   │   ├── accounts/
│   │   │   ├── accounts-create.feature    # POST /api/v1/accounts/
│   │   │   ├── accounts-list.feature      # GET /api/v1/accounts/
│   │   │   ├── accounts-get.feature       # GET /api/v1/accounts/{account_id}
│   │   │   ├── accounts-update.feature    # PUT /api/v1/accounts/{account_id}
│   │   │   └── accounts-delete.feature    # DELETE /api/v1/accounts/{account_id}
│   │   └── helpers/
│   │       └── auth-helper.feature        # Helper reutilizável de autenticação (DRY)
│   └── utils/
│       ├── CredentialUtils.java           # Utilitário de credenciais e .env
│       └── DataGenerator.java             # Gerador dinâmico Datafaker pt-BR
└── resources/
    ├── data/
    │   ├── payloads/accounts/
    │   │   ├── account-create-request.json
    │   │   └── account-update-request.json
    │   └── schemas/accounts/
    │       ├── account-response-schema.json
    │       └── account-list-schema.json
    ├── config/environments.json
    └── karate-config.js
```
