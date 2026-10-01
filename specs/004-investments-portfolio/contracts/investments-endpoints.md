# API Contracts: Gestão de Portfólio de Investimentos (Investments API)

**Feature**: `004-investments-portfolio`  
**Host Baseline**: `http://100.75.210.114:8000`  
**Base Path**: `/api/v1/investments`  
**Security**: Bearer JWT (`Authorization: Bearer <token>`) obrigatório em todas as rotas.

---

## 1. POST `/api/v1/investments/`
- **Operação**: `create_investment_api_v1_investments__post`
- **Descrição**: Cadastra uma nova posição de custódia de investimento para o usuário autenticado.
- **Headers**: `Content-Type: application/json`, `Authorization: Bearer <token>`
- **Request Body**: `InvestmentCreate` (JSON)
  ```json
  {
    "ticker": "PETR4",
    "nome": "Petrobras PN",
    "classe": "ACOES",
    "quantidade": "100.0",
    "preco_medio": "30.00",
    "cotacao_atual": "36.00"
  }
  ```
- **Respostas**:
  - `201 Created`: Retorna `InvestmentResponse` com campos calculados preenchidos.
  - `401 Unauthorized`: Token ausente ou inválido.
  - `422 Unprocessable Entity`: Validação de contrato falhou (`HTTPValidationError`).

---

## 2. GET `/api/v1/investments/`
- **Operação**: `list_investments_api_v1_investments__get`
- **Descrição**: Lista as posições de investimento do usuário autenticado.
- **Headers**: `Authorization: Bearer <token>`
- **Query Parameters**:
  - `classe` (opcional, enum `InvestmentClass`): Filtra por classe de ativo.
  - `skip` (opcional, integer >= 0, default 0): Deslocamento de paginação.
  - `limit` (opcional, integer 1..100, default 100): Quantidade máxima por página.
- **Respostas**:
  - `200 OK`: Array de `InvestmentResponse`.
  - `401 Unauthorized`: Não autenticado.
  - `422 Unprocessable Entity`: Parâmetro de query inválido.

---

## 3. GET `/api/v1/investments/summary`
- **Operação**: `get_portfolio_summary_api_v1_investments_summary_get`
- **Descrição**: Obtém métricas consolidadas do portfólio de investimentos do usuário autenticado.
- **Headers**: `Authorization: Bearer <token>`
- **Respostas**:
  - `200 OK`: `PortfolioSummaryResponse`
  - `401 Unauthorized`: Não autenticado.

---

## 4. GET `/api/v1/investments/{investment_id}`
- **Operação**: `get_investment_api_v1_investments__investment_id__get`
- **Descrição**: Obtém detalhes de uma posição de investimento específica por ID.
- **Headers**: `Authorization: Bearer <token>`
- **Path Parameters**:
  - `investment_id` (UUID v4 obrigatório): Identificador do investimento.
- **Respostas**:
  - `200 OK`: `InvestmentResponse`
  - `401 Unauthorized`: Não autenticado.
  - `404 Not Found`: Ativo inexistente ou pertencente a outro usuário (IDOR).
  - `422 Unprocessable Entity`: ID malformado (não-UUID).

---

## 5. PUT `/api/v1/investments/{investment_id}`
- **Operação**: `update_investment_api_v1_investments__investment_id__put`
- **Descrição**: Atualiza dados de um investimento e recalcula métricas derivadas.
- **Headers**: `Content-Type: application/json`, `Authorization: Bearer <token>`
- **Path Parameters**:
  - `investment_id` (UUID v4 obrigatório).
- **Request Body**: `InvestmentUpdate` (JSON parcial)
  ```json
  {
    "cotacao_atual": "38.50"
  }
  ```
- **Respostas**:
  - `200 OK`: `InvestmentResponse` com campos recalculados.
  - `401 Unauthorized`: Não autenticado.
  - `404 Not Found`: Ativo inexistente ou de outro usuário (IDOR).
  - `422 Unprocessable Entity`: Dados ou limites inválidos.

---

## 6. DELETE `/api/v1/investments/{investment_id}`
- **Operação**: `delete_investment_api_v1_investments__investment_id__delete`
- **Descrição**: Exclui uma posição de investimento e expurga seu saldo do portfólio.
- **Headers**: `Authorization: Bearer <token>`
- **Path Parameters**:
  - `investment_id` (UUID v4 obrigatório).
- **Respostas**:
  - `204 No Content`: Excluído com sucesso (sem corpo).
  - `401 Unauthorized`: Não autenticado.
  - `404 Not Found`: Inexistente ou pertencente a outro usuário.
  - `422 Unprocessable Entity`: ID malformado.
