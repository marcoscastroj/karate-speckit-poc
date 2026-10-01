# Research: Gestão de Transações e Projeções Financeiras (Transactions API)

**Feature**: `specs/003-transactions-management/spec.md`  
**Status**: Concluído  
**Date**: 2026-09-28

---

## 1. 📅 Resolução Dinâmica de Datas e Status Temporal (`EFETIVADA` vs `AGENDADA`)

### Contexto
O endpoint `POST /api/v1/transactions/` e a listagem `GET /api/v1/transactions/` possuem a regra de negócio temporal:
- Se `data <= hoje`: `status` é atribuído como `"EFETIVADA"`.
- Se `data > hoje`: `status` é atribuído como `"AGENDADA"`.
Como testes de API automatizados executam em dias e horários variáveis, fixar strings estáticas como `"2026-09-28"` geraria flakiness ou quebra quando a data do teste ultrapassasse a data fixada.

### Decisão
Utilizar a interoperabilidade Java do Karate DSL com `java.time.LocalDate` e `java.time.format.DateTimeFormatter` para calcular dinamicamente as datas de teste:
- Data Atual ($D_0$): `java.time.LocalDate.now().toString()`
- Data Passada ($D_{-1}$): `java.time.LocalDate.now().minusDays(1).toString()`
- Data Futura ($D_{+5}$): `java.time.LocalDate.now().plusDays(5).toString()`
- Mês Atual: `java.time.LocalDate.now().getMonthValue()`
- Ano Atual: `java.time.LocalDate.now().getYear()`

### Rationale
Garante 100% de determinismo e resiliência temporal em qualquer data ou fuso horário em que o pipeline de CI/CD for acionado.

### Alternativas Consideradas
- *Hardcoded Dates*: Datas fixas (ex: "2026-10-01") quebrariam a asserção de status assim que a data do sistema avançasse.
- *Função JavaScript `Date.now()`*: Menos legível e requer manipulações manuais de padding de zero para o formato `YYYY-MM-DD`. `java.time.LocalDate` é nativo, thread-safe e padronizado em ISO-8601.

---

## 2. 🧮 Acurácia Monetária e Validação de Projeções Mensais

### Contexto
O endpoint `GET /api/v1/transactions/projections` calcula:
- `receitas_previstas`: Soma de todas as receitas do mês (`tipo = "RECEITA"`), sejam efetivadas ou agendadas.
- `despesas_previstas`: Soma de todas as despesas do mês (`tipo = "DESPESA"`), sejam efetivadas ou agendadas.
- `saldo_projetado`: `receitas_previstas - despesas_previstas`.
Os valores monetários retornam como string decimal compatível com o regex `^(?!^[-+.]*$)[+-]?0*\d*\.?\d*$`.

### Decisão
No teste automatizado:
1. Injetar valores com centavos exatos (ex: `3000.00` + `1000.00` em receitas = `4000.00`, e `800.50` + `450.25` em despesas = `1250.75`).
2. Validar o resultado contábil com asserção estrita de string (`"2749.25"`) e asserção numérica convertida via `Number(response.saldo_projetado) == 2749.25`.
3. Validar a conformidade com o schema OpenAPI usando Karate fuzzy matchers para os formatos de regex monetários.

### Rationale
Evita erros de ponto flutuante típicos de linguagens dinâmicas e assegura que a API preserva a exatidão financeira esperada por sistemas contábeis.

---

## 3. 🛡️ Isolamento Multi-tenant e Defesa contra IDOR na Vinculação de Contas

### Contexto
Ao registrar uma transação (`POST /api/v1/transactions/`), o usuário deve fornecer `conta_id`. A API precisa garantir:
1. O usuário titular da transação é o dono da conta informada em `conta_id`.
2. Se o Usuário A tentar vincular sua transação ao `conta_id` do Usuário B, a API deve rejeitar com `404 Not Found` (ou `403 Forbidden`).
3. Na listagem e na consulta por ID (`/transactions/{id}`), transações do Usuário B não podem ser vistas nem alteradas pelo Usuário A.

### Decisão
Cada cenário de teste de IDOR utilizará `auth-helper.feature` para provisionar dois usuários distintos em runtime:
- **Usuário Titular (B)**: Cadastra conta bancária legítima e transação confidencial.
- **Usuário Intruso (A)**: Tenta associar transação à conta de B ou consultar/excluir a transação de B com seu próprio token.
Asserções verificam status `404` (ou `403`) e a integridade intacta dos dados do Usuário B.

### Rationale
Cumpre a recomendação OWASP API Security Top 10 (API1:2023 - Broken Object Level Authorization) e o Princípio I (Independência e Isolamento Estrito) da Constituição do projeto.

---

## 4. 🔄 Reversibilidade do Saldo da Conta na Exclusão da Transação

### Contexto
Uma transação afeta diretamente o `saldo_calculado` da conta bancária (`+` receita, `-` despesa). Quando a transação é excluída via `DELETE /api/v1/transactions/{transaction_id}`, esse impacto deve ser revertido.

### Decisão
O cenário de exclusão deve verificar:
1. Leitura do saldo base da conta antes da transação (ex: `1000.00`).
2. Criação da transação (ex: despesa de `250.00` -> saldo vai para `750.00`).
3. Disparo do `DELETE /api/v1/transactions/{transaction_id}` -> status `204 No Content`.
4. Consulta imediata subsequente `GET /api/v1/accounts/{account_id}` para assegurar que `saldo_calculado` retornou exatamente para `1000.00`.

### Rationale
Comprova a consistência transacional do banco de dados (ACID) por meio de testes caixa-preta via REST API sem necessidade de conexões JDBC diretas.
