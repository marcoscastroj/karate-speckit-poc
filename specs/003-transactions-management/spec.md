# Feature Specification: Gestão de Transações e Projeções Financeiras (Transactions API)

**Feature Branch**: `003-transactions-management`

**Created**: 2026-09-28

**Status**: Draft

**Input**: User description: "Gestão de Transações e Projeções Financeiras (Transactions) - Matriz completa de cenários de testes de API cobrindo contratos de dados, validação de tipos de transação, cálculo de status por data, filtros combinados de consulta, projeções mensais, integridade referencial com contas e isolamento entre utilizadores (multi-tenancy)."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registro de Transações Financeiras (`POST /api/v1/transactions/`) (Priority: P1) 🎯 MVP

Como um usuário autenticado na plataforma Finance Organizer,  
Quero registrar movimentações financeiras de receitas ou despesas vinculadas a uma das minhas contas,  
Para que o sistema atribua automaticamente o status correto baseado na data, consolide meu saldo e registre meu histórico financeiro.

**Why this priority**: A transação é a entidade transacional primária que movimenta o patrimônio das contas. Sem ela, saldos dinâmicos, relatórios e projeções orçamentárias não operam.

**Independent Test**: Provisionar um novo usuário e uma conta via `auth-helper.feature`, enviar `POST /api/v1/transactions/` com payload válido de receita ou despesa, validar resposta `201 Created` no contrato `TransactionResponse` e verificar atualização do `saldo_calculado` na conta.

**Acceptance Scenarios**:

#### SCEN-TX-01: Registro de receita com data atual ou passada (status EFETIVADA)
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-TX-01 - Registro bem-sucedido de receita efetivada
  Given um usuário autenticado com uma conta bancária ativa
  And uma transação de tipo "RECEITA" com valor "1250.50", data atual (ou passada) e descrição "Salário Mensal"
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status HTTP retornado deve ser 201
  And o corpo da resposta deve validar estritamente o schema TransactionResponse:
    | campo        | tipo   | validação                                                |
    | id           | string | formato UUID v4 válido                                   |
    | user_id      | string | idêntico ao ID do usuário autenticado no token          |
    | conta_id     | string | idêntico ao ID da conta informada                        |
    | valor        | string | "1250.50" (cumprindo regex decimal)                     |
    | tipo         | string | "RECEITA"                                                |
    | status       | string | "EFETIVADA" (atribuído por regra de data <= hoje)        |
    | data         | string | formato ISO date "YYYY-MM-DD"                            |
    | descricao    | string | "Salário Mensal"                                         |
    | recorrencia  | string | "UNICA" (valor padrão)                                   |
    | created_at   | string | formato ISO 8601 (date-time)                             |
```

#### SCEN-TX-02: Registro de despesa com data futura (status AGENDADA)
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Business Rule / Temporal Status
```gherkin
Scenario: SCEN-TX-02 - Registro de despesa futura com status agendada
  Given um usuário autenticado com uma conta bancária ativa
  And uma transação de tipo "DESPESA" com valor "300.00", data futura (D+5) e descrição "Fatura Cartão Futura"
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status retornado deve ser 201
  And o campo "tipo" deve ser "DESPESA"
  And o campo "status" na resposta deve ser obrigatoriamente "AGENDADA"
```

#### SCEN-TX-03: Suporte aos padrões de recorrência e omissão padrão
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Happy Path / Parameterized
```gherkin
Scenario Outline: SCEN-TX-03 - Registro com padrão de recorrência especificado (<recorrencia>)
  Given um usuário autenticado com conta ativa
  And payload de transação com tipo "RECEITA", valor "500.00" e recorrencia configurada como "<recorrencia>"
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status deve ser 201
  And o campo "recorrencia" na resposta deve corresponder a "<recorrencia>"

  Examples:
    | recorrencia |
    | UNICA       |
    | SEMANAL     |
    | MENSAL      |
    | ANUAL       |
```

#### SCEN-TX-04: Precisão monetária decimal máxima de 2 casas
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Boundary / Data Format
```gherkin
Scenario Outline: SCEN-TX-04 - Aceitação de valores monetários válidos (<descricao>)
  Given um usuário autenticado com conta ativa
  And payload de transação com valor "<valor_input>"
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status retornado deve ser 201
  And o valor persistido na resposta deve cumprir a máscara de formatação decimal

  Examples:
    | descricao           | valor_input |
    | inteiro simples     | 100         |
    | decimal com 1 casa  | 100.5       |
    | decimal com 2 casas | 100.55      |
```

#### SCEN-TX-05: Atualização automática e dinâmica do saldo da conta
- **Endpoint**: `POST /api/v1/transactions/` & `GET /api/v1/accounts/{account_id}`
- **Categoria**: Integration / Balance Impact
```gherkin
Scenario: SCEN-TX-05 - Atualização do saldo da conta após registro de receita e despesa
  Given uma conta recém-criada com saldo inicial "0.00"
  When o usuário registra uma transação de RECEITA no valor de "2000.00"
  Then o saldo_calculado da conta via GET deve atualizar para "2000.00"
  When o usuário registra uma transação de DESPESA no valor de "450.00"
  Then o saldo_calculado da conta via GET deve atualizar para "1550.00"
```

#### SCEN-TX-06: Rejeição de transação com valor zero, negativo ou excesso decimal
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Negative / Boundary Validation
```gherkin
Scenario Outline: SCEN-TX-06 - Rejeição de transação com valor monetário inválido (<motivo>)
  Given um usuário autenticado com conta ativa
  And payload de transação com valor "<valor_invalido>"
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status HTTP retornado deve ser 422
  And o schema da resposta deve validar HTTPValidationError

  Examples:
    | motivo               | valor_invalido |
    | valor zero           | 0              |
    | valor negativo       | -50.00         |
    | mais de 2 decimais   | 100.999        |
    | valor textual/letras | cem_reais      |
```

#### SCEN-TX-07: Rejeição de valores inválidos para tipo, recorrência e formato de data
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario Outline: SCEN-TX-07 - Rejeição de campos com valores fora do domínio (<campo>)
  Given um usuário autenticado com conta ativa
  And payload de transação configurado com <payload_mutado>
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status deve ser 422
  And a lista de erros deve conter violação de schema

  Examples:
    | campo              | payload_mutado                                                                                                              |
    | tipo inválido      | { "valor": 100, "tipo": "TRANSFERENCIA", "data": "2026-09-28", "descricao": "Teste", "conta_id": "#(contaId)" }           |
    | recorrência fora   | { "valor": 100, "tipo": "RECEITA", "data": "2026-09-28", "descricao": "Teste", "conta_id": "#(contaId)", "recorrencia": "DIARIA" } |
    | data inválida      | { "valor": 100, "tipo": "RECEITA", "data": "28/09/2026", "descricao": "Teste", "conta_id": "#(contaId)" }                 |
```

#### SCEN-TX-08: Limites de tamanho e obrigatoriedade da descrição
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Negative / Boundary Validation
```gherkin
Scenario Outline: SCEN-TX-08 - Validação de limites na descrição da transação (<cenario>)
  Given um usuário autenticado com conta ativa
  And payload de transação com descricao "<descricao_teste>"
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status HTTP retornado deve ser 422

  Examples:
    | cenario                   | descricao_teste                                                                                                              |
    | string vazia (0 chars)    |                                                                                                                              |
    | acima do limite (256 car) | DescricaoComMaisDeDuzentosECinquentaECincoCaracteres_LoremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididuntUtLaboreEtDoloreMagnaAliquaUtEnimAdMinimVeniamQuisNostrudExercitationUllamcoLaborisNisiUtAliquipExEaCommodoConsequatDuisAuteIrureDolorInReprehenderit256charsX |
```

#### SCEN-TX-09: Rejeição por ausência de campos obrigatórios
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario Outline: SCEN-TX-09 - Rejeição por omissão de campos obrigatórios (<campo_ausente>)
  Given um usuário autenticado com conta ativa
  And o payload da transação sem o campo "<campo_ausente>"
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status retornado deve ser 422

  Examples:
    | campo_ausente |
    | valor         |
    | tipo          |
    | data          |
    | descricao     |
    | conta_id      |
```

#### SCEN-TX-10: Proteção contra vinculação a conta inexistente ou conta de outro usuário (IDOR)
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Security / Referential Integrity & IDOR
```gherkin
Scenario: SCEN-TX-10 - Tentativa de registrar transação vinculada a conta de terceiro ou UUID inexistente
  Given o Usuário B possui a conta "Conta Segura B" com ID "CONTA-B-ID"
  And o Usuário A está autenticado com seu próprio token
  When o Usuário A tenta registrar uma transação associando "conta_id": "CONTA-B-ID"
  Then o código de status retornado deve ser 404 Not Found (ou 403 Forbidden)
  When o Usuário A tenta registrar uma transação com um UUID aleatório não existente no banco
  Then o código de status retornado deve ser 404 Not Found
```

#### SCEN-TX-11: Rejeição de registro de transação sem autenticação
- **Endpoint**: `POST /api/v1/transactions/`
- **Categoria**: Security / Authentication
```gherkin
Scenario Outline: SCEN-TX-11 - Tentativa de registro sem autenticação válida (<condicao_auth>)
  Given uma requisição sem credenciais válidas configurada com header Authorization = '<header_val>'
  And payload de transação válido
  When o cliente envia uma requisição POST para "/api/v1/transactions/"
  Then o código de status HTTP retornado deve ser 401

  Examples:
    | condicao_auth       | header_val              |
    | cabeçalho ausente   |                         |
    | token inválido      | Bearer token_falso_1234 |
    | esquema não bearer  | Basic dXNlcjpwYXNz      |
```

---

### User Story 2 - Listagem e Filtros Combinados de Transações (`GET /api/v1/transactions/`) (Priority: P1)

Como um usuário autenticado,  
Quero consultar a lista das minhas transações financeiras aplicando filtros por mês, ano, conta e status, além de paginação,  
Para que eu possa auditar minhas movimentações e inspecionar lançamentos específicos de determinado período.

**Why this priority**: A consulta parametrizada é o principal meio de navegação histórica do usuário na gestão financeira pessoal.

**Independent Test**: Criar um conjunto de transações com datas e contas distintas, submeter requisições `GET /api/v1/transactions/` com combinações de query params e comprovar precisão dos filtros e isolamento multi-tenant.

**Acceptance Scenarios**:

#### SCEN-TX-12: Listagem geral de transações do usuário logado (sem filtros)
- **Endpoint**: `GET /api/v1/transactions/`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-TX-12 - Listagem padrão de transações do usuário
  Given um usuário com 3 transações cadastradas em sua conta
  When o cliente envia uma requisição GET para "/api/v1/transactions/"
  Then o código de status retornado deve ser 200
  And o corpo da resposta deve ser um array JSON contendo exatamente 3 transações
  And cada item deve validar o schema TransactionResponse
  And todas as transações devem ter o campo "user_id" igual ao ID do usuário autenticado
```

#### SCEN-TX-13: Isolamento multi-tenant estrito na listagem
- **Endpoint**: `GET /api/v1/transactions/`
- **Categoria**: Security / Multi-tenancy
```gherkin
Scenario: SCEN-TX-13 - Segregação de transações entre usuários distintos
  Given o Usuário A possui 2 transações registradas
  And o Usuário B possui 1 transação registrada
  When o Usuário A envia uma requisição GET para "/api/v1/transactions/" com seu token
  Then o código de status retornado deve ser 200
  And a lista deve conter exatamente as 2 transações do Usuário A
  And nenhuma transação do Usuário B deve constar no resultado
```

#### SCEN-TX-14: Filtro por competência temporal (mês e ano)
- **Endpoint**: `GET /api/v1/transactions/`
- **Categoria**: Happy Path / Filtering
```gherkin
Scenario: SCEN-TX-14 - Filtro de transações por mês e ano
  Given um usuário com transações em Setembro/2026 e Outubro/2026
  When o cliente envia GET para "/api/v1/transactions/?mes=9&ano=2026"
  Then o status retornado deve ser 200
  And todas as transações retornadas devem possuir a data pertencente ao mês 09 e ano 2026
```

#### SCEN-TX-15: Filtro por conta específica (`conta_id`)
- **Endpoint**: `GET /api/v1/transactions/`
- **Categoria**: Happy Path / Filtering
```gherkin
Scenario: SCEN-TX-15 - Filtro de transações por conta
  Given um usuário com 2 transações na "Conta A" e 1 transação na "Conta B"
  When o cliente envia GET para "/api/v1/transactions/?conta_id={conta_a_id}"
  Then o código de status deve ser 200
  And todas as transações retornadas devem possuir "conta_id" igual a "conta_a_id"
```

#### SCEN-TX-16: Filtro por status (`EFETIVADA` vs `AGENDADA`)
- **Endpoint**: `GET /api/v1/transactions/`
- **Categoria**: Happy Path / Filtering
```gherkin
Scenario: SCEN-TX-16 - Filtro de transações por status
  Given um usuário com transações efetivadas (passadas) e agendadas (futuras)
  When o cliente envia GET para "/api/v1/transactions/?status=EFETIVADA"
  Then o código de status deve ser 200
  And todos os registros retornados devem ter "status": "EFETIVADA"
  When o cliente envia GET para "/api/v1/transactions/?status=AGENDADA"
  Then o código de status deve ser 200
  And todos os registros retornados devem ter "status": "AGENDADA"
```

#### SCEN-TX-17: Combinação múltipla de filtros e paginação
- **Endpoint**: `GET /api/v1/transactions/`
- **Categoria**: Integration / Query Parameters
```gherkin
Scenario: SCEN-TX-17 - Combinação de filtros (mês, ano, conta, status) e paginação (skip, limit)
  Given uma massa de transações distribuída por datas e contas
  When o cliente envia GET para "/api/v1/transactions/?mes=9&ano=2026&conta_id={id}&status=EFETIVADA&skip=0&limit=10"
  Then o código de status deve ser 200
  And a lista deve cumprir simultaneamente todos os critérios de filtro especificados
```

#### SCEN-TX-18: Validação de erro em query params inválidos
- **Endpoint**: `GET /api/v1/transactions/`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario Outline: SCEN-TX-18 - Rejeição de query parameters fora do schema permitido (<parametro>)
  Given um usuário autenticado com token válido
  When o cliente envia requisição GET para "/api/v1/transactions/?<query_invalida>"
  Then o código de status HTTP deve ser 422
  And a resposta deve validar HTTPValidationError

  Examples:
    | parametro        | query_invalida         |
    | mês menor que 1  | mes=0&ano=2026         |
    | mês maior que 12 | mes=13&ano=2026        |
    | ano menor que min| mes=9&ano=1899         |
    | ano maior que max| mes=9&ano=2101         |
    | status inválido  | status=PENDENTE        |
    | conta_id não-UUID| conta_id=nao-uuid-1234 |
    | limit negativo   | limit=-1               |
    | limit acima 100  | limit=101              |
```

#### SCEN-TX-19: Rejeição de listagem sem token
- **Endpoint**: `GET /api/v1/transactions/`
- **Categoria**: Security / Authentication
```gherkin
Scenario: SCEN-TX-19 - Tentativa de listagem sem autenticação
  Given nenhuma credencial de autenticação fornecida
  When o cliente envia uma requisição GET para "/api/v1/transactions/"
  Then o status retornado deve ser 401
```

---

### User Story 3 - Projeções e Totalizadores Mensais (`GET /api/v1/transactions/projections`) (Priority: P2)

Como um usuário autenticado na plataforma Finance Organizer,  
Quero consultar as projeções financeiras consolidando o total de receitas e despesas previstas e o saldo projetado de um mês e ano específicos,  
Para que eu tenha clareza do fluxo de caixa previsto e planeje minhas finanças com antecedência.

**Why this priority**: A funcionalidade de projeção orçamentária é o recurso analítico central para tomada de decisão financeira e conciliação do orçamento mensal.

**Independent Test**: Registrar receitas e despesas com datas no mesmo mês (tanto efetivadas quanto agendadas), submeter `GET /api/v1/transactions/projections?mes={M}&ano={A}` e verificar a exatidão matemática de `receitas_previstas`, `despesas_previstas` e `saldo_projetado`.

**Acceptance Scenarios**:

#### SCEN-TX-20: Consulta bem-sucedida de projeções com cálculo contábil exato
- **Endpoint**: `GET /api/v1/transactions/projections`
- **Categoria**: Happy Path / Business Calculation
```gherkin
Scenario: SCEN-TX-20 - Cálculo dinâmico de projeções do mês (receitas, despesas e saldo projetado)
  Given um usuário com uma conta ativa
  And 1 receita efetivada de "3000.00" em 10/09/2026
  And 1 receita agendada de "1000.00" em 25/09/2026
  And 1 despesa efetivada de "800.50" em 05/09/2026
  And 1 despesa agendada de "450.25" em 28/09/2026
  When o cliente envia uma requisição GET para "/api/v1/transactions/projections?mes=9&ano=2026"
  Then o código de status HTTP retornado deve ser 200
  And o corpo da resposta deve validar o schema TransactionProjectionsResponse:
    | campo               | valor esperado |
    | mes                 | 9              |
    | ano                 | 2026           |
    | conta_id            | null           |
    | receitas_previstas  | "4000.00"      |
    | despesas_previstas  | "1250.75"      |
    | saldo_projetado     | "2749.25"      |
```

#### SCEN-TX-21: Projeção filtrada por conta específica (`conta_id`)
- **Endpoint**: `GET /api/v1/transactions/projections`
- **Categoria**: Happy Path / Filtering
```gherkin
Scenario: SCEN-TX-21 - Projeção orçamentária restrita a uma conta específica
  Given um usuário com transações na "Conta A" e transações na "Conta B" no mês 09/2026
  When o cliente envia GET para "/api/v1/transactions/projections?mes=9&ano=2026&conta_id={conta_a_id}"
  Then o código de status deve ser 200
  And o campo "conta_id" deve corresponder a "conta_a_id"
  And os campos "receitas_previstas" e "despesas_previstas" devem somar exclusivamente os valores da Conta A
```

#### SCEN-TX-22: Mês sem transações cadastradas (retorno zerado formatado)
- **Endpoint**: `GET /api/v1/transactions/projections`
- **Categoria**: Happy Path / Empty State
```gherkin
Scenario: SCEN-TX-22 - Consulta de projeções em mês sem movimentações
  Given um usuário sem nenhuma transação cadastrada no mês 01/2027
  When o cliente envia GET para "/api/v1/transactions/projections?mes=1&ano=2027"
  Then o código de status deve ser 200
  And "receitas_previstas" deve ser "0.00"
  And "despesas_previstas" deve ser "0.00"
  And "saldo_projetado" deve ser "0.00"
```

#### SCEN-TX-23: Rejeição de consulta de projeções por omissão de parâmetros obrigatórios ou valores inválidos
- **Endpoint**: `GET /api/v1/transactions/projections`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario Outline: SCEN-TX-23 - Rejeição por parâmetros obrigatórios ausentes ou inválidos (<motivo>)
  Given um usuário autenticado com token válido
  When o cliente envia GET para "/api/v1/transactions/projections?<query_params>"
  Then o código de status HTTP retornado deve ser 422
  And o schema deve validar HTTPValidationError

  Examples:
    | motivo               | query_params    |
    | ausência de mês      | ano=2026        |
    | ausência de ano      | mes=9           |
    | mês fora do limite   | mes=13&ano=2026 |
    | ano fora do limite   | mes=9&ano=1800  |
    | conta_id não-UUID    | mes=9&ano=2026&conta_id=nao-uuid |
```

#### SCEN-TX-24: Rejeição de consulta de projeções sem autenticação
- **Endpoint**: `GET /api/v1/transactions/projections`
- **Categoria**: Security / Authentication
```gherkin
Scenario: SCEN-TX-24 - Consulta de projeções sem cabeçalho Authorization
  Given nenhuma credencial fornecida
  When o cliente envia GET para "/api/v1/transactions/projections?mes=9&ano=2026"
  Then o código de status deve ser 401
```

---

### User Story 4 - Consulta de Detalhes de Transação por ID (`GET /api/v1/transactions/{transaction_id}`) (Priority: P2)

Como um usuário autenticado,  
Quero consultar os dados detalhados de uma transação pelo seu identificador `transaction_id`,  
Para inspecionar metadados, valores e conferir a conta associada à movimentação.

**Why this priority**: Permite inspeção granular e individual de registros após operações ou conciliação bancária.

**Independent Test**: Criar uma transação, disparar `GET /api/v1/transactions/{transaction_id}`, validar código `200 OK` e conformidade com o schema `TransactionResponse`.

**Acceptance Scenarios**:

#### SCEN-TX-25: Consulta com sucesso de transação própria existente
- **Endpoint**: `GET /api/v1/transactions/{transaction_id}`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-TX-25 - Consulta de transação por ID existente
  Given um usuário autenticado com uma transação "Aluguel" criada previamente
  When o cliente envia GET para "/api/v1/transactions/{transaction_id}" com token válido
  Then o código de status deve ser 200
  And o corpo deve validar TransactionResponse
  And os campos "id", "descricao", "valor" e "conta_id" devem corresponder à transação criada
```

#### SCEN-TX-26: Proteção IDOR em tentativa de consulta a transação de outro usuário
- **Endpoint**: `GET /api/v1/transactions/{transaction_id}`
- **Categoria**: Security / Authorization (IDOR)
```gherkin
Scenario: SCEN-TX-26 - Bloqueio de acesso a transação de terceiro (IDOR)
  Given o Usuário B possui a transação "Salário Confidencial B" com ID "TX-B-ID"
  And o Usuário A está autenticado com seu próprio token
  When o Usuário A envia GET para "/api/v1/transactions/TX-B-ID"
  Then o código de status retornado deve ser 404 Not Found (ou 403 Forbidden)
  And nenhum dado da transação do Usuário B deve ser exposto ao Usuário A
```

#### SCEN-TX-27: Consulta com UUID inexistente ou não formatado
- **Endpoint**: `GET /api/v1/transactions/{transaction_id}`
- **Categoria**: Negative / Not Found & Validation
```gherkin
Scenario Outline: SCEN-TX-27 - Consulta de transação com ID inválido ou inexistente (<motivo>)
  Given um usuário autenticado com token válido
  When o cliente envia GET para "/api/v1/transactions/<id_informado>"
  Then o código de status deve ser <status_esperado>

  Examples:
    | motivo               | id_informado                   | status_esperado |
    | UUID não cadastrado  | 00000000-0000-0000-0000-000000000000 | 404             |
    | formato não-UUID     | id-invalido-1234               | 422             |
```

#### SCEN-TX-28: Rejeição de consulta por ID sem autenticação
- **Endpoint**: `GET /api/v1/transactions/{transaction_id}`
- **Categoria**: Security / Authentication
```gherkin
Scenario: SCEN-TX-28 - Consulta por ID sem token de sessão
  Given uma transação existente no sistema
  When uma requisição GET é enviada para "/api/v1/transactions/{transaction_id}" sem cabeçalho Authorization
  Then o código de status retornado deve ser 401
```

---

### User Story 5 - Exclusão de Transação e Reversão de Saldo (`DELETE /api/v1/transactions/{transaction_id}`) (Priority: P2)

Como um usuário da plataforma Finance Organizer,  
Quero excluir uma transação financeira registrada incorretamente ou cancelada,  
Para que a movimentação seja removida e o impacto financeiro no saldo da conta associada seja devidamente revertido.

**Why this priority**: Garante o ciclo de vida completo da transação e a correção de lançamentos indevidos com estorno contábil automático.

**Independent Test**: Registrar uma transação em uma conta, consultar o saldo alterado, disparar `DELETE /api/v1/transactions/{transaction_id}`, validar código `204 No Content` sem corpo, validar `404` em GET subsequente e comprovar que o saldo da conta foi revertido.

**Acceptance Scenarios**:

#### SCEN-TX-29: Exclusão bem-sucedida de transação própria e inacessibilidade subsequente
- **Endpoint**: `DELETE /api/v1/transactions/{transaction_id}`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-TX-29 - Exclusão bem-sucedida de transação
  Given um usuário autenticado com uma transação registrada
  When o cliente envia uma requisição DELETE para "/api/v1/transactions/{transaction_id}" com token válido
  Then o código de status retornado deve ser 204 No Content
  And o corpo da resposta deve ser vazio
  And uma requisição GET subsequente para "/api/v1/transactions/{transaction_id}" deve retornar 404 Not Found
```

#### SCEN-TX-30: Reversão contábil imediata do saldo da conta após exclusão
- **Endpoint**: `DELETE /api/v1/transactions/{transaction_id}` & `GET /api/v1/accounts/{account_id}`
- **Categoria**: Integration / Balance Reversion
```gherkin
Scenario Outline: SCEN-TX-30 - Reversão do impacto no saldo após exclusão de <tipo>
  Given uma conta com saldo base de "1000.00"
  And uma transação de <tipo> no valor de "<valor>" vinculada a essa conta
  When o usuário exclui a transação via DELETE "/api/v1/transactions/{transaction_id}"
  Then o código de status deve ser 204
  And o saldo_calculado da conta consultado via GET deve retornar exatamente para o saldo base de "1000.00"

  Examples:
    | tipo    | valor  |
    | RECEITA | 500.00 |
    | DESPESA | 250.00 |
```

#### SCEN-TX-31: Proteção IDOR em tentativa de exclusão de transação de outro usuário
- **Endpoint**: `DELETE /api/v1/transactions/{transaction_id}`
- **Categoria**: Security / Authorization (IDOR)
```gherkin
Scenario: SCEN-TX-31 - Bloqueio de exclusão de transação de terceiro (IDOR)
  Given o Usuário B possui a transação "Despesa Pessoal B" com ID "TX-B-ID"
  And o Usuário A está autenticado com seu próprio token
  When o Usuário A envia DELETE para "/api/v1/transactions/TX-B-ID"
  Then o código de status retornado deve ser 404 Not Found (ou 403 Forbidden)
  And a transação do Usuário B deve continuar existindo no banco de dados (GET por B retorna 200)
```

#### SCEN-TX-32: Tentativa de exclusão de transação inexistente ou não-UUID
- **Endpoint**: `DELETE /api/v1/transactions/{transaction_id}`
- **Categoria**: Negative / Not Found & Validation
```gherkin
Scenario Outline: SCEN-TX-32 - Exclusão com identificador inválido ou inexistente (<motivo>)
  Given um usuário autenticado com token válido
  When o cliente envia DELETE para "/api/v1/transactions/<id_informado>"
  Then o código de status deve ser <status_esperado>

  Examples:
    | motivo               | id_informado                          | status_esperado |
    | UUID não cadastrado  | 00000000-0000-0000-0000-000000000000 | 404             |
    | formato não-UUID     | id-invalido-xyz                       | 422             |
```

#### SCEN-TX-33: Rejeição de exclusão de transação sem autenticação
- **Endpoint**: `DELETE /api/v1/transactions/{transaction_id}`
- **Categoria**: Security / Authentication
```gherkin
Scenario: SCEN-TX-33 - Tentativa de exclusão sem cabeçalho Authorization
  Given uma transação existente no sistema
  When uma requisição DELETE é enviada para "/api/v1/transactions/{transaction_id}" sem token
  Then o código de status retornado deve ser 401
```

---

## Edge Cases

- **Virada de Dia e Status Temporal**: Uma transação agendada para hoje (`data = hoje`) que passa para o dia seguinte (`data < hoje`) deve transicionar seu status para `EFETIVADA` dinamicamente ou na consulta.
- **Datas em Fim de Mês / Anos Bissextos**: Envio de datas como `2024-02-29` (ano bissexto válido) vs `2026-02-29` (inválido). O backend deve validar a coerência do calendário com `422`.
- **Saldo Resultante Negativo**: Registrar despesas superiores ao saldo total da conta. O sistema financeiro aceita saldos negativos na conta (ex: cheque especial/débito) mantendo a integridade matemática precisa com prefixo `-`.
- **Valores Monetários com Formatações Variadas**: Envio de `valor` como número (`1500.5`) vs string (`"1500.50"`). A API suporta ambos via schema `anyOf`, mas o retorno padroniza como string decimal regex `^(?!^[-+.]*$)[+-]?0*\d*\.?\d{0,2}0*$`.
- **Filtros com Resultados Vazios**: Aplicação de filtros combinados de mês/ano/conta que não possuem registros no banco devem retornar lista vazia `[]` com status `200 OK` (nunca `404` ou `500`).

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST permitir o registro de novas transações financeiras via `POST /api/v1/transactions/` para usuários autenticados, retornando `201 Created` e contrato `TransactionResponse`.
- **FR-002**: Toda transação criada com `data <= hoje` MUST ter seu campo `status` atribuído automaticamente como `"EFETIVADA"`.
- **FR-003**: Toda transação criada com `data > hoje` MUST ter seu campo `status` atribuído automaticamente como `"AGENDADA"`.
- **FR-004**: O campo `valor` em `TransactionCreate` MUST ser positivo e estritamente maior que zero (`exclusiveMinimum: 0.0`), suportando no máximo 2 casas decimais. Valores nulos, iguais a zero, negativos ou com excesso decimal MUST retornar `422 Unprocessable Entity`.
- **FR-005**: O campo `tipo` MUST aceitar exclusivamente os valores `"RECEITA"` ou `"DESPESA"`, rejeitando outros valores com `422 Unprocessable Entity`.
- **FR-006**: O campo `recorrencia` MUST suportar `"UNICA"`, `"SEMANAL"`, `"MENSAL"` e `"ANUAL"`, assumindo `"UNICA"` como valor por omissão (default) se não especificado.
- **FR-007**: O campo `descricao` MUST ter tamanho mínimo de 1 caractere e máximo de 255 caracteres, rejeitando descrições vazias ou excedentes com `422 Unprocessable Entity`.
- **FR-008**: O registro de uma transação MUST exigir uma `conta_id` válida vinculada ao usuário autenticado. Tentativa de associar a transação à conta de outro usuário (IDOR) ou conta inexistente MUST ser bloqueada com `404 Not Found` (ou `403 Forbidden`).
- **FR-009**: O registro de transações MUST atualizar de imediato e dinamicamente o `saldo_calculado` da conta bancária associada (`+` para receitas, `-` para despesas).
- **FR-010**: O sistema MUST listar transações em `GET /api/v1/transactions/` pertencentes exclusivamente ao usuário autenticado (isolamento multi-tenant).
- **FR-011**: A listagem de transações MUST suportar filtros opcionais combináveis por `mes` (1 a 12), `ano` (1900 a 2100), `conta_id` (UUID), `status` (`EFETIVADA`/`AGENDADA`), além de paginação com `skip` (default 0) e `limit` (default 100, max 100).
- **FR-012**: O sistema MUST fornecer o endpoint `GET /api/v1/transactions/projections` exigindo obrigatoriamente os query params `mes` (1..12) e `ano` (1900..2100), com suporte ao filtro opcional `conta_id`.
- **FR-013**: As projeções mensais MUST calcular com exatidão matemática:
  - `receitas_previstas` = soma algébrica de todas as receitas do mês de referência (efetivadas + agendadas).
  - `despesas_previstas` = soma algébrica de todas as despesas do mês de referência (efetivadas + agendadas).
  - `saldo_projetado` = `receitas_previstas - despesas_previstas`.
- **FR-014**: O sistema MUST fornecer a consulta de uma transação individual via `GET /api/v1/transactions/{transaction_id}` para o titular, retornando `200 OK` e contrato `TransactionResponse`.
- **FR-015**: O sistema MUST permitir a exclusão de uma transação via `DELETE /api/v1/transactions/{transaction_id}` pelo usuário titular, retornando `204 No Content` sem corpo.
- **FR-016**: A exclusão de uma transação MUST reverter de imediato o impacto financeiro no `saldo_calculado` da conta associada.
- **FR-017**: Tentativas de acesso, consulta ou exclusão de transações pertencentes a outros usuários (IDOR) MUST ser bloqueadas com `404 Not Found` (ou `403 Forbidden`).
- **FR-018**: Todas as operações de transações (`POST`, `GET`, `DELETE`, `/projections`) MUST exigir autenticação Bearer JWT válida, respondendo com `401 Unauthorized` caso ausente, inválida ou expirada.
- **FR-019**: Parâmetros de identificadores UUID (`transaction_id`, `conta_id`) com formatos não compatíveis com UUID v4 MUST responder com `422 Unprocessable Entity`.

---

### Key Entities

- **Transaction (Transação)**: Representa uma movimentação financeira de entrada ou saída. Possui atributos `id` (UUID), `user_id` (UUID), `conta_id` (UUID), `valor` (string/decimal positivo), `tipo` (`RECEITA` \| `DESPESA`), `data` (date YYYY-MM-DD), `descricao` (1..255 chars), `recorrencia` (`UNICA` \| `SEMANAL` \| `MENSAL` \| `ANUAL`), `status` (`EFETIVADA` \| `AGENDADA`) e `created_at` (ISO 8601 date-time).
- **Account (Conta/Carteira)**: Entidade contábil agregadora vinculada à transação via `conta_id`. Seu `saldo_calculado` reflete a soma consolidada de todas as transações associadas.
- **TransactionProjections (Projeção Financeira)**: Objeto analítico consolidado para um dado `mes` e `ano`, contendo `receitas_previstas`, `despesas_previstas` e `saldo_projetado`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos cenários de teste automatizados da matriz de Transações e Projeções (33 cenários BDD) implementados e aprovados com 0 falhas em Karate DSL.
- **SC-002**: 100% de isolamento multi-tenant garantido em listagem, detalhe, projeções e exclusão, sem qualquer vazamento de dados entre usuários distintos.
- **SC-003**: 100% de acurácia matemática nas fórmulas contábeis de `saldo_calculado` na conta e `saldo_projetado` nas projeções mensais.
- **SC-004**: Validação precisa da transição temporal de status: 100% das transações com data <= hoje registradas como `EFETIVADA` e transações com data > hoje como `AGENDADA`.
- **SC-005**: Execução paralela da suíte de Transações em 3 threads no `TestRunner` do JUnit 5 sem colisões de massa de dados ou flakiness.
- **SC-006**: Conformidade estrita de 100% com os schemas OpenAPI `TransactionResponse`, `TransactionCreate`, `TransactionProjectionsResponse` e `HTTPValidationError`.
- **SC-007**: Cobertura integral da matriz de status codes HTTP: `200`, `201`, `204`, `401`, `404` e `422`.

---

## Assumptions

- O endpoint base da API sob teste é `http://100.75.210.114:8000`, conforme estabelecido na Constituição do projeto.
- A autenticação é provida via tokens Bearer JWT emitidos por `POST /api/v1/auth/login`.
- Os testes automatizados utilizarão o helper `auth-helper.feature` via `karate.call` para provisionar dinamicamente novos usuários e carteiras isoladas por cenário, cumprindo o Princípio VII da Constituição.
- A data atual de referência para os testes é calculada dinamicamente via Java/JavaScript (`java.time.LocalDate.now()`) para garantir determinação exata dos limites temporais (D-1, D0, D+1) independente do dia de execução.
- Testes de IDOR provisionam dois usuários distintos (Titular e Intruso) em runtime com suas respectivas contas para assegurar proteção estrita de limites de acesso (BOLA).
