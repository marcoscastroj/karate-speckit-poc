# Phase 0 Research: Gestão de Contas e Carteiras (Accounts API)

**Branch**: `002-accounts-management` | **Feature**: [specs/002-accounts-management/spec.md](spec.md)

---

## 1. Estratégia de Isolamento Multi-tenant e Testes de IDOR (Broken Object Level Authorization)

### Decisão
Em todos os cenários que testam proteção contra IDOR (`GET`, `PUT`, `DELETE` em `/api/v1/accounts/{account_id}`), o teste em Karate DSL provisionará dinamicamente **dois usuários distintos em runtime**:
- **Usuário A (Titular Legítimo)**: criado via `auth-helper.feature`, recebe token JWT A e cria a conta alvo.
- **Usuário B (Intruso/Atacante)**: criado via `auth-helper.feature`, recebe token JWT B e tenta acessar/modificar/excluir a conta do Usuário A.

### Justificativa
- Garante total independência de testes (Princípio I da Constituição) e zero acoplamento de estado entre threads paralelas.
- Elimina flakiness decorrente de contas estáticas pré-existentes que poderiam ser alteradas simultaneamente por outras execuções.
- Valida o controle de acesso no nível de objeto (BOLA / OWASP API Security Top 10).

### Alternativas Consideradas
- **Contas estáticas pré-cadastradas no banco**: Rejeitado. Viola o Princípio I e causa colisão fatal em execuções paralelas concorrentes.
- **Mock de permissões no Karate**: Rejeitado. Os testes devem atuar como especificação executável de caixa-preta contra a API real.

---

## 2. Validação da Fórmula Contábil de Saldo Dinâmico (`saldo_calculado`)

### Decisão
A validação do campo `saldo_calculado` será realizada através de um fluxo transacional completo via API:
1. Provisionar um usuário novo via `auth-helper.feature`.
2. Criar uma nova conta com saldo inicial garantido em `"0.00"`.
3. Injetar transações sintéticas via `POST /api/v1/transactions/`:
   - 2 transações de `RECEITA` (ex: 1500.50 e 500.00).
   - 1 transação de `DESPESA` (ex: 350.25).
4. Consultar `GET /api/v1/accounts/{account_id}` e validar:
   - Que `saldo_calculado` é uma string decimal igual a `"1650.25"`.
   - Que atende à máscara regex contratual: `^(?!^[-+.]*$)[+-]?0*\d*\.?\d*$`.

### Justificativa
- Assegura que o cálculo contábil realizado pelo backend (provavelmente via agregação SQL `SUM(CASE WHEN tipo = 'RECEITA' THEN valor ELSE -valor END)`) é dinâmico e consistente sem depender de acesso direto ao banco (JDBC).
- Cumpre os Princípios II e VI da Constituição.

### Alternativas Consideradas
- **Inserção direta de linhas no banco via SQL**: Rejeitado. Viola o desacoplamento de banco de dados e a portabilidade do repositório de testes.

---

## 3. Estratégia de Teste de Integridade Referencial na Exclusão (`DELETE`)

### Decisão
Para o endpoint `DELETE /api/v1/accounts/{account_id}`, serão implementados dois fluxos distintos de deleção:
1. **Conta Vazia**: Exclusão de conta recém-criada sem nenhuma movimentação vinculada. Deve retornar estritamente `204 No Content` sem corpo, e um `GET` subsequente deve responder `404 Not Found`.
2. **Conta com Transações Filhas**: Criação de conta vinculada a transações via `POST /api/v1/transactions/`. O teste aceita um de dois comportamentos válidos arquiteturais:
   - *Cascade Delete*: Retorna `204 No Content`, expurgando as transações órfãs.
   - *Integrity Protection*: Retorna `400 Bad Request` ou `409 Conflict`, recusando a exclusão para preservar o histórico contábil.
   - **Asserção de Segurança**: Em hipótese alguma o servidor pode responder com `500 Internal Server Error` (que indicaria exceção de chave estrangeira não tratada).

### Justificativa
- Garante resiliência e estabilidade contra crashes não tratados no banco de dados relacional sob teste.

---

## 4. Modularização de Features e Reuso com Karate DRY

### Decisão
Os cenários serão agrupados no diretório `src/test/java/features/accounts/` organizados por operação:
- `accounts-create.feature` (POST /api/v1/accounts/)
- `accounts-list.feature` (GET /api/v1/accounts/)
- `accounts-get.feature` (GET /api/v1/accounts/{account_id})
- `accounts-update.feature` (PUT /api/v1/accounts/{account_id})
- `accounts-delete.feature` (DELETE /api/v1/accounts/{account_id})

Cada arquivo consumirá o helper compartilhado [`auth-helper.feature`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/src/test/java/features/helpers/auth-helper.feature) via `karate.call` no `Background` ou no início do cenário, cumprindo o Princípio VII da Constituição.

### Justificativa
- Mantém features com escopo coeso (< 150 linhas), facilitando a leitura de relatórios e a execução de testes específicos por tag ou arquivo.
- Evita arquivos monolíticos que degradam a legibilidade no editor.

---

## 5. Payloads e Schemas Centralizados

### Decisão
Centralizar todos os modelos JSON sob:
- `src/test/resources/data/payloads/accounts/`:
  - `account-create-request.json`
  - `account-update-request.json`
- `src/test/resources/data/schemas/accounts/`:
  - `account-response-schema.json`
  - `account-list-schema.json`

Os schemas utilizarão os fuzzy matchers do Karate:
```json
{
  "id": "#uuid",
  "user_id": "#uuid",
  "apelido": "#string",
  "saldo_calculado": "#regex ^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d*$",
  "created_at": "#regex ^\\d{4}-\\d{2}-\\d{2}T.*"
}
```
