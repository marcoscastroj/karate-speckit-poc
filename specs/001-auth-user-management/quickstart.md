# Quickstart & Verification Guide: Auth API Test Automation

**Feature**: `001-auth-user-management`
**Date**: 2026-09-23
**Status**: Ready for Implementation

Este guia orienta a execução, validação e auditoria dos testes automatizados em Karate DSL para o módulo de **Autenticação e Gestão de Usuário (`Auth`)**.

---

## 1. Pré-Requisitos

- **Java Development Kit**: Java 21 LTS instalado (`java -version`).
- **Apache Maven**: Versão 3.9+ instalada (`mvn -version`).
- **API Target em Execução**: Backend da API Finance Organizer ativo no host/porta configurado em `src/test/resources/config/environments.json` (alvo canônico: `http://100.75.210.114:8000` conforme Constituição v1.1.0).

---

## 2. Configuração de Ambiente

As URLs-base e parâmetros de timeout são controlados centralmente via `environments.json` e ativados via argumento `-Dkarate.env`:

```bash
# Execução apontando para ambiente local/dev
mvn test -Dkarate.env="dev"

# Execução apontando para ambiente de QA
mvn test -Dkarate.env="qa"
```

Caso sejam necessárias variáveis customizadas de autenticação ou chaves de serviço, configure via variáveis de ambiente no SO antes de disparar a suíte.

---

## 3. Comandos de Execução da Suíte de Testes

### 3.1 Execução de Toda a Suíte do Módulo Auth
Dispara todos os cenários cobrindo cadastro, login, perfil e deleção com paralelismo nativo (3 threads):

```bash
mvn test -Dkarate.tags="@auth"
```

### 3.2 Execução de Testes Críticos (Smoke Tests)
Valida rapidamente o caminho feliz dos endpoints (`register`, `login`, `me` e `delete`):

```bash
mvn test -Dkarate.tags="@smoke"
```

### 3.3 Execução por Endpoint Específico
Para depuração focada durante o ciclo de desenvolvimento:

```bash
# Testes do endpoint de cadastro (POST /api/v1/auth/register)
mvn test -Dkarate.tags="@register"

# Testes de autenticação e JWT (POST /api/v1/auth/login)
mvn test -Dkarate.tags="@login"

# Testes de consulta de perfil (GET /api/v1/auth/me)
mvn test -Dkarate.tags="@me"

# Testes de exclusão de conta e cascata (DELETE /api/v1/auth/me)
mvn test -Dkarate.tags="@delete"
```

---

## 4. Cenários de Validação End-to-End

| Cenário de Validação | Comando / Tag | Resultado Esperado |
| :--- | :--- | :--- |
| **Criação de Conta Válida** | `@register and @smoke` | Retorno `201 Created` e validação do schema [`user-response.json`](contracts/user-response.json). |
| **Tentativa de Duplicidade** | `@register and @conflict` | Retorno `409 Conflict` preservando a integridade da conta original. |
| **Validação de Limites de Senha** | `@register and @boundaries` | Rejeição `422 Unprocessable Entity` para senhas com 7 e 73 caracteres. |
| **Login com Sucesso** | `@login and @smoke` | Retorno `200 OK` e validação do schema [`token-response.json`](contracts/token-response.json). |
| **Login com Senha Errada** | `@login and @security` | Rejeição com `401 Unauthorized` sem geração de token. |
| **Conta Desativada** | `@login and @inactive` | Rejeição com `403 Forbidden`. |
| **Consulta de Perfil Protegido** | `@me and @smoke` | Retorno `200 OK` com dados idênticos ao token e zero dados sensíveis. |
| **Exclusão e Cascata** | `@delete and @cascade` | Retorno `204 No Content` sem erro `500`, revogação do token (`401`) e inacessibilidade dos recursos filhos (`404`). |

---

## 5. Relatórios de Execução

Após a execução via Maven, o Karate gera um relatório visual detalhado contendo a linha do tempo, requisições HTTP, payloads enviados e asserções validadas:

- **Relatório Principal**: `target/karate-reports/karate-summary.html`
- **Detalhes por Feature**:
  - `target/karate-reports/features.auth.register.html`
  - `target/karate-reports/features.auth.login.html`
  - `target/karate-reports/features.auth.me-get.html`
  - `target/karate-reports/features.auth.me-delete.html`

Abra o arquivo HTML no seu navegador de preferência para inspecionar os resultados e evidências de teste.
