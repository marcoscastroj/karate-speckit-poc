# Feature Specification: Gestão de Contas e Carteiras (Accounts API)

**Feature Branch**: `002-accounts-management`

**Created**: 2026-09-28

**Status**: Draft

**Input**: User description: "Gestão de Contas / Carteiras (Accounts) - Matriz exaustiva de cenários de testes de API cobrindo contratos OpenAPI, regras de negócio, limites de payload, cálculo de saldo dinâmico, paginação, integridade multi-tenant (isolamento de usuários) e proteção de integridade referencial."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Criação de Contas / Carteiras (`POST /api/v1/accounts/`) (Priority: P1) 🎯 MVP

Como um usuário autenticado na plataforma Finance Organizer,  
Quero cadastrar novas contas ou carteiras financeiras (ex: "Nubank", "Carteira Física"),  
Para que eu possa organizar meus recursos financeiros e registrar movimentações em carteiras distintas.

**Why this priority**: A conta/carteira é a entidade agregadora essencial para todas as operações financeiras. Sem ela, nenhuma transação ou projeção pode existir.

**Independent Test**: Pode ser testado de forma totalmente autônoma provisionando um novo usuário via `auth-helper.feature` e submetendo uma requisição `POST /api/v1/accounts/` com payload `{ "apelido": "Nubank" }`, validando status HTTP `201 Created` e conformidade estrita com `AccountResponse`.

**Acceptance Scenarios**:

#### SCEN-ACC-01: Criação bem-sucedida de conta com apelido válido
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-ACC-01 - Criação bem-sucedida de conta com apelido válido
  Given um usuário autenticado e ativo no sistema com token Bearer válido
  And um payload de criação de conta é construído com apelido "Nubank"
    """json
    {
      "apelido": "Nubank"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/accounts/" com o cabeçalho Authorization
  Then o código de status HTTP retornado deve ser 201
  And o corpo da resposta deve validar estritamente o schema AccountResponse:
    | campo           | tipo      | validação                                             |
    | id              | string    | formato UUID v4 válido                                |
    | user_id         | string    | formato UUID v4 idêntico ao id do usuário autenticado |
    | apelido         | string    | exatamente igual a "Nubank"                           |
    | saldo_calculado | string    | valor inicial exato "0.00"                            |
    | created_at      | string    | formato ISO 8601 (date-time)                          |
```

#### SCEN-ACC-02: Criação de conta no limite mínimo permitido de caracteres (1 caractere)
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Boundary Validation / Happy Path
```gherkin
Scenario: SCEN-ACC-02 - Criação de conta no limite mínimo de 1 caractere
  Given um usuário autenticado com token válido
  And um payload de conta é estruturado com apelido de exatamente 1 caractere ("A")
  When o cliente envia uma requisição POST para "/api/v1/accounts/"
  Then o código de status HTTP deve ser 201
  And o campo "apelido" na resposta deve ser igual a "A"
  And o campo "saldo_calculado" deve ser "0.00"
```

#### SCEN-ACC-03: Criação de conta no limite máximo permitido de caracteres (100 caracteres)
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Boundary Validation / Happy Path
```gherkin
Scenario: SCEN-ACC-03 - Criação de conta no limite máximo de 100 caracteres
  Given um usuário autenticado com token válido
  And um payload de conta é estruturado com apelido de exatamente 100 caracteres
  When o cliente envia uma requisição POST para "/api/v1/accounts/"
  Then o código de status HTTP deve ser 201
  And o comprimento do campo "apelido" na resposta deve ser exatamente 100 caracteres
```

#### SCEN-ACC-04: Rejeição de criação com apelido em branco / string vazia (0 caracteres)
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Negative / Schema & Boundary Validation
```gherkin
Scenario: SCEN-ACC-04 - Rejeição de conta com apelido vazio (violação de minLength: 1)
  Given um usuário autenticado com token válido
  And um payload é enviado com apelido vazio: { "apelido": "" }
  When o cliente envia uma requisição POST para "/api/v1/accounts/"
  Then o código de status HTTP retornado deve ser 422
  And o corpo da resposta deve validar o schema HTTPValidationError
  And a lista de erros deve conter violação do tipo "string_too_short" para o campo "apelido"
```

#### SCEN-ACC-05: Rejeição de criação com apelido excedendo o limite máximo (101 caracteres)
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Negative / Boundary Validation
```gherkin
Scenario: SCEN-ACC-05 - Rejeição de conta com apelido excedendo 100 caracteres
  Given um usuário autenticado com token válido
  And um payload é estruturado com apelido de 101 caracteres alfanuméricos
  When o cliente envia uma requisição POST para "/api/v1/accounts/"
  Then o código de status HTTP retornado deve ser 422
  And a resposta deve conter erro de validação indicando max_length violado para "apelido"
```

#### SCEN-ACC-06: Rejeição de criação por ausência do campo obrigatório apelido
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario Outline: SCEN-ACC-06 - Rejeição por ausência ou nulidade do campo apelido (<cenario>)
  Given um usuário autenticado com token válido
  And o corpo da requisição é configurado como <payload>
  When o cliente envia uma requisição POST para "/api/v1/accounts/"
  Then o código de status HTTP deve ser 422
  And o corpo da resposta deve validar o schema HTTPValidationError

  Examples:
    | cenario         | payload           |
    | campo ausente   | {}                |
    | valor nulo      | { "apelido": null } |
```

#### SCEN-ACC-07: Rejeição de apelido com tipos de dados incompatíveis (número, array, boolean)
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Negative / Type Safety
```gherkin
Scenario Outline: SCEN-ACC-07 - Rejeição de payload com tipo de dados inválido (<tipo_invalido>)
  Given um usuário autenticado com token válido
  And o corpo da requisição possui apelido com <payload>
  When o cliente envia uma requisição POST para "/api/v1/accounts/"
  Then o código de status HTTP retornado deve ser 422
  And a mensagem de erro deve indicar que o campo esperado é string

  Examples:
    | tipo_invalido | payload                    |
    | inteiro       | { "apelido": 12345 }       |
    | boolean       | { "apelido": true }        |
    | array         | { "apelido": ["Carteira"] }|
    | objeto        | { "apelido": { "nome": "Nubank" } } |
```

#### SCEN-ACC-08: Tentativa de Mass Assignment / injeção de campos protegidos ou somente leitura
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Security / Data Integrity
```gherkin
Scenario: SCEN-ACC-08 - Bloqueio de injeção de campos somente leitura (id, user_id, saldo_calculado)
  Given um usuário titular autenticado com id "USR-TITULAR"
  And um payload forçando injeção de saldo inicial e identificadores arbitrários:
    """json
    {
      "apelido": "Carteira Injetada",
      "saldo_calculado": "999999.00",
      "user_id": "00000000-0000-0000-0000-000000000000",
      "id": "11111111-1111-1111-1111-111111111111"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/accounts/"
  Then o código de status retornado deve ser 201 ou 422
  And SE retornar 201, o sistema DEVE sanitizar os campos:
    | campo           | comportamento obrigatório                      |
    | id              | deve ser gerado pelo backend e NÃO ser o injetado |
    | user_id         | deve ser associado ao token e NÃO ao injetado  |
    | saldo_calculado | deve ser inicializado estritamente como "0.00" |
```

#### SCEN-ACC-09: Rejeição de criação de conta sem autenticação
- **Endpoint**: `POST /api/v1/accounts/`
- **Categoria**: Security / Authentication
```gherkin
Scenario Outline: SCEN-ACC-09 - Tentativa de criação sem autenticação (<condicao_auth>)
  Given uma requisição sem credenciais válidas configurada com header Authorization = '<header_val>'
  And payload de criação com apelido válido
  When o cliente envia uma requisição POST para "/api/v1/accounts/"
  Then o código de status HTTP retornado deve ser 401
  And nenhuma conta deve ser criada no sistema

  Examples:
    | condicao_auth       | header_val              |
    | cabeçalho ausente   |                         |
    | token inválido      | Bearer token_falso_1234 |
    | esquema não bearer  | Basic dXNlcjpwYXNz      |
```

---

### User Story 2 - Listagem e Paginação de Contas (`GET /api/v1/accounts/`) (Priority: P1)

Como um usuário autenticado na plataforma,  
Quero consultar a lista das minhas contas com suporte a paginação (`skip` e `limit`),  
Para visualizar todas as minhas carteiras cadastradas com seus respectivos saldos de forma rápida e segura.

**Why this priority**: A visualização das contas cadastradas é parte integrante do fluxo central do usuário para consulta e tomada de decisão financeira.

**Independent Test**: Provisionar um novo usuário, criar 3 contas e submeter `GET /api/v1/accounts/`, verificando a devolução das 3 contas pertencentes exclusivamente a este usuário.

**Acceptance Scenarios**:

#### SCEN-ACC-10: Listagem padrão com sucesso de contas cadastradas
- **Endpoint**: `GET /api/v1/accounts/`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-ACC-10 - Listagem padrão de contas do usuário logado
  Given um usuário com 2 contas cadastradas previamente ("Conta Corrente" e "Poupança")
  When o cliente envia uma requisição GET para "/api/v1/accounts/" com token válido
  Then o código de status retornado deve ser 200
  And o corpo da resposta deve ser um array JSON contendo exatamente 2 elementos
  And cada elemento do array deve validar o schema AccountResponse
  And todos os registros retornados devem ter o campo "user_id" igual ao ID do usuário autenticado
```

#### SCEN-ACC-11: Listagem para usuário recém-criado sem contas associadas
- **Endpoint**: `GET /api/v1/accounts/`
- **Categoria**: Happy Path / Empty State
```gherkin
Scenario: SCEN-ACC-11 - Listagem de contas para usuário sem registros
  Given um novo usuário recém-cadastrado sem nenhuma conta criada
  When o cliente envia uma requisição GET para "/api/v1/accounts/"
  Then o código de status retornado deve ser 200
  And a resposta deve ser uma lista vazia "[]"
```

#### SCEN-ACC-12: Garantia de Isolamento Multi-tenant (Segregação de Usuários)
- **Endpoint**: `GET /api/v1/accounts/`
- **Categoria**: Security / Multi-tenancy
```gherkin
Scenario: SCEN-ACC-12 - Isolamento de dados entre usuários distintos
  Given o Usuário A possui 2 contas cadastradas ("Conta A1", "Conta A2")
  And o Usuário B possui 1 conta cadastrada ("Conta B1")
  When o Usuário A envia uma requisição GET para "/api/v1/accounts/" com seu próprio token
  Then o código de status deve ser 200
  And a lista retornada deve conter exatamente 2 contas
  And NENHUMA conta pertencente ao Usuário B deve constar no resultado do Usuário A
```

#### SCEN-ACC-13: Paginação de contas com parâmetros skip e limit
- **Endpoint**: `GET /api/v1/accounts/`
- **Categoria**: Happy Path / Pagination
```gherkin
Scenario: SCEN-ACC-13 - Paginação customizada com skip e limit
  Given um usuário com 5 contas cadastradas ("Conta 1", "Conta 2", "Conta 3", "Conta 4", "Conta 5")
  When o cliente envia uma requisição GET para "/api/v1/accounts/?skip=2&limit=2"
  Then o código de status deve ser 200
  And o array retornado deve conter exatamente 2 contas
  And as contas retornadas devem corresponder à terceira e quarta contas na ordenação
```

#### SCEN-ACC-14: Paginação com skip além da quantidade total de contas
- **Endpoint**: `GET /api/v1/accounts/`
- **Categoria**: Boundary / Pagination
```gherkin
Scenario: SCEN-ACC-14 - Consulta com skip superior ao total de contas existentes
  Given um usuário com 2 contas cadastradas
  When o cliente envia uma requisição GET para "/api/v1/accounts/?skip=10&limit=10"
  Then o código de status deve ser 200
  And o resultado deve ser uma lista vazia "[]"
```

#### SCEN-ACC-15: Rejeição de paginação com parâmetros inválidos (não inteiros)
- **Endpoint**: `GET /api/v1/accounts/`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario Outline: SCEN-ACC-15 - Validação de erro para query params de paginação inválidos (<parametro>)
  Given um usuário autenticado com token válido
  When o cliente envia uma requisição GET para "/api/v1/accounts/?<query_string>"
  Then o código de status deve ser 422
  And o schema da resposta deve validar HTTPValidationError

  Examples:
    | parametro         | query_string         |
    | skip string       | skip=invalido        |
    | limit string      | limit=muitos         |
    | skip decimal      | skip=1.5             |
```

#### SCEN-ACC-16: Rejeição de listagem de contas sem token de autenticação
- **Endpoint**: `GET /api/v1/accounts/`
- **Categoria**: Security / Authentication
```gherkin
Scenario: SCEN-ACC-16 - Consulta de listagem de contas sem cabeçalho Authorization
  Given nenhuma credencial de autenticação fornecida
  When o cliente envia uma requisição GET para "/api/v1/accounts/"
  Then o código de status deve ser 401
```

---

### User Story 3 - Consulta de Detalhes e Saldo Dinâmico (`GET /api/v1/accounts/{account_id}`) (Priority: P2)

Como um usuário da plataforma Finance Organizer,  
Quero consultar os detalhes de uma conta específica pelo seu identificador `account_id`,  
Para inspecionar o saldo consolidado atualizado e os dados cadastrais da carteira.

**Why this priority**: A visualização individual da conta provê a checagem detalhada do patrimônio e serve de base para conferência de conciliação financeira.

**Independent Test**: Criar uma conta, injetar transações de receita e despesa, e executar `GET /api/v1/accounts/{account_id}`, validando se `saldo_calculado` reflete exatamente a diferença `receitas - despesas`.

**Acceptance Scenarios**:

#### SCEN-ACC-17: Consulta com sucesso de conta existente pertencente ao usuário logado
- **Endpoint**: `GET /api/v1/accounts/{account_id}`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-ACC-17 - Consulta bem-sucedida de conta por ID válido
  Given um usuário autenticado com uma conta "Carteira Principal" criada previamente
  When o cliente envia uma requisição GET para "/api/v1/accounts/{account_id}"
  Then o código de status HTTP retornado deve ser 200
  And o corpo da resposta deve validar o schema AccountResponse
  And os campos "id", "apelido" e "user_id" devem corresponder aos dados da conta consultada
```

#### SCEN-ACC-18: Validação matemática do saldo calculado dinâmico da conta
- **Endpoint**: `GET /api/v1/accounts/{account_id}`
- **Categoria**: Integration / Business Calculation
```gherkin
Scenario: SCEN-ACC-18 - Cálculo dinâmico de saldo (receitas menos despesas)
  Given um usuário autenticado com uma conta recém-criada (saldo inicial "0.00")
  And foram registradas 2 transações de RECEITA no valor de "1500.50" e "500.00" associadas a essa conta
  And foi registrada 1 transação de DESPESA no valor de "350.25" associada a essa conta
  When o cliente envia uma requisição GET para "/api/v1/accounts/{account_id}"
  Then o código de status retornado deve ser 200
  And o campo "saldo_calculado" deve ser uma string com valor exatamente correspondente a "1650.25"
  And o valor deve cumprir a máscara regex "^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d*$"
```

#### SCEN-ACC-19: Tentativa de consulta com UUID inexistente no banco de dados
- **Endpoint**: `GET /api/v1/accounts/{account_id}`
- **Categoria**: Negative / Not Found
```gherkin
Scenario: SCEN-ACC-19 - Consulta de conta com UUID inexistente
  Given um usuário autenticado com token válido
  And um identificador UUID gerado aleatoriamente e não existente no banco
  When o cliente envia uma requisição GET para "/api/v1/accounts/{random_uuid}"
  Then o código de status retornado deve ser 404
  And a mensagem de detalhe deve indicar que a conta não foi encontrada
```

#### SCEN-ACC-20: Proteção contra Quebra de Controle de Acesso (IDOR / BOLA)
- **Endpoint**: `GET /api/v1/accounts/{account_id}`
- **Categoria**: Security / Authorization (IDOR)
```gherkin
Scenario: SCEN-ACC-20 - Tentativa do Usuário A acessar a conta do Usuário B (IDOR)
  Given o Usuário B possui uma conta cadastrada com id "CONTA-B-UUID"
  And o Usuário A está autenticado com seu próprio token JWT
  When o Usuário A envia uma requisição GET para "/api/v1/accounts/CONTA-B-UUID"
  Then o código de status HTTP retornado DEVE ser 404 (ou 403 Forbidden)
  And NENHUM dado da conta do Usuário B deve ser retornado para o Usuário A
```

#### SCEN-ACC-21: Rejeição de requisição com formato de account_id inválido (não-UUID)
- **Endpoint**: `GET /api/v1/accounts/{account_id}`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario: SCEN-ACC-21 - Consulta com account_id fora do formato UUID
  Given um usuário autenticado com token válido
  When o cliente envia uma requisição GET para "/api/v1/accounts/id-invalido-12345"
  Then o código de status HTTP retornado deve ser 422
  And a resposta deve validar o schema HTTPValidationError indicando erro de formato UUID
```

#### SCEN-ACC-22: Rejeição de consulta individual de conta sem autenticação
- **Endpoint**: `GET /api/v1/accounts/{account_id}`
- **Categoria**: Security / Authentication
```gherkin
Scenario: SCEN-ACC-22 - Consulta de conta sem token de sessão
  Given uma conta existente no sistema
  When uma requisição GET é enviada para "/api/v1/accounts/{account_id}" sem cabeçalho Authorization
  Then o código de status HTTP retornado deve ser 401
```

---

### User Story 4 - Atualização de Conta / Carteira (`PUT /api/v1/accounts/{account_id}`) (Priority: P2)

Como um usuário autenticado,  
Quero atualizar o apelido de uma das minhas contas existentes,  
Para refletir mudanças no nome ou na instituição financeira onde mantenho meus recursos.

**Why this priority**: A manutenção e renomeação de carteiras permite flexibilidade operacional sem necessidade de recriar contas e perder histórico financeiro.

**Independent Test**: Criar uma conta com apelido "Antigo", enviar `PUT /api/v1/accounts/{account_id}` com `{ "apelido": "Novo Nome" }`, validar retorno `200 OK` e conferir que o apelido foi atualizado.

**Acceptance Scenarios**:

#### SCEN-ACC-23: Atualização bem-sucedida de apelido da conta
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-ACC-23 - Atualização de apelido de conta existente
  Given um usuário autenticado com uma conta "Nome Antigo"
  And um payload de atualização com novo apelido:
    """json
    {
      "apelido": "Banco Inter"
    }
    """
  When o cliente envia uma requisição PUT para "/api/v1/accounts/{account_id}"
  Then o código de status HTTP retornado deve ser 200
  And o corpo da resposta deve validar o schema AccountResponse
  And o campo "apelido" deve ser atualizado para "Banco Inter"
  And os campos "id", "user_id" e "created_at" devem permanecer inalterados
```

#### SCEN-ACC-24: Atualização de apelido nos limites de caracteres (1 e 100 caracteres)
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Boundary Validation / Happy Path
```gherkin
Scenario Outline: SCEN-ACC-24 - Atualização de apelido nos limites permitidos (<limite>)
  Given um usuário autenticado com uma conta existente
  And um payload com apelido contendo <tamanho> caracteres
  When o cliente envia uma requisição PUT para "/api/v1/accounts/{account_id}"
  Then o código de status retornado deve ser 200
  And o campo "apelido" deve refletir o valor atualizado de tamanho <tamanho>

  Examples:
    | limite   | tamanho |
    | mínimo   | 1       |
    | máximo   | 100     |
```

#### SCEN-ACC-25: Rejeição de atualização com apelido vazio (0 caracteres)
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Negative / Boundary Validation
```gherkin
Scenario: SCEN-ACC-25 - Rejeição de atualização com apelido vazio
  Given um usuário autenticado com conta existente
  And um payload com apelido vazio: { "apelido": "" }
  When o cliente envia uma requisição PUT para "/api/v1/accounts/{account_id}"
  Then o código de status retornado deve ser 422
  And o apelido original da conta no banco deve permanecer inalterado
```

#### SCEN-ACC-26: Rejeição de atualização com apelido excedendo 100 caracteres
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Negative / Boundary Validation
```gherkin
Scenario: SCEN-ACC-26 - Rejeição de atualização com apelido acima de 100 caracteres
  Given um usuário autenticado com conta existente
  And um payload com apelido de 101 caracteres
  When o cliente envia uma requisição PUT para "/api/v1/accounts/{account_id}"
  Then o código de status retornado deve ser 422
```

#### SCEN-ACC-27: Tentativa de atualização de conta com UUID inexistente
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Negative / Not Found
```gherkin
Scenario: SCEN-ACC-27 - Atualização de conta inexistente
  Given um usuário autenticado com token válido
  And um UUID gerado aleatoriamente e inexistente
  When o cliente envia uma requisição PUT para "/api/v1/accounts/{random_uuid}" com payload válido
  Then o código de status retornado deve ser 404
```

#### SCEN-ACC-28: Proteção IDOR em atualização de conta pertencente a outro usuário
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Security / Authorization (IDOR)
```gherkin
Scenario: SCEN-ACC-28 - Tentativa de atualizar conta de terceiro (IDOR)
  Given o Usuário B possui a conta "Conta Segura de B"
  And o Usuário A autentica-se com seu próprio token
  When o Usuário A envia uma requisição PUT para "/api/v1/accounts/{conta_b_id}" com payload { "apelido": "Nome Invasor" }
  Then o código de status retornado DEVE ser 404 (ou 403 Forbidden)
  And o apelido da conta do Usuário B NÃO deve ser modificado
```

#### SCEN-ACC-29: Imutabilidade de identificadores e saldo durante o PUT
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Security / Data Integrity
```gherkin
Scenario: SCEN-ACC-29 - Preservação de campos imutáveis durante atualização
  Given uma conta existente com saldo_calculado "500.00"
  And um payload malicioso tentando sobrescrever identificadores e saldo:
    """json
    {
      "apelido": "Conta Modificada",
      "saldo_calculado": "0.00",
      "user_id": "00000000-0000-0000-0000-000000000000",
      "id": "11111111-1111-1111-1111-111111111111"
    }
    """
  When o cliente envia uma requisição PUT para "/api/v1/accounts/{account_id}"
  Then o código de status deve ser 200
  And o campo "saldo_calculado" na resposta deve continuar inalterado em "500.00"
  And os campos "id" e "user_id" originais devem ser mantidos intactos
```

#### SCEN-ACC-30: Rejeição de atualização com account_id fora do formato UUID
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario: SCEN-ACC-30 - Atualização com path parameter não-UUID
  Given um usuário autenticado com token válido
  When o cliente envia uma requisição PUT para "/api/v1/accounts/formato-invalido"
  Then o código de status deve ser 422
```

#### SCEN-ACC-31: Rejeição de atualização sem autenticação
- **Endpoint**: `PUT /api/v1/accounts/{account_id}`
- **Categoria**: Security / Authentication
```gherkin
Scenario: SCEN-ACC-31 - Atualização de conta sem credenciais
  Given uma conta existente no sistema
  When uma requisição PUT é enviada para "/api/v1/accounts/{account_id}" sem cabeçalho Authorization
  Then o código de status HTTP retornado deve ser 401
```

---

### User Story 5 - Exclusão de Conta e Integridade Referencial (`DELETE /api/v1/accounts/{account_id}`) (Priority: P2)

Como um usuário da plataforma Finance Organizer,  
Quero encerrar/excluir uma conta ou carteira que não utilizo mais,  
Para manter minha visão consolidada limpa e organizada.

**Why this priority**: O encerramento de contas garante controle total do ciclo de vida dos recursos pelo usuário e cumprimento do princípio de eliminação de dados.

**Independent Test**: Criar uma conta vazia, disparar `DELETE /api/v1/accounts/{account_id}`, validar código `204 No Content` sem corpo, e verificar que uma chamada subsequente `GET /api/v1/accounts/{account_id}` retorna `404 Not Found`.

**Acceptance Scenarios**:

#### SCEN-ACC-32: Exclusão com sucesso de conta vazia (sem transações vinculadas)
- **Endpoint**: `DELETE /api/v1/accounts/{account_id}`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-ACC-32 - Exclusão bem-sucedida de conta sem dependências
  Given um usuário autenticado com uma conta existente sem transações vinculadas
  When o cliente envia uma requisição DELETE para "/api/v1/accounts/{account_id}" com token válido
  Then o código de status retornado deve ser 204
  And o corpo da resposta deve ser vazio
  And uma requisição GET subsequente para "/api/v1/accounts/{account_id}" deve retornar 404 Not Found
```

#### SCEN-ACC-33: Integridade referencial ao excluir conta com transações associadas
- **Endpoint**: `DELETE /api/v1/accounts/{account_id}`
- **Categoria**: Referential Integrity / Data Cascade
```gherkin
Scenario: SCEN-ACC-33 - Exclusão de conta que possui transações financeiras vinculadas
  Given um usuário autenticado com uma conta vinculada a transações financeiras ativas
  When o cliente envia uma requisição DELETE para "/api/v1/accounts/{account_id}"
  Then o sistema DEVE adotar um dos comportamentos válidos de integridade:
    | comportamento        | status esperado | pós-condição                                              |
    | Cascade Delete       | 204 No Content  | As transações órfãs são deletadas e GET subsequente é 404 |
    | Integrity Protection | 400 ou 409      | A deleção é rejeitada e as transações são preservadas     |
  And em hipótese alguma o servidor pode responder com status 500 (Internal Server Error)
```

#### SCEN-ACC-34: Tentativa de exclusão de conta com UUID inexistente
- **Endpoint**: `DELETE /api/v1/accounts/{account_id}`
- **Categoria**: Negative / Not Found
```gherkin
Scenario: SCEN-ACC-34 - Exclusão de conta com identificador inexistente
  Given um usuário autenticado com token válido
  And um UUID gerado aleatoriamente e não cadastrado
  When o cliente envia uma requisição DELETE para "/api/v1/accounts/{random_uuid}"
  Then o código de status retornado deve ser 404
```

#### SCEN-ACC-35: Proteção IDOR em tentativa de exclusão de conta de outro usuário
- **Endpoint**: `DELETE /api/v1/accounts/{account_id}`
- **Categoria**: Security / Authorization (IDOR)
```gherkin
Scenario: SCEN-ACC-35 - Tentativa de deletar conta de outro usuário (IDOR)
  Given o Usuário B possui a conta cadastrada "Conta Privada B"
  And o Usuário A está autenticado com seu próprio token
  When o Usuário A envia uma requisição DELETE para "/api/v1/accounts/{conta_b_id}"
  Then o código de status retornado DEVE ser 404 (ou 403 Forbidden)
  And a conta do Usuário B NÃO deve ser deletada
  And o Usuário B ainda deve conseguir consultar sua conta com sucesso (status 200)
```

#### SCEN-ACC-36: Rejeição de exclusão com account_id fora do formato UUID
- **Endpoint**: `DELETE /api/v1/accounts/{account_id}`
- **Categoria**: Negative / Schema Validation
```gherkin
Scenario: SCEN-ACC-36 - Exclusão com account_id não-UUID
  Given um usuário autenticado com token válido
  When o cliente envia uma requisição DELETE para "/api/v1/accounts/id-invalido-abc"
  Then o código de status HTTP retornado deve ser 422
```

#### SCEN-ACC-37: Rejeição de exclusão de conta sem autenticação
- **Endpoint**: `DELETE /api/v1/accounts/{account_id}`
- **Categoria**: Security / Authentication
```gherkin
Scenario: SCEN-ACC-37 - Exclusão de conta sem cabeçalho Authorization
  Given uma conta existente no sistema
  When uma requisição DELETE é enviada para "/api/v1/accounts/{account_id}" sem token
  Then o código de status retornado deve ser 401
```

---

## Edge Cases

- **Apelido com Espaços em Branco**: Envio de `"   "` (apenas espaços). O backend deve rejeitar com `422` ou efetuar trim e validar contra `minLength: 1`.
- **Caracteres Especiais e Emojis**: Apelidos com caracteres acentuados ("Poupança Família") ou emojis ("💰 Carteira"). O sistema deve persistir e retornar com encoding UTF-8 íntegro sem corrupção.
- **Padrão de Paginação Inverso**: Envio de `limit=0` ou `limit < 0` e `skip < 0`. O backend deve responder com `422 Unprocessable Entity` ou aplicar valores padrão sanitizados.
- **Concorrência em Saldo Calculado**: Registro simultâneo de transações concorrentes na mesma conta enquanto o saldo é consultado via `GET /api/v1/accounts/{account_id}`, garantindo coerência matemática sem race condition.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST permitir a criação de contas/carteiras via `POST /api/v1/accounts/` para usuários autenticados, retornando `201 Created` e contrato `AccountResponse`.
- **FR-002**: O campo `apelido` em `AccountCreate` MUST ter tamanho mínimo de 1 caractere e máximo de 100 caracteres. Valores fora dessa faixa MUST ser rejeitados com `422 Unprocessable Entity`.
- **FR-003**: Toda conta criada MUST ser vinculada automaticamente ao `user_id` do usuário autenticado no token JWT, ignorando qualquer tentativa de injeção externa desse campo.
- **FR-004**: O campo `saldo_calculado` de uma conta recém-criada MUST ser inicializado estritamente como `"0.00"`.
- **FR-005**: O sistema MUST listar apenas as contas pertencentes ao usuário autenticado em `GET /api/v1/accounts/`, retornando `200 OK` e um array de `AccountResponse`.
- **FR-006**: A listagem de contas MUST suportar paginação via query parameters `skip` (default 0) e `limit` (default 100). Parâmetros não numéricos MUST retornar `422 Unprocessable Entity`.
- **FR-007**: Usuários que não possuem contas cadastradas MUST receber um array vazio `[]` com status `200 OK` ao consultar `GET /api/v1/accounts/`.
- **FR-008**: O sistema MUST fornecer a consulta de detalhes de conta específica via `GET /api/v1/accounts/{account_id}` para o usuário titular, retornando `200 OK`.
- **FR-009**: O campo `saldo_calculado` retornado na consulta da conta MUST refletir dinamicamente a soma algébrica das transações vinculadas à conta (`receitas - despesas`), formatado como string numérica compatível com o regex `^(?!^[-+.]*$)[+-]?0*\d*\.?\d*$`.
- **FR-010**: O sistema MUST bloquear o acesso de qualquer usuário a contas pertencentes a outros usuários (IDOR) em `GET`, `PUT` e `DELETE`, retornando `404 Not Found` (ou `403 Forbidden`).
- **FR-011**: O sistema MUST permitir a atualização do `apelido` de uma conta existente pelo titular via `PUT /api/v1/accounts/{account_id}`, retornando `200 OK`.
- **FR-012**: A atualização de conta via `PUT` MUST respeitar as mesmas regras de limite de caracteres do apelido (1 a 100 caracteres), rejeitando violações com `422 Unprocessable Entity`.
- **FR-013**: Os campos `id`, `user_id`, `created_at` e `saldo_calculado` MUST ser imutáveis via requisição `PUT /api/v1/accounts/{account_id}`.
- **FR-014**: O sistema MUST permitir a exclusão de conta via `DELETE /api/v1/accounts/{account_id}` pelo usuário titular, retornando `204 No Content` sem corpo de resposta.
- **FR-015**: Após a exclusão bem-sucedida de uma conta, qualquer consulta subsequente por seu identificador MUST responder com `404 Not Found`.
- **FR-016**: A exclusão de contas com transações vinculadas MUST manter a integridade referencial do banco de dados (via exclusão em cascata controlada ou rejeição segura com `400/409`), sem disparar erro interno `500`.
- **FR-017**: Todas as operações dos endpoints de contas (`POST`, `GET`, `PUT`, `DELETE`) MUST exigir autenticação Bearer JWT válida, respondendo com `401 Unauthorized` em caso de ausência, expiração ou adulteração de token.
- **FR-018**: Todo parâmetro `account_id` recebido no path que não cumprir o formato UUID v4 MUST ser rejeitado com `422 Unprocessable Entity`.

---

### Key Entities

- **Account (Conta/Carteira)**: Representa uma carteira ou instituição financeira vinculada a um usuário. Possui atributos `id` (UUID), `user_id` (UUID), `apelido` (string de 1 a 100 chars), `saldo_calculado` (string decimal) e `created_at` (ISO 8601).
- **User (Usuário)**: Entidade proprietária da conta. Uma conta pertence exclusivamente a um único usuário (relação 1:N entre User e Account).
- **Transaction (Transação)**: Movimentação financeira de receita ou despesa associada a uma conta específica através da chave estrangeira `conta_id`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos cenários de teste automatizados da matriz de Contas (37 cenários BDD) implementados e aprovados com 0 falhas em Karate DSL.
- **SC-002**: 100% de isolamento multi-tenant comprovado: zero vazamento de dados de contas entre usuários distintos em testes de IDOR.
- **SC-003**: Acurácia contábil de 100% na validação do campo `saldo_calculado` frente a transações sintéticas injetadas.
- **SC-004**: Execução paralela da suíte de Contas em 3 threads no `TestRunner` sem colisões de dados ou flakiness.
- **SC-005**: 100% de conformidade com os contratos OpenAPI `AccountResponse`, `AccountCreate`, `AccountUpdate` e `HTTPValidationError`.
- **SC-006**: Cobertura integral da matriz de códigos HTTP: `200`, `201`, `204`, `401`, `404` e `422`.

---

## Assumptions

- O endpoint base da API sob teste é `http://100.75.210.114:8000`, conforme estabelecido na Constituição do projeto.
- A autenticação é provida via tokens Bearer JWT emitidos por `POST /api/v1/auth/login`.
- Os testes automatizados utilizarão o helper [`auth-helper.feature`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/src/test/java/features/helpers/auth-helper.feature) para provisionar dinamicamente novos usuários isolados para cada cenário, cumprindo o Princípio VII da Constituição.
- Testes de IDOR provisionam dois usuários distintos (Titular e Intruso) em runtime para testar a tentativa de acesso cruzado.
