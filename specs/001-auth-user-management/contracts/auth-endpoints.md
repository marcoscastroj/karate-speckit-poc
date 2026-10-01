# Interface Contracts: Auth API Endpoints

Este documento define os contratos de interface HTTP expostos pelo módulo de Autenticação e Gestão de Usuários da API Finance Organizer, extraídos diretamente de `docs/openapi.json`.

---

## 1. `POST /api/v1/auth/register`
**Sumário**: Cadastrar um novo usuário anônimo.
**Autenticação**: Nenhuma (endpoint público).

### Request
- **Headers**: `Content-Type: application/json`
- **Schema**: [`user-create-request.json`](user-create-request.json)
```json
{
  "email": "user@example.com",
  "password": "Password123"
}
```

### Responses
- **201 Created**: Usuário registrado com sucesso.
  - **Schema**: [`user-response.json`](user-response.json)
- **409 Conflict**: Conflito de e-mail duplicado na base de dados.
- **422 Unprocessable Entity**: Violação de schema, limites de tamanho de senha ou campos extras não permitidos.
  - **Schema**: [`http-validation-error.json`](http-validation-error.json)

---

## 2. `POST /api/v1/auth/login`
**Sumário**: Autenticar credenciais e gerar token JWT.
**Autenticação**: Nenhuma (endpoint público).

### Request
- **Headers**: `Content-Type: application/json`
- **Schema**: [`user-create-request.json`](user-create-request.json)
```json
{
  "email": "user@example.com",
  "password": "Password123"
}
```

### Responses
- **200 OK**: Autenticação bem-sucedida.
  - **Schema**: [`token-response.json`](token-response.json)
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```
- **401 Unauthorized**: Senha incorreta ou e-mail inexistente.
- **403 Forbidden**: Conta com status inativo (`is_active: false`).
- **422 Unprocessable Entity**: Campos obrigatórios ausentes ou payload malformado.
  - **Schema**: [`http-validation-error.json`](http-validation-error.json)

---

## 3. `GET /api/v1/auth/me`
**Sumário**: Obter dados cadastrais do usuário autenticado.
**Autenticação**: OAuth2 Bearer Token obrigatório.

### Request
- **Headers**:
  - `Authorization: Bearer <access_token>`
  - `Accept: application/json`

### Responses
- **200 OK**: Consulta bem-sucedida do perfil.
  - **Schema**: [`user-response.json`](user-response.json)
- **401 Unauthorized**: Ausência de cabeçalho `Authorization`, token expirado, corrompido ou malformado.

---

## 4. `DELETE /api/v1/auth/me`
**Sumário**: Hard delete imediato da conta e limpeza em cascata no banco de dados.
**Autenticação**: OAuth2 Bearer Token obrigatório.

### Request
- **Headers**:
  - `Authorization: Bearer <access_token>`

### Responses
- **204 No Content**: Exclusão física da conta executada com sucesso. Corpo de resposta vazio.
- **401 Unauthorized**: Ausência de token ou token inválido.
