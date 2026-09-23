# Implementation Plan: Autenticação e Gestão de Usuário (Auth API Test Automation)

**Branch**: `001-auth-user-management` | **Date**: 2026-09-23 | **Spec**: [specs/001-auth-user-management/spec.md](spec.md)

**Input**: Feature specification from `specs/001-auth-user-management/spec.md`

## Summary

Implementação de uma suíte exaustiva de testes automatizados de API em Karate DSL cobrindo 100% das regras de negócio, limites de schema, autenticação/autorização e integridade transacional em cascata para o módulo `Auth` do sistema Finance Organizer.

A abordagem técnica adota Java 21 LTS e Karate DSL JUnit 5 com execução paralela (3 threads), desacoplamento de payloads externos sob `src/test/resources/data/payloads/auth/`, validação estrita de schemas via Karate matchers (`#uuid`, `#regex`, `#string`, `#boolean`), geração de massa sintética dinâmica com Datafaker (`pt-BR`) via `DataGenerator`, e validação de deleção em cascata via testes de caixa-preta HTTP (sem acoplamento JDBC).

## Technical Context

**Language/Version**: Java 21 LTS (Maven compiler source/target set to 21)

**Primary Dependencies**: Karate DSL (`karate-junit5` 1.5.2), Net Datafaker (`datafaker` 2.4.2), JUnit 5 Test Platform (`maven-surefire-plugin` 3.2.5)

**Storage**: N/A (Repositório exclusivo de testes de aceitação/contrato de API; o banco de dados da aplicação sob teste é verificado estritamente via camada HTTP sem dependência de drivers JDBC)

**Testing**: Karate DSL (`karate-junit5` 1.5.2) executado através de `features.TestRunner`

**Target Platform**: JVM 21 em ambiente Linux / CI-CD Runners (Maven CLI)

**Project Type**: Suíte de Automação de Testes de API (DSL / Especificação Executável em Gherkin)

**Performance Goals**: Execução paralela em 3 threads; suíte completa do módulo Auth executada em menos de 30 segundos localmente; 0% de falhas intermitentes por colisão de dados

**Constraints**:
- Princípio I: Independência e paralelismo estrito (cada cenário deve ser autocontido com e-mails e dados sintéticos únicos)
- Princípio II: Desacoplamento de payloads estáticos em arquivos externos JSON
- Princípio III: Geração dinâmica de dados via `DataGenerator` (proibido dados fixos em `.feature`)
- Princípio IV: Zero exposição de segredos em código versionado e logs
- Princípio V: Tagging padronizado (`@auth`, `@smoke`, `@regression`, `@register`, `@login`, `@me`, `@delete`)
- Princípio VI: Matriz completa de cobertura de códigos de resposta (200, 201, 204, 401, 403, 409, 422)

**Scale/Scope**: 4 endpoints (`POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `GET /api/v1/auth/me`, `DELETE /api/v1/auth/me`), 20 cenários BDD categorizados em 4 User Stories, 3 schemas contratuais principais (`UserResponse`, `Token`, `HTTPValidationError`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio Constitucional | Requisito do Projeto | Status | Evidência / Mecanismo de Conformidade |
| :--- | :--- | :--- | :--- |
| **I. Test Independence & Parallel Safety** | Scenarios autocontidos, idempotentes, 3 threads paralelas | **PASS** | `DataGenerator.getRandomEmail()` e geração de senhas sintéticas únicas por cenário; zero estado compartilhado entre threads. |
| **II. Payload Decoupling & Schema Payloads** | Payloads desacoplados em `src/test/resources/data/payloads/` | **PASS** | Payloads base `register-request.json` e `login-request.json` externalizados; schemas em `schemas/auth/`. |
| **III. Dynamic Data & Synthetic Generation** | Uso de Datafaker (`pt-BR`) via `DataGenerator` | **PASS** | Todos os dados pessoais (nomes, e-mails) gerados via `DataGenerator.java`; senhas de borda geradas dinamicamente. |
| **IV. Zero-Secret Exposure & Parity** | Zero credenciais no git, configuração por ambiente | **PASS** | `environments.json` e `credentials-reader.js` com variáveis de ambiente; mascaramento de headers sensíveis no `logback-test.xml`. |
| **V. Living Specifications & Tagging** | Especificações executáveis com tags estruturadas | **PASS** | Features organizadas com tags `@auth`, `@register`, `@login`, `@me`, `@delete`, `@smoke`, `@regression`. |
| **VI. Mandatory QA Coverage Matrix** | Happy path, boundaries, 401, 403, 404, 409, 422 | **PASS** | Matriz com 20 cenários cobrindo 100% dos status codes definidos e esclarecidos na fase de especificação. |

**Avaliação dos Gates**: Todos os 6 princípios constitucionais aprovados. Nenhuma violação detectada.

## Project Structure

### Documentation (this feature)

```text
specs/001-auth-user-management/
├── spec.md              # Feature specification com BDD clarificado
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output: Decisões técnicas e padrões adotados
├── data-model.md        # Phase 1 output: Entidades, limites de schema e estados
├── quickstart.md        # Phase 1 output: Guia de execução e validação dos testes
├── contracts/           # Phase 1 output: Contratos e esquemas JSON OpenAPI
│   ├── auth-endpoints.md
│   ├── user-create-request.json
│   ├── user-response.json
│   ├── token-response.json
│   └── http-validation-error.json
└── checklists/
    └── requirements.md  # Checklist de qualidade de requisitos
```

### Source Code (repository root)

```text
src/test/
├── java/
│   ├── features/
│   │   ├── TestRunner.java                 # JUnit 5 Parallel Test Runner (3 threads)
│   │   └── auth/
│   │       ├── register.feature           # US1: Cadastro e validações de borda (POST /register)
│   │       ├── login.feature              # US2: Autenticação e emissão de JWT (POST /login)
│   │       ├── me-get.feature             # US3: Consulta de perfil do usuário (GET /me)
│   │       └── me-delete.feature          # US4: Hard delete e cascata (DELETE /me)
│   └── utils/
│       ├── CredentialUtils.java           # Utilitários de credenciais
│       └── DataGenerator.java             # Datafaker helpers dinâmicos
└── resources/
    ├── karate-config.js                   # Setup global de ambiente e injeção de helpers
    ├── logback-test.xml                   # Configuração de logs sem vazamento de segredos
    ├── config/
    │   └── environments.json              # Configurações de baseUrl por ambiente (dev, qa, e2e)
    ├── data/
    │   ├── payloads/
    │   │   └── auth/
    │   │       ├── register-request.json  # Payload base para cadastro
    │   │       └── login-request.json     # Payload base para login
    │   └── schemas/
    │       └── auth/
    │           ├── user-response-schema.json    # Schema de contrato UserResponse
    │           ├── token-schema.json            # Schema de contrato Token
    │           └── validation-error-schema.json # Schema de contrato HTTPValidationError
    └── utils/
        └── credentials-reader.js          # Leitor de variáveis de ambiente/properties
```

**Structure Decision**: Adoção da arquitetura padrão do Karate DSL JUnit 5 sob `src/test/`. As especificações de teste residem em `features/auth/`, payloads em `data/payloads/auth/` e schemas em `data/schemas/auth/`, garantindo separação limpa entre lógica de teste, dados e contratos.

## Complexity Tracking

> Nenhuma violação constitucional identificada. Nenhuma complexidade acidental justificada.
