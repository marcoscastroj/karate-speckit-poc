# Implementation Plan: Gestão de Portfólio de Investimentos (Investments API Test Automation)

**Branch**: `004-investments-portfolio` | **Date**: 2026-09-28 | **Spec**: [specs/004-investments-portfolio/spec.md](spec.md)

**Input**: Feature specification from `specs/004-investments-portfolio/spec.md`

## Summary

Implementação de uma suíte de automação de testes de API em Karate DSL cobrindo 100% dos contratos OpenAPI, regras de negócio de custódia de investimentos, validações de enums (`InvestmentClass`), restrições numéricas/strings, cálculos de métricas derivadas (`total_investido`, `patrimonio_atual`, `lucro_prejuizo_absoluto`, `rentabilidade_percentual`), consolidação global de carteira (`/investments/summary`), invariante de 100% na alocação de classes e isolamento estrito de dados entre usuários (multi-tenancy / IDOR).

A solução técnica adota Java 21 LTS e Karate DSL JUnit 5 com execução paralela em 3 threads, desacoplamento de payloads em `src/test/resources/data/payloads/investments/`, schemas de contrato com Karate fuzzy matchers em `src/test/resources/data/schemas/investments/`, helper de setup `investment-helper.feature` e provisionamento dinâmico de contas via `auth-helper.feature` em cumprimento integral à Constituição de Automação de Testes do projeto.

## Technical Context

**Language/Version**: Java 21 LTS (Maven compiler source/target 21)

**Primary Dependencies**: Karate DSL (`karate-junit5` 1.5.2), Net Datafaker (`datafaker` 2.4.2), JUnit 5 Test Platform (`maven-surefire-plugin` 3.2.5)

**Storage**: N/A (Repositório de automação de testes de API / BDD; interações com a base de dados ocorrem estritamente através das interfaces HTTP REST da aplicação)

**Testing**: Karate DSL (`karate-junit5` 1.5.2) executado via JUnit 5 runner central (`features.TestRunner`)

**Target Platform**: JVM 21 em ambiente Linux / CI-CD Runners (Maven CLI)

**Project Type**: Suíte de Automação de Testes de API (BDD / Living Specification em Karate DSL)

**Performance Goals**: Execução paralela em 3 threads sem conflito ou concorrência de dados; 100% de cenários idempotentes e independentes; tempo total de execução otimizado.

**Constraints**:
- Princípio I: Independência e paralelismo estrito (cenários autocontidos, provisionamento dinâmico em runtime)
- Princípio II: Desacoplamento de payloads em `src/test/resources/data/payloads/investments/`
- Princípio III: Geração dinâmica de dados via `DataGenerator` e sufixos aleatórios para tickers
- Princípio IV: Zero exposição de segredos em código versionado e logs
- Princípio V: Tagging padronizado (`@investments`, `@smoke`, `@regression`, `@create`, `@summary`, `@list`, `@detail`, `@update`, `@delete`, `@idor`)
- Princípio VI: Matriz completa de cobertura de status codes (200, 201, 204, 401, 404, 422)
- Princípio VII: Reusabilidade obrigatória via `auth-helper.feature` e `investment-helper.feature` com `karate.call` (eliminação de duplicação inline de setup)

**Scale/Scope**: 6 operações de endpoint (`POST /api/v1/investments/`, `GET /api/v1/investments/`, `GET /api/v1/investments/summary`, `GET /api/v1/investments/{investment_id}`, `PUT /api/v1/investments/{investment_id}`, `DELETE /api/v1/investments/{investment_id}`), 41 cenários BDD categorizados em 6 User Stories, schemas contratuais (`InvestmentResponse`, `InvestmentCreate`, `InvestmentUpdate`, `PortfolioSummaryResponse`, `ClassAllocation`, `HTTPValidationError`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Princípio Constitucional | Requisito do Projeto | Status | Evidência / Mecanismo de Conformidade |
| :--- | :--- | :--- | :--- |
| **I. Test Independence & Parallel Safety** | Cenários autocontidos, idempotentes, 3 threads paralelas | **PASS** | Cada cenário provisiona seus próprios usuários via `auth-helper.feature`; posições criadas no próprio teste; zero dependência de dados entre cenários. |
| **II. Payload Decoupling & Schema Payloads** | Payloads desacoplados em `src/test/resources/data/payloads/` | **PASS** | Payloads base `investment-create-request.json` e `investment-update-request.json` externalizados; schemas fuzzy matchers sob `schemas/investments/`. |
| **III. Dynamic Data & Synthetic Generation** | Uso de Datafaker (`pt-BR`) e tickers/nomes dinâmicos | **PASS** | Nomes de ativos e identificadores gerados com sufixos aleatórios; valores numéricos parametrizados sem dados sensíveis. |
| **IV. Zero-Secret Exposure & Parity** | Zero credenciais no git, configuração por ambiente | **PASS** | `environments.json` e `credentials-reader.js` com variáveis de ambiente; mascaramento de headers sensíveis no `logback-test.xml`. |
| **V. Living Specifications & Tagging** | Especificações executáveis com tags estruturadas | **PASS** | Features organizadas com tags `@investments`, `@smoke`, `@create`, `@summary`, `@list`, `@detail`, `@update`, `@delete`, `@idor`. |
| **VI. Mandatory QA Coverage Matrix** | Happy path, boundaries, 401, 404, 422 | **PASS** | Matriz com 41 cenários cobrindo 100% dos status codes definidos, validações de limites, IDOR e agregação multi-classe. |
| **VII. Code Reusability & DRY Helpers** | Helpers reutilizáveis obrigatórios via `karate.call` | **PASS** | Todos os cenários autenticados consomem `auth-helper.feature` via `karate.call`; setup de custódia reutilizável via `investment-helper.feature`. |

**Avaliação dos Gates**: Todos os 7 princípios constitucionais aprovados. Nenhuma violação detectada.

## Project Structure

### Documentation (this feature)

```text
specs/004-investments-portfolio/
├── spec.md              # Feature specification com 41 cenários BDD
├── plan.md              # Este arquivo (Implementation Plan)
├── research.md          # Phase 0: Decisões técnicas, precisão float e agregação
├── data-model.md        # Phase 1: Entidades, diagramas e regras de cálculo
├── quickstart.md        # Phase 1: Guia prático de comandos Maven e execução
└── contracts/           # Phase 1: Especificações e contratos de schema
    ├── investments-endpoints.md
    ├── investment-create-request.json
    ├── investment-update-request.json
    ├── investment-response.json
    ├── investment-list-schema.json
    ├── portfolio-summary-response.json
    └── class-allocation-schema.json
```

### Source Code Layout (Implementação dos Testes)

```text
src/test/
├── java/
│   ├── features/
│   │   ├── investments/
│   │   │   ├── investments-create.feature         # POST /api/v1/investments/
│   │   │   ├── investments-summary.feature        # GET /api/v1/investments/summary
│   │   │   ├── investments-list.feature           # GET /api/v1/investments/
│   │   │   ├── investments-get.feature            # GET /api/v1/investments/{id}
│   │   │   ├── investments-update.feature         # PUT /api/v1/investments/{id}
│   │   │   ├── investments-delete.feature         # DELETE /api/v1/investments/{id}
│   │   │   └── investments-idor.feature           # Testes de isolamento multi-tenant (IDOR)
│   │   ├── transactions/                          # Suíte do Módulo 003
│   │   ├── accounts/                              # Suíte do Módulo 002
│   │   ├── auth/                                  # Suíte do Módulo 001
│   │   └── helpers/
│   │       ├── auth-helper.feature                # Helper reutilizável de autenticação (existente)
│   │       └── investment-helper.feature          # Helper reutilizável de criação de posição
│   └── utils/
│       ├── CredentialUtils.java
│       └── DataGenerator.java
└── resources/
    ├── data/
    │   ├── payloads/investments/
    │   │   ├── investment-create-request.json
    │   │   └── investment-update-request.json
    │   └── schemas/investments/
    │       ├── investment-response-schema.json
    │       ├── investment-list-schema.json
    │       ├── portfolio-summary-schema.json
    │       └── class-allocation-schema.json
    └── config/
        ├── environments.json
        └── credentials-reader.js
```

## Phase 0 & Phase 1 Execution Checklist

- [x] **Phase 0 Research**: Decisões técnicas de ponto flutuante, invariante de alocação de carteira (100%), testes de IDOR e helper de fixture documentadas em `research.md`.
- [x] **Phase 1 Data Model**: Entidades `Investment`, `PortfolioSummary`, `ClassAllocation`, limites contratuais e diagramas documentados em `data-model.md`.
- [x] **Phase 1 Contracts**: 6 endpoints documentados em `investments-endpoints.md` e schemas/payloads JSON criados sob `contracts/`.
- [x] **Phase 1 Quickstart**: Guia de execução Maven com comandos por tag documentado em `quickstart.md`.
- [x] **Re-avaliação da Constituição**: Gates constitucionais pós-design validados com 100% de conformidade.
