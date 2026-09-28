# Contract Specification: Transactions API Endpoints

**Base Path**: `/api/v1/transactions`  
**Security**: Bearer JWT (`OAuth2PasswordBearer`)

---

## 1. POST `/api/v1/transactions/`
Registra uma nova transação financeira vinculada a uma carteira/conta.

- **Headers**:
  - `Authorization: Bearer <access_token>` (obrigatório)
  - `Content-Type: application/json`
- **Request Body (`TransactionCreate`)**:
  ```json
  {
    "valor": 1500.50,
    "tipo": "RECEITA",
    "data": "2026-09-28",
    "descricao": "Salário Mensal",
    "conta_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "recorrencia": "UNICA"
  }
  ```
- **Responses**:
  - `201 Created`: Retorna `TransactionResponse`.
  - `401 Unauthorized`: Token ausente ou inválido.
  - `404 Not Found`: `conta_id` não existe ou pertence a outro usuário (IDOR).
  - `422 Unprocessable Entity`: Violação de schema ou tipos de dados inválidos.

---

## 2. GET `/api/v1/transactions/`
Lista transações do usuário autenticado com filtros opcionais combinados e paginação.

- **Query Parameters**:
  - `mes` (integer, 1..12, opcional): Filtra pelo mês da transação.
  - `ano` (integer, 1900..2100, opcional): Filtra pelo ano da transação.
  - `conta_id` (UUID, opcional): Filtra por conta específica.
  - `status` (`EFETIVADA` | `AGENDADA`, opcional): Filtra por status.
  - `skip` (integer, default 0, min 0, opcional): Paginação (offset).
  - `limit` (integer, default 100, min 1, max 100, opcional): Tamanho da página.
- **Responses**:
  - `200 OK`: Array de `TransactionResponse` (`[]` se nenhum registro).
  - `401 Unauthorized`: Sem autenticação.
  - `422 Unprocessable Entity`: Parâmetro fora do tipo ou limite permitido.

---

## 3. GET `/api/v1/transactions/projections`
Obtém totalizadores e projeções financeiras consolidadas para um dado mês e ano.

- **Query Parameters**:
  - `mes` (integer, 1..12, **obrigatório**): Mês de competência.
  - `ano` (integer, 1900..2100, **obrigatório**): Ano de competência.
  - `conta_id` (UUID, opcional): Filtra os cálculos para uma conta específica.
- **Responses**:
  - `200 OK`: Retorna `TransactionProjectionsResponse`.
  - `401 Unauthorized`: Sem autenticação.
  - `422 Unprocessable Entity`: Mês ou ano ausentes ou fora dos limites permitidos.

---

## 4. GET `/api/v1/transactions/{transaction_id}`
Obtém detalhes de uma transação específica por ID.

- **Path Parameters**:
  - `transaction_id` (UUID, **obrigatório**): ID da transação.
- **Responses**:
  - `200 OK`: Retorna `TransactionResponse`.
  - `401 Unauthorized`: Sem autenticação.
  - `404 Not Found`: Transação não encontrada ou pertencente a outro usuário (IDOR).
  - `422 Unprocessable Entity`: `transaction_id` fora do formato UUID.

---

## 5. DELETE `/api/v1/transactions/{transaction_id}`
Exclui uma transação e reverte o impacto financeiro no saldo da conta vinculada.

- **Path Parameters**:
  - `transaction_id` (UUID, **obrigatório**): ID da transação.
- **Responses**:
  - `204 No Content`: Exclusão bem-sucedida sem corpo de resposta.
  - `401 Unauthorized`: Sem autenticação.
  - `404 Not Found`: Transação inexistente ou pertencente a terceiro (IDOR).
  - `422 Unprocessable Entity`: Formato não-UUID.
