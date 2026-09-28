# Implementation Plan: Gestão de Transações e Projeções Financeiras (Transactions API Test Automation)

**Branch**: `003-transactions-management` | **Date**: 2026-09-28 | **Spec**: [specs/003-transactions-management/spec.md](spec.md)

**Input**: Feature specification from `specs/003-transactions-management/spec.md`

## Summary

Implementação de uma suíte exaustiva de testes automatizados de API em Karate DSL cobrindo 100% dos contratos OpenAPI, regras de negócio de status temporal (`EFETIVADA` vs `AGENDADA`), precisão decimal monetária, filtros combinados de consulta, projeções orçamentárias mensais (`/projections`), isolamento multi-tenant (IDOR/BOLA), e impacto/reversão de saldo nas contas vinculadas.

A solução técnica adota Java 21 LTS e Karate DSL JUnit 5 com execução paralela (3 threads), desacoplamento de payloads em `src/test/resources/data/payloads/transactions/`, schemas de contrato com Karate fuzzy matchers em `src/test/resources/data/schemas/transactions/`, e provisionamento dinâmico de usuários e contas via `auth-helper.feature` em cumprimento ao Princípio VII da Constituição (DRY Helpers).

## Technical Context

**Language/Version**: Java 21 LTS (Maven compiler source/target 21)

**Primary Dependencies**: Karate DSL (`karate-junit5` 1.5.2), Net Datafaker (`datafaker` 2.4.2), JUnit 5 Test Platform (`maven-surefire-plugin` 3.2.5)

**Storage**: N/A (Repositório exclusivo de testes de aceitação e contrato; validação do banco de dados da aplicação ocorre estritamente via camada HTTP sem acoplamento a JDBC)

**Testing**: Karate DSL (`karate-junit5` 1.5.2) executado através de `features.TestRunner`

**Target Platform**: JVM 21 em ambiente Linux / CI-CD Runners (Maven CLI)

**Project Type**: Suíte de Automação de Testes de API (BDD / Especificação Executável em Karate DSL)

**Performance Goals**: Execução paralela em 3 threads; suíte completa de Transações executada com sucesso respeitando as janelas de retry do rate limit de autenticação da API (5 req/min); 0% de falhas intermitentes por colisão de dados

**Constraints**:
- Princípio I: Independência e paralelismo estrito (cenários autocontidos, provisionamento dinâmico em runtime)
- Princípio II: Desacoplamento de payloads em `src/test/resources/data/payloads/transactions/`
- Princípio III: Geração dinâmica de dados via `DataGenerator` e `java.time.LocalDate`
- Princípio IV: Zero exposição de segredos em código versionado e logs
- Princípio V: Tagging padronizado (`@transactions`, `@smoke`, `@regression`, `@create`, `@list`, `@projections`, `@detail`, `@delete`, `@idor`)
- Princípio VI: Matriz completa de cobertura de status codes (200, 201, 204, 401, 404, 422)
- Princípio VII: Reusabilidade obrigatória via `auth-helper.feature` com `karate.call` (eliminação de duplicação inline de cadastro e login)

**Scale/Scope**: 5 endpoints (`POST /api/v1/transactions/`, `GET /api/v1/transactions/`, `GET /api/v1/transactions/projections`, `GET /api/v1/transactions/{transaction_id}`, `DELETE /api/v1/transactions/{transaction_id}`), 33 cenários BDD categorizados em 5 User Stories, schemas contratuais principais (`TransactionResponse`, `TransactionCreate`, `TransactionProjectionsResponse`, `HTTPValidationError`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio Constitucional | Requisito do Projeto | Status | Evidência / Mecanismo de Conformidade |
| :--- | :--- | :--- | :--- |
| **I. Test Independence & Parallel Safety** | Scenarios autocontidos, idempotentes, 3 threads paralelas | **PASS** | Cada cenário provisiona seus próprios usuários e contas via `auth-helper.feature`; zero estado compartilhado entre threads. |
| **II. Payload Decoupling & Schema Payloads** | Payloads desacoplados em `src/test/resources/data/payloads/` | **PASS** | Payload base `transaction-create-request.json` externalizado; schemas sob `schemas/transactions/`. |
| **III. Dynamic Data & Synthetic Generation** | Uso de Datafaker (`pt-BR`) e `java.time.LocalDate` | **PASS** | Datas calculadas dinamicamente ($D_{-1}$, $D_0$, $D_{+5}$); valores e descrições gerados via Java/Datafaker. |
| **IV. Zero-Secret Exposure & Parity** | Zero credenciais no git, configuração por ambiente | **PASS** | `environments.json` e `credentials-reader.js` com variáveis de ambiente; mascaramento no `logback-test.xml`. |
| **V. Living Specifications & Tagging** | Especificações executáveis com tags estruturadas | **PASS** | Features organizadas com tags `@transactions`, `@smoke`, `@create`, `@list`, `@projections`, `@detail`, `@delete`, `@idor`. |
| **VI. Mandatory QA Coverage Matrix** | Happy path, boundaries, 401, 404, 422 | **PASS** | Matriz com 33 cenários cobrindo 100% dos status codes definidos e regras de IDOR e totalizadores mensais. |
| **VII. Code Reusability & DRY Helpers** | Helpers reutilizáveis obrigatórios via `karate.call` | **PASS** | Todos os cenários que requerem contexto autenticado utilizam `auth-helper.feature` via `karate.call`. |

**Avaliação dos Gates**: Todos os 7 princípios constitucionais aprovados. Nenhuma violação detectada.

## Project Structure

### Documentation (this feature)

```text
specs/003-transactions-management/
├── spec.md              # Feature specification com 33 cenários BDD
├── plan.md              # Este arquivo (Implementation Plan)
├── research.md          # Phase 0: Decisões técnicas, status temporal e projeções
├── data-model.md        # Phase 1: Entidades, diagramas e limites de dados
├── quickstart.md        # Phase 1: Guia prático de comandos Maven
└── contracts/           # Phase 1: Especificações e contratos de schema
    ├── transactions-endpoints.md
    ├── transaction-create-request.json
    ├── transaction-response.json
    ├── transaction-list-schema.json
    └── transaction-projections-response.json
```

### Source Code Layout (Implementação dos Testes)

```text
src/test/
├── java/
│   ├── features/
│   │   ├── transactions/
│   │   │   ├── transactions-create.feature         # POST /api/v1/transactions/
│   │   │   ├── transactions-list.feature           # GET /api/v1/transactions/
│   │   │   ├── transactions-projections.feature    # GET /api/v1/transactions/projections
│   │   │   ├── transactions-get.feature            # GET /api/v1/transactions/{transaction_id}
│   │   │   └── transactions-delete.feature         # DELETE /api/v1/transactions/{transaction_id}
│   │   ├── accounts/                               # Suíte do Módulo 002 (existente)
│   │   ├── auth/                                   # Suíte do Módulo 001 (existente)
│   │   └── helpers/
│   │       └── auth-helper.feature                 # Helper reutilizável de autenticação (DRY)
│   └── utils/
│       ├── CredentialUtils.java
│       └── DataGenerator.java
└── resources/
    ├── data/
    │   ├── payloads/transactions/
    │   │   └── transaction-create-request.json
    │   └── schemas/transactions/
    │       ├── transaction-response-schema.json
    │       ├── transaction-list-schema.json
    │       └── transaction-projections-schema.json
    ├── config/environments.json
    └── karate-config.js
```

---

## Phases

### Phase 0: Research (Concluído)
- Decisões consolidadas em `research.md` (resolução dinâmica de datas, precisão decimal, IDOR e reversibilidade de saldo).

### Phase 1: Design & Contracts (Concluído)
- Modelo de dados estruturado em `data-model.md`.
- Contratos e schemas com Karate fuzzy matchers gerados em `contracts/`.
- Guia de execução rápida gerado em `quickstart.md`.

### Phase 2: Implementation & Tasks (Próximo Passo)
- Executar `/speckit-tasks` para gerar `tasks.md` ordenado por dependências e fases de entrega incremental.
