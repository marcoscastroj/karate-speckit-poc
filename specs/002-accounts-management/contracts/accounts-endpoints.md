# OpenAPI Endpoints Contract: Accounts API

Este documento especifica formalmente as assinaturas de rota, parâmetros, headers de autorização e modelos de resposta para o módulo de Gestão de Contas e Carteiras, derivados de `docs/openapi.json`.

---

## 1. POST /api/v1/accounts/

- **Sumário**: Criar uma nova conta/carteira
- **Segurança**: `OAuth2PasswordBearer` (Requer `Authorization: Bearer <token>`)
- **Content-Type**: `application/json`

### Request Body:
```json
{
  "apelido": "Nubank"
}
```

### Respostas Mapeadas:
- **`201 Created`**: Conta criada com sucesso.
  - Schema: `AccountResponse`
  - Headers: `Content-Type: application/json`
- **`422 Unprocessable Entity`**: Erro de validação de schema (`minLength: 1`, `maxLength: 100`, campo ausente ou tipo inválido).
  - Schema: `HTTPValidationError`
- **`401 Unauthorized`**: Token ausente, inválido ou expirado.

---

## 2. GET /api/v1/accounts/

- **Sumário**: Listar todas as contas do usuário logado
- **Segurança**: `OAuth2PasswordBearer` (Requer `Authorization: Bearer <token>`)

### Query Parameters:
| Parâmetro | Tipo | Obrigatório | Padrão | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| `skip` | `integer` | Não | `0` | Quantidade de registros a pular para paginação |
| `limit` | `integer` | Não | `100` | Quantidade máxima de registros a retornar |

### Respostas Mapeadas:
- **`200 OK`**: Lista de contas do usuário logado.
  - Schema: `array[AccountResponse]`
- **`422 Unprocessable Entity`**: Tipo de parâmetro de query inválido (ex: string não numérica).
- **`401 Unauthorized`**: Token ausente ou inválido.

---

## 3. GET /api/v1/accounts/{account_id}

- **Sumário**: Obter detalhes de uma conta por ID
- **Segurança**: `OAuth2PasswordBearer` (Requer `Authorization: Bearer <token>`)

### Path Parameters:
| Parâmetro | Tipo | Formato | Obrigatório | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| `account_id` | `string` | `uuid` | Sim | Identificador único da conta |

### Respostas Mapeadas:
- **`200 OK`**: Detalhes da conta recuperados com sucesso.
  - Schema: `AccountResponse`
- **`404 Not Found`**: Conta inexistente ou pertencente a outro usuário (defesa contra IDOR).
- **`422 Unprocessable Entity`**: Parâmetro `account_id` não é um UUID válido.
- **`401 Unauthorized`**: Token ausente ou inválido.

---

## 4. PUT /api/v1/accounts/{account_id}

- **Sumário**: Atualizar apelido de uma conta
- **Segurança**: `OAuth2PasswordBearer` (Requer `Authorization: Bearer <token>`)
- **Content-Type**: `application/json`

### Path Parameters:
- `account_id`: `uuid` (obrigatório)

### Request Body:
```json
{
  "apelido": "Banco Inter"
}
```

### Respostas Mapeadas:
- **`200 OK`**: Conta atualizada com sucesso.
  - Schema: `AccountResponse`
- **`404 Not Found`**: Conta não encontrada ou pertencente a outro usuário (IDOR).
- **`422 Unprocessable Entity`**: Apelido inválido (vazio ou > 100 caracteres) ou `account_id` não-UUID.
- **`401 Unauthorized`**: Token ausente ou inválido.

---

## 5. DELETE /api/v1/accounts/{account_id}

- **Sumário**: Deletar uma conta
- **Segurança**: `OAuth2PasswordBearer` (Requer `Authorization: Bearer <token>`)

### Path Parameters:
- `account_id`: `uuid` (obrigatório)

### Respostas Mapeadas:
- **`204 No Content`**: Conta excluída com sucesso (sem corpo de resposta).
- **`400 Bad Request` / `409 Conflict`**: Rejeição de integridade caso haja transações vinculadas e deleção em cascata não seja permitida.
- **`404 Not Found`**: Conta não encontrada ou pertencente a outro usuário (IDOR).
- **`422 Unprocessable Entity`**: `account_id` inválido (não-UUID).
- **`401 Unauthorized`**: Token ausente ou inválido.
