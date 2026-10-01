# Technical Research & Architecture Decisions: Auth API Test Automation

**Feature**: `001-auth-user-management`
**Date**: 2026-09-23
**Status**: Completed

## Overview

Este documento consolida as decisões arquiteturais, padrões técnicos e diretrizes de implementação adotadas para a automação de testes em Karate DSL do módulo de **Autenticação e Gestão de Usuário (`Auth`)**. Todas as decisões derivam diretamente dos requisitos clarificados e da [Constituição do Repositório](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/.specify/memory/constitution.md).

---

## Technical Decisions

### Decision 1: Organização dos Arquivos de Teste (`.feature`) e Estratégia de Tags

- **Decisão**: Decompor o módulo `Auth` em quatro arquivos `.feature` especializados sob `src/test/java/features/auth/`:
  1. `register.feature` (US1 - Cadastro de Usuário e Validações de Borda)
  2. `login.feature` (US2 - Autenticação, Emissão de JWT e Bloqueios)
  3. `me-get.feature` (US3 - Perfil do Usuário e Segurança de Headers)
  4. `me-delete.feature` (US4 - Hard Delete e Validação de Limpeza em Cascata)
- **Rationale**:
  - Promove alta coesão e isolamento de escopo por endpoint.
  - Permite execução paralela pelo `TestRunner` sem colisões de contexto entre cenários do mesmo arquivo.
  - Facilita execução seletiva via tags no Maven (ex: `mvn test -Dkarate.tags="@register"`, `mvn test -Dkarate.tags="@smoke"`).
- **Alternativas Consideradas**:
  - *Arquivo único `auth.feature`*: Descartado por gerar um arquivo monolítico de difícil manutenção (mais de 20 cenários) e com concorrência desnecessária.
  - *Um arquivo por cenário*: Granularidade excessiva que geraria repetição desnecessária de Background e setup de ambiente.

---

### Decision 2: Desacoplamento e Manipulação Dinâmica de Payloads

- **Decisão**: Armazenar templates base de requisição em arquivos JSON sob `src/test/resources/data/payloads/auth/`:
  - `register-request.json`: `{ "email": "", "password": "" }`
  - `login-request.json`: `{ "email": "", "password": "" }`
  No Karate, os testes carregam o template com `read()` e alteram atributos dinâmicos através da instrução `* set payload.campo = valor`.
- **Rationale**:
  - Cumpre estritamente o **Princípio II (Payload Decoupling & Schema-Driven Payloads)** da Constituição.
  - Evita poluição de JSON inline nas features, mantendo o foco do BDD na intenção de negócio.
- **Alternativas Consideradas**:
  - *JSON inline dentro dos passos Gherkin*: Descartado por violar o Princípio II e dificultar a manutenção de schemas volumosos.
  - *Classes Java DTO de request*: Descartado por introduzir complexidade desnecessária em um framework baseado em DSL declarativa.

---

### Decision 3: Validação de Contrato de Resposta via Karate Fuzzy Matchers

- **Decisão**: Externalizar schemas contratuais em `src/test/resources/data/schemas/auth/` e validar as respostas da API utilizando os matchers fuzzy nativos do Karate:
  - `user-response-schema.json`:
    ```json
    {
      "id": "#uuid",
      "email": "#regex ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
      "is_active": "#boolean",
      "created_at": "#regex ^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}"
    }
    ```
  - `token-schema.json`:
    ```json
    {
      "access_token": "#regex ^[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+\\.?[A-Za-z0-9-_.+/=]*$",
      "token_type": "bearer"
    }
    ```
  - `validation-error-schema.json`:
    ```json
    {
      "detail": "#[] { loc: '#[]', msg: '#string', type: '#string' }"
    }
    ```
- **Rationale**:
  - Garante conformidade estrita com o OpenAPI 3.1 sem fragilidade a dados gerados dinamicamente (UUIDs, timestamps, tokens).
  - Em caso de quebra contratual (chave ausente ou tipo inválido), o Karate falha o teste com relatório de diff detalhado.
- **Alternativas Consideradas**:
  - *Asserções exatas de campos*: Inviável para IDs e carimbos de tempo dinâmicos.
  - *Validador JSON Schema externo (schema-validator)*: Desnecessário, pois o motor nativo de matchers do Karate cobre todas as tipagens com performance superior.

---

### Decision 4: Validação de Exclusão em Cascata em Modo Caixa-Preta (Sem JDBC)

- **Decisão**: A validação de limpeza em cascata no cenário `SCEN-DEL-02` será executada de forma autônoma via encadeamento de chamadas HTTP (caixa-preta):
  1. Criação do usuário e autenticação (geração do `access_token`).
  2. Criação de recursos correlacionados (`POST /api/v1/accounts/`, `POST /api/v1/transactions/`, `POST /api/v1/investments/`) utilizando o token emitido.
  3. Exclusão da conta via `DELETE /api/v1/auth/me` -> valida status `204 No Content` e ausência de erro de integridade referencial `500`.
  4. Verificação de inacessibilidade pós-exclusão:
     - `POST /api/v1/auth/login` com as credenciais deletadas -> valida `401 Unauthorized`.
     - `GET /api/v1/auth/me` com o token anterior -> valida `401 Unauthorized`.
     - Tentativa de consulta aos identificadores criados -> valida recusa de acesso (`401` ou `404`).
- **Rationale**:
  - Decisão confirmada durante a sessão de esclarecimento (`/speckit-clarify` - Pergunta 5).
  - Mantém o repositório leve, independente de drivers JDBC e sem dependência de credenciais de acesso direto ao banco de dados em ambientes restritos (CI/CD).
- **Alternativas Consideradas**:
  - *Adição de JDBC Driver e asserções SQL diretas*: Rejeitada por acoplar a suíte de testes à infraestrutura de banco de dados e demandar configuração de rede/portas de banco.

---

### Decision 5: Extensão de Dados Sintéticos e Limites de Fronteira no `DataGenerator`

- **Decisão**: Enriquecer `src/test/java/utils/DataGenerator.java` com métodos auxiliares especializados para suporte aos cenários de borda:
  - `generatePassword(int length)`: Gera senha válida com caracteres alfanuméricos no comprimento exato especificado (8 caracteres para mínimo, 72 para máximo, 7 para teste negativo, 73 para limite superior).
  - `getRandomValidPassword()`: Gera senha padrão segura atendendo às políticas de complexidade.
- **Rationale**:
  - Atende ao **Princípio III (Dynamic Data & Synthetic Generation)** da Constituição.
  - Elimina senhas estáticas hardcoded nos arquivos `.feature`, prevenindo colisões ou advertências de segurança estática (Sonar / SAST).
- **Alternativas Consideradas**:
  - *Hardcoding de senhas nos arquivos de teste*: Rejeitado por violar a Constituição do projeto.
