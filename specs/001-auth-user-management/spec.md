# Feature Specification: Autenticação e Gestão de Usuário (Auth API)

**Feature Branch**: `001-auth-user-management`

**Created**: 2026-09-23

**Status**: Draft

**Input**: User description: "Autenticação e Gestão de Usuário (Auth) - Matriz exaustiva de cenários de testes de API cobrindo 100% das regras de negócio, limites de schema, autenticação/autorização e integridade transacional de dados baseados em openapi.json"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cadastro e Validação de Contas de Usuário (Priority: P1)

Como um novo usuário do sistema Finance Organizer,
Quero me cadastrar fornecendo e-mail válido e uma senha segura,
Para que eu possa criar minha identidade na plataforma com integridade cadastral e proteção de dados.

**Why this priority**: O cadastro é a porta de entrada para qualquer cliente na plataforma. Falhas nessa funcionalidade impedem novos usuários de acessar o sistema e expõem o backend a vulnerabilidades de dados ou corrupção de schema.

**Independent Test**: Pode ser testado de forma totalmente independente gerando um e-mail randômico sintético via Datafaker e submetendo uma requisição `POST /api/v1/auth/register`, verificando o status HTTP `201 Created` e a conformidade estrita com o contrato `UserResponse`.

**Acceptance Scenarios**:

#### SCEN-REG-01: Cadastro bem-sucedido com e-mail válido e senha no limite mínimo (8 caracteres)
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Happy Path / Boundary Validation
```gherkin
Scenario: SCEN-REG-01 - Cadastro bem-sucedido com senha mínima (8 caracteres)
  Given o sistema está disponível e configurado para aceitar novos registros
  And um payload sintético válido é gerado com e-mail único e senha de exatamente 8 caracteres
    """json
    {
      "email": "user_min_pass_<unique>@example.com",
      "password": "Password1"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register" com o payload
  Then o código de status HTTP retornado deve ser 201
  And o corpo da resposta deve validar estritamente o schema UserResponse:
    | campo      | tipo      | validação                                |
    | id         | string    | UUID v4 válido                           |
    | email      | string    | idêntico ao e-mail enviado               |
    | is_active  | boolean   | exatamente true                          |
    | created_at | string    | formato ISO 8601 (date-time)             |
  And o hash de senha NÃO deve ser retornado em nenhuma propriedade da resposta
  And como pós-condição, o usuário deve estar persistido no banco com estado ativo (is_active = true)
```

#### SCEN-REG-02: Cadastro bem-sucedido com senha longa no limite máximo suportado (72 caracteres)
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Happy Path / Boundary Validation
```gherkin
Scenario: SCEN-REG-02 - Cadastro bem-sucedido com senha máxima (72 caracteres)
  Given o sistema está disponível para novos registros
  And um payload sintético válido é gerado com e-mail único e senha longa de exatamente 72 caracteres
    """json
    {
      "email": "user_max_pass_<unique>@example.com",
      "password": "Ab1!aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa72char"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register" com o payload
  Then o código de status HTTP retornado deve ser 201
  And o corpo da resposta deve validar o schema UserResponse com id em formato UUID e is_active igual a true
  And como pós-condição, o usuário deve ser armazenado com sucesso usando hashing criptográfico
```

#### SCEN-REG-03: Rejeição de cadastro com formato de e-mail inválido
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Negative / Schema & Format Validation
```gherkin
Scenario Outline: SCEN-REG-03 - Rejeição de cadastro com e-mail malformado
  Given um payload de cadastro com o e-mail inválido "<email_invalido>" e senha válida
    """json
    {
      "email": "<email_invalido>",
      "password": "Password123"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register"
  Then o código de status HTTP retornado deve ser 422
  And o corpo da resposta deve validar o schema HTTPValidationError detalhando erro de formato no campo email
  And como pós-condição, nenhuma conta de usuário deve ser criada no banco de dados

  Examples:
    | email_invalido             | motivo_falha                  |
    | usuario_sem_arroba.com     | ausência de arroba            |
    | usuario@sem_dominio        | domínio de nível superior nulo|
    | usuario com espacos@dom.com| espaços em branco intercalados|
    | @dominio.com               | ausência de identificador local|
```

#### SCEN-REG-04: Rejeição de cadastro com e-mail duplicado (Validação de Unicidade)
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Negative / Business Conflict
```gherkin
Scenario: SCEN-REG-04 - Conflito cadastral para e-mail já existente
  Given que já existe um usuário previamente cadastrado com o e-mail "registered_user_<unique>@example.com"
  And um novo payload de cadastro tenta reutilizar o mesmo e-mail com outra senha
    """json
    {
      "email": "registered_user_<unique>@example.com",
      "password": "AnotherPassword456"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register"
  Then o código de status HTTP retornado deve ser 422 ou 409
  And o corpo da resposta deve indicar erro de violação de unicidade ou conflito cadastral
  And como pós-condição, o registro original permanece inalterado e nenhum novo registro é adicionado
```

#### SCEN-REG-05: Rejeição de cadastro com senha abaixo do limite mínimo (menor que 8 caracteres)
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Negative / Boundary Validation
```gherkin
Scenario: SCEN-REG-05 - Rejeição de senha com 7 caracteres
  Given um payload de cadastro com e-mail único e senha curta de 7 caracteres
    """json
    {
      "email": "short_pass_<unique>@example.com",
      "password": "Pass123"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register"
  Then o código de status HTTP retornado deve ser 422
  And o corpo da resposta deve validar o schema HTTPValidationError indicando violação do minLength (8) no campo password
  And como pós-condição, nenhum usuário é cadastrado
```

#### SCEN-REG-06: Rejeição de cadastro com senha acima do limite máximo (maior que 72 caracteres)
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Negative / Boundary Validation
```gherkin
Scenario: SCEN-REG-06 - Rejeição de senha com 73 caracteres
  Given um payload de cadastro com e-mail único e senha excessiva de 73 caracteres
    """json
    {
      "email": "long_pass_<unique>@example.com",
      "password": "Ab1!aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa73chars"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register"
  Then o código de status HTTP retornado deve ser 422
  And o corpo da resposta deve validar o schema HTTPValidationError indicando violação do maxLength (72) no campo password
  And como pós-condição, nenhum usuário é cadastrado
```

#### SCEN-REG-07: Rejeição de cadastro por ausência de campos obrigatórios
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Negative / Missing Required Fields
```gherkin
Scenario Outline: SCEN-REG-07 - Ausência de campos obrigatórios no cadastro
  Given um payload de cadastro <descricao_payload>:
    """json
    <payload>
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register"
  Then o código de status HTTP retornado deve ser 422
  And a resposta deve validar o schema HTTPValidationError apontando ausência do campo obrigatório correspondente
  And como pós-condição, nenhum usuário é registrado

  Examples:
    | descricao_payload  | payload                                         |
    | sem campo email    | {"password": "ValidPassword123"}                |
    | sem campo password | {"email": "missing_pass_<unique>@example.com"}  |
    | payload vazio      | {}                                              |
```

#### SCEN-REG-08: Rejeição de cadastro por tipagem de dados incorreta
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Negative / Type Safety
```gherkin
Scenario: SCEN-REG-08 - Tipagem incorreta no e-mail ou payload não estruturado
  Given um payload onde o campo email é fornecido como numérico
    """json
    {
      "email": 123456789,
      "password": "ValidPassword123"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register"
  Then o código de status HTTP retornado deve ser 422
  And o schema de resposta deve ser HTTPValidationError indicando erro de tipagem de string
```

#### SCEN-REG-09: Rejeição ou sanitização estrita de injeção de campos extras (Mass Assignment Protection)
- **Endpoint**: `POST /api/v1/auth/register`
- **Categoria**: Security / Mass Assignment Protection
```gherkin
Scenario: SCEN-REG-09 - Tentativa de injeção de atributos não mapeados em UserCreate
  Given um payload de cadastro contendo atributos arbitrários maliciosos
    """json
    {
      "email": "mass_assign_<unique>@example.com",
      "password": "ValidPassword123",
      "is_active": false,
      "role": "admin",
      "superuser": true
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/register"
  Then o código de status HTTP retornado deve ser 422 (se extra='forbid') OU 201 Created (se extra='ignore')
  And se 201 Created for retornado, os campos extras não devem estar presentes na entidade criada e o atributo is_active deve obrigatoriamente permanecer true por padrão
```

---

### User Story 2 - Autenticação e Emissão de Tokens de Acesso (Priority: P1)

Como um usuário cadastrado e ativo na plataforma,
Quero fornecer minhas credenciais de e-mail e senha,
Para que o sistema autentique minha identidade e me emita um token JWT seguro para consumir as APIs protegidas.

**Why this priority**: A autenticação é o mecanismo central de segurança que viabiliza o consumo de todos os recursos restritos (contas, transações, investimentos). Sem ela, nenhuma transação financeira pode ser realizada.

**Independent Test**: Pode ser testado de forma autônoma criando um usuário temporário e disparando `POST /api/v1/auth/login`, validando o retorno `200 OK` e o formato do contrato `Token` (`access_token` e `token_type: "bearer"`).

**Acceptance Scenarios**:

#### SCEN-LOG-01: Login bem-sucedido com credenciais válidas existentes
- **Endpoint**: `POST /api/v1/auth/login`
- **Categoria**: Happy Path / Authentication
```gherkin
Scenario: SCEN-LOG-01 - Autenticação com sucesso e emissão de JWT
  Given que existe um usuário registrado e ativo com e-mail "login_user_<unique>@example.com" e senha "Password123"
  And o payload de autenticação é preenchido com essas credenciais corretas
    """json
    {
      "email": "login_user_<unique>@example.com",
      "password": "Password123"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/login"
  Then o código de status HTTP retornado deve ser 200
  And o corpo da resposta deve validar estritamente o schema Token:
    | campo        | tipo   | validação                              |
    | access_token | string | token JWT não vazio (3 blocos base64)  |
    | token_type   | string | exatamente "bearer"                   |
  And o access_token emitido deve conter claims válidas associadas ao ID do usuário
```

#### SCEN-LOG-02: Rejeição de login com senha incorreta para e-mail existente
- **Endpoint**: `POST /api/v1/auth/login`
- **Categoria**: Negative / Security & Authentication Failure
```gherkin
Scenario: SCEN-LOG-02 - Tentativa de autenticação com senha inválida
  Given que existe um usuário registrado com e-mail "user_auth_<unique>@example.com" e senha "CorrectPassword123"
  And o payload de login informa o e-mail correto com uma senha divergente "WrongPassword999"
    """json
    {
      "email": "user_auth_<unique>@example.com",
      "password": "WrongPassword999"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/login"
  Then o código de status HTTP retornado deve ser 401 ou 422
  And nenhum token de acesso (access_token) deve ser emitido
  And a mensagem de erro não deve divulgar informações excessivas que permitam brute-force
```

#### SCEN-LOG-03: Rejeição de login com e-mail não cadastrado na base
- **Endpoint**: `POST /api/v1/auth/login`
- **Categoria**: Negative / User Non-Existence
```gherkin
Scenario: SCEN-LOG-03 - Tentativa de login com e-mail não cadastrado
  Given um e-mail randômico garantidamente inexistente no banco "non_existent_<unique>@example.com"
  And o payload de login é submetido com qualquer senha
    """json
    {
      "email": "non_existent_<unique>@example.com",
      "password": "ArbitraryPassword123"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/login"
  Then o código de status HTTP retornado deve ser 401 ou 422
  And nenhum token de acesso deve ser emitido
```

#### SCEN-LOG-04: Bloqueio de login para usuário com conta inativa (is_active: false)
- **Endpoint**: `POST /api/v1/auth/login`
- **Categoria**: Security / Account Status Validation
```gherkin
Scenario: SCEN-LOG-04 - Bloqueio de acesso para conta desativada
  Given que existe um usuário cadastrado com credenciais válidas, mas com status is_active = false
  And o payload de login envia as credenciais desse usuário inativo
    """json
    {
      "email": "inactive_user_<unique>@example.com",
      "password": "Password123"
    }
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/login"
  Then o código de status HTTP retornado deve ser 401 ou 403
  And a emissão de token de acesso deve ser rejeitada
```

#### SCEN-LOG-05: Rejeição de login com campos obrigatórios ausentes ou em branco
- **Endpoint**: `POST /api/v1/auth/login`
- **Categoria**: Negative / Validation Error
```gherkin
Scenario Outline: SCEN-LOG-05 - Payload de login com campos vazios ou nulos
  Given um payload de login com parâmetros inválidos:
    """json
    <payload>
    """
  When o cliente envia uma requisição POST para "/api/v1/auth/login"
  Then o código de status HTTP retornado deve ser 422
  And a resposta deve validar o schema HTTPValidationError
  And nenhum token é gerado

  Examples:
    | cenario            | payload                               |
    | e-mail vazio       | {"email": "", "password": "Pass123"}  |
    | senha vazia        | {"email": "user@test.com", "password": ""} |
    | campos nulos       | {"email": null, "password": null}     |
```

---

### User Story 3 - Consulta de Perfil do Usuário Autenticado (Priority: P2)

Como um usuário autenticado,
Quero consultar meu perfil atual através do meu token de sessão,
Para verificar meus dados cadastrais e confirmar que minha sessão permanece válida e íntegra.

**Why this priority**: Permite que aplicações clientes validem o token obtido no login e renderizem o estado do usuário logado de forma segura e contextual.

**Independent Test**: Pode ser testado de forma independente autenticando um usuário, capturando o `access_token`, submetendo `GET /api/v1/auth/me` com o cabeçalho `Authorization: Bearer <token>` e verificando o retorno `200 OK` compatível com `UserResponse`.

**Acceptance Scenarios**:

#### SCEN-ME-01: Consulta de perfil bem-sucedida com Bearer token válido
- **Endpoint**: `GET /api/v1/auth/me`
- **Categoria**: Happy Path / Profile Query
```gherkin
Scenario: SCEN-ME-01 - Obtenção dos dados do usuário logado via token válido
  Given que um usuário "me_user_<unique>@example.com" foi registrado e obteve um access_token válido via login
  When o cliente envia uma requisição GET para "/api/v1/auth/me" com o cabeçalho "Authorization: Bearer <access_token>"
  Then o código de status HTTP retornado deve ser 200
  And o corpo da resposta deve validar estritamente o schema UserResponse:
    | campo      | tipo      | validação                                     |
    | id         | string    | UUID correspondente ao id do usuário logado   |
    | email      | string    | exatamente "me_user_<unique>@example.com"     |
    | is_active  | boolean   | true                                          |
    | created_at | string    | formato ISO 8601                              |
  And sob nenhuma circunstância os campos password ou password_hash devem estar expostos
```

#### SCEN-ME-02: Rejeição de consulta de perfil sem o cabeçalho Authorization
- **Endpoint**: `GET /api/v1/auth/me`
- **Categoria**: Security / Missing Authorization
```gherkin
Scenario: SCEN-ME-02 - Acesso não autorizado por ausência de cabeçalho
  Given uma requisição GET para "/api/v1/auth/me" sem fornecer nenhum cabeçalho de autorização
  When a requisição é processada pela API
  Then o código de status HTTP retornado deve ser 401
  And nenhuma informação de perfil de usuário deve ser revelada
```

#### SCEN-ME-03: Rejeição de consulta com cabeçalho Authorization malformado
- **Endpoint**: `GET /api/v1/auth/me`
- **Categoria**: Security / Malformed Authorization Header
```gherkin
Scenario Outline: SCEN-ME-03 - Cabeçalho de autorização com formato incorreto
  Given que um usuário possui um token válido
  When o cliente envia uma requisição GET para "/api/v1/auth/me" com o cabeçalho "Authorization: <cabecalho_malformado>"
  Then o código de status HTTP retornado deve ser 401
  And nenhum dado sensível ou de perfil deve ser retornado

  Examples:
    | cabecalho_malformado        | descricao_problema              |
    | <token>                     | ausência do prefixo Bearer      |
    | Basic dXNlcjpwYXNz          | esquema de autorização incorreto|
    | Bearer                      | prefixo sem token associado     |
```

#### SCEN-ME-04: Rejeição de consulta com token expirado, corrompido ou assinatura violada
- **Endpoint**: `GET /api/v1/auth/me`
- **Categoria**: Security / Invalid Token
```gherkin
Scenario Outline: SCEN-ME-04 - Token inválido, expirado ou com assinatura adulterada
  Given uma tentativa de acesso ao endpoint "/api/v1/auth/me" utilizando um token com <condicao_token>:
  When o cliente submete o cabeçalho "Authorization: Bearer <token_invalido>"
  Then o código de status HTTP retornado deve ser 401
  And o acesso aos dados da conta deve ser integralmente bloqueado

  Examples:
    | condicao_token            | token_invalido                                           |
    | assinatura adulterada     | eyJhbGciOiJIUzI1NiJ9.payload_falso.assinatura_adulterada |
    | token expirado            | token_jwt_com_claim_exp_no_passado                       |
    | string arbitrária         | token_totalmente_invalido_12345                          |
```

---

### User Story 4 - Exclusão Imediata da Conta e Efeito Cascata Transacional (Priority: P2)

Como um usuário da plataforma Finance Organizer que deseja encerrar seu relacionamento,
Quero solicitar a exclusão imediata (Hard Delete) da minha conta,
Para que todos os meus dados cadastrais, contas financeiras, transações e posições de investimentos sejam irrevogavelmente expurgados sem falhas de integridade referencial.

**Why this priority**: Conformidade com direitos de privacidade (LGPD/GDPR) e garantia de integridade estrutural do banco de dados (eliminação completa de registros órfãos e inexistência de erros de Foreign Key).

**Independent Test**: Pode ser testado de forma autônoma criando um usuário com árvore completa de dados filhos (contas, transações, investimentos), disparando `DELETE /api/v1/auth/me` e verificando o retorno `204 No Content`, acompanhado da comprovação de que as credenciais e o token não têm mais acesso ao sistema.

**Acceptance Scenarios**:

#### SCEN-DEL-01: Exclusão imediata bem-sucedida (Hard Delete) de conta sem vínculos
- **Endpoint**: `DELETE /api/v1/auth/me`
- **Categoria**: Happy Path / Account Hard Delete
```gherkin
Scenario: SCEN-DEL-01 - Exclusão imediata de usuário simples
  Given que existe um usuário ativo "del_simple_<unique>@example.com" autenticado com access_token válido
  And esse usuário não possui nenhuma conta bancária, transação ou investimento vinculado
  When o cliente envia uma requisição DELETE para "/api/v1/auth/me" com o cabeçalho de autorização válido
  Then o código de status HTTP retornado deve ser 204
  And o corpo da resposta deve ser vazio
  And como pós-condição, o registro do usuário deve ser fisicamente expurgado do banco de dados
```

#### SCEN-DEL-02: Exclusão de conta com limpeza em cascata (contas, transações e investimentos)
- **Endpoint**: `DELETE /api/v1/auth/me`
- **Categoria**: Happy Path / Cascade Purge & Referential Integrity
```gherkin
Scenario: SCEN-DEL-02 - Exclusão com limpeza em cascata de dados financeiros correlacionados
  Given que existe um usuário registrado e autenticado com access_token
  And esse usuário possui registros associados nas entidades filhas:
    | entidade    | detalhes do registro criado                                   |
    | accounts    | pelo menos uma carteira ativa criada via POST /accounts/      |
    | transactions| pelo menos uma transação criada vinculada à conta do usuário  |
    | investments | pelo menos uma posição de investimento criada via /investments/|
  When o cliente envia uma requisição DELETE para "/api/v1/auth/me" com o cabeçalho Bearer do usuário
  Then o código de status HTTP retornado deve ser 204
  And a operação não deve disparar violação de integridade referencial ou erro interno (500)
  And como pós-condição no banco de dados:
    | entidade_alvo | condicao_esperada                                           |
    | users         | registro do usuário deletado                                |
    | accounts      | todas as contas do user_id foram expurgadas                 |
    | transactions  | todas as transações do user_id foram expurgadas             |
    | investments   | todas as posições de investimento do user_id foram expurgadas|
```

#### SCEN-DEL-03: Revogação de acesso e bloqueio de login subsequente
- **Endpoint**: `POST /api/v1/auth/login` (após DELETE)
- **Categoria**: Post-Condition Access Validation
```gherkin
Scenario: SCEN-DEL-03 - Impossibilidade de login após exclusão da conta
  Given que um usuário "deleted_user_<unique>@example.com" teve sua conta excluída com sucesso via DELETE /api/v1/auth/me
  When o cliente tenta realizar novo login em "/api/v1/auth/login" usando as credenciais do usuário recém-deletado
  Then o código de status HTTP retornado deve ser 401 ou 422
  And nenhum token de sessão deve ser gerado
```

#### SCEN-DEL-04: Rejeição imediata de consultas reutilizando o token da conta deletada
- **Endpoint**: `GET /api/v1/auth/me` (após DELETE)
- **Categoria**: Post-Condition Token Invalidation
```gherkin
Scenario: SCEN-DEL-04 - Rejeição de token de sessão previamente emitido após exclusão
  Given que um usuário autenticado deletou sua conta via DELETE /api/v1/auth/me
  When o cliente tenta reutilizar o mesmo access_token para consultar "/api/v1/auth/me"
  Then o código de status HTTP retornado deve ser 401
  And nenhuma informação cadastral deve ser retornada
```

#### SCEN-DEL-05: Rejeição de exclusão sem token ou com token inválido
- **Endpoint**: `DELETE /api/v1/auth/me`
- **Categoria**: Security / Unauthorized Deletion Attempt
```gherkin
Scenario: SCEN-DEL-05 - Tentativa não autorizada de exclusão de conta
  Given uma requisição DELETE para "/api/v1/auth/me" sem cabeçalho Authorization ou com token inválido
  When a requisição é submetida ao servidor
  Then o código de status HTTP retornado deve ser 401
  And nenhum dado de usuário ou de suas carteiras deve ser excluído do sistema
```

---

### Edge Cases

- **Colisão Concorrente de E-mails**: Duas requisições simultâneas de cadastro para o mesmo e-mail devem garantir que exatamente uma tenha sucesso (`201`) e a outra seja rejeitada (`422`/`409`), sem gerar inconsistência no banco de dados.
- **Caracteres Especiais e Unicode no E-mail e Senha**: Validação de senhas com caracteres Unicode complexos, acentuações e símbolos especiais para assegurar que a codificação UTF-8 e a função de hash criptográfico (ex: bcrypt/argon2) processem a string sem truncamento silencioso.
- **Tentativa de Reutilização de Identificador**: Após o hard delete de um usuário, uma nova tentativa de cadastro com o mesmo e-mail deve ser permitida como uma nova conta (gerando novo UUID distinto), desde que a política de privacidade permita re-cadastro.
- **Deleção Concorrente com Criação de Transação**: Tentativa de registrar uma transação no exato momento em que o endpoint de deleção da conta está em execução deve resultar em consistência transacional (ou a transação é criada e deletada na cascata, ou falha com erro de autorização/entidade inexistente).
- **Tratamento de Payload Vazio ou Não JSON**: Envio de strings literais, XML ou corpo binário para endpoints que requerem `application/json` deve resultar em rejeição padronizada `422 Unprocessable Entity`.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE disponibilizar o endpoint `POST /api/v1/auth/register` para permitir o cadastro anônimo de novos usuários recebendo e-mail e senha.
- **FR-002**: O sistema DEVE validar o formato de e-mail conforme a RFC de endereçamento e garantir a unicidade de e-mail na base cadastral, rejeitando duplicidades com código HTTP 422 ou 409.
- **FR-003**: O sistema DEVE validar as regras de fronteira de senha no cadastro: tamanho mínimo obrigatório de 8 caracteres e tamanho máximo de 72 caracteres, rejeitando violações com código HTTP 422.
- **FR-004**: O sistema DEVE retornar o código HTTP `201 Created` e a entidade `UserResponse` (`id` como UUID, `email`, `is_active: true`, `created_at` em ISO 8601) em caso de cadastro bem-sucedido.
- **FR-005**: O sistema NÃO DEVE expor senhas em texto puro ou hashes criptográficos em nenhuma resposta da API.
- **FR-006**: O sistema DEVE rejeitar tentativas de Mass Assignment no cadastro, não permitindo a sobrescrita de atributos de sistema como `is_active` ou criação de campos arbitrários.
- **FR-007**: O sistema DEVE disponibilizar o endpoint `POST /api/v1/auth/login` para autenticar credenciais registradas e emitir o contrato `Token` (`access_token` JWT válido e `token_type: "bearer"`) com código HTTP `200 OK`.
- **FR-008**: O sistema DEVE rejeitar tentativas de login com senha incorreta ou e-mail inexistente com resposta de erro genérica (401 ou 422) para mitigar enumeração de contas.
- **FR-009**: O sistema DEVE impedir a autenticação de contas cujo atributo `is_active` esteja como `false`, retornando código 401 ou 403.
- **FR-010**: O sistema DEVE disponibilizar o endpoint `GET /api/v1/auth/me` protegido por autenticação OAuth2 Bearer, retornando os dados do usuário autenticado no formato `UserResponse` com código HTTP `200 OK`.
- **FR-011**: O sistema DEVE rejeitar requisições a `GET /api/v1/auth/me` e `DELETE /api/v1/auth/me` que não contenham token, que contenham token com assinatura inválida, formato incorreto ou token expirado, retornando código HTTP `401 Unauthorized`.
- **FR-012**: O sistema DEVE disponibilizar o endpoint `DELETE /api/v1/auth/me` protegido por Bearer token para realizar a exclusão física imediata (Hard Delete) do usuário autenticado, retornando código HTTP `204 No Content` sem corpo de resposta.
- **FR-013**: O sistema DEVE executar a limpeza em cascata (Cascade Delete) de todos os registros e relacionamentos financeiros pertencentes ao `user_id` deletado (incluindo `accounts`, `transactions` e `investments`), impedindo falhas de Foreign Key (FK) ou geração de registros órfãos.
- **FR-014**: O sistema DEVE invalidar imediatamente o acesso subsequente de credenciais e tokens correspondentes a contas excluídas.
- **FR-015**: Toda resposta de erro de validação de payload DEVE estar estritamente aderente ao schema `HTTPValidationError` conforme definido no contrato OpenAPI.

### Key Entities

- **User**: Representa a identidade do titular no sistema Finance Organizer. Atributos essenciais: identificador único (`id` em formato UUID), `email` (único, formato email), `password_hash` (armazenado de forma segura e nunca exposto), `is_active` (booleano indicando status da conta) e `created_at` (carimbo de data/hora no padrão ISO 8601).
- **Token**: Representa o artefato criptográfico de sessão emitido após autenticação bem-sucedida. Composto por `access_token` (string JWT contendo claims de identidade) e `token_type` (padrão "bearer").
- **Account / Carteira**: Entidade financeira vinculada a um `user_id`. Contém saldo, tipo de conta e histórico financeiro. Sujeita a deleção em cascata quando o usuário é excluído.
- **Transaction**: Registro de movimentação financeira (receita ou despesa) associado a uma conta e a um `user_id`. Sujeito a deleção em cascata.
- **Investment**: Registro de custódia de ativos e posições de mercado associadas ao `user_id`. Sujeito a deleção em cascata.
- **HTTPValidationError**: Estrutura padronizada de erro de contrato retornada quando um payload não atende às regras de validação (composta por array `detail` com `loc`, `msg` e `type`).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos cenários de teste BDD definidos para os endpoints de Auth (`register`, `login`, `me` GET e `me` DELETE) devem ser automatizados e executados com sucesso no framework de testes.
- **SC-002**: 100% das respostas de sucesso da API nos testes de Auth devem ser validadas contra os schemas `UserResponse` e `Token` do contrato OpenAPI sem desvios estruturais.
- **SC-003**: 100% dos testes de erro de validação de schema devem comprovar a emissão de código HTTP `422 Unprocessable Entity` com schema aderente a `HTTPValidationError`.
- **SC-004**: Zero dados sensíveis de credenciais (hashes de senha, senhas em texto puro ou chaves secretas de assinatura) devem ser expostos em logs de execução ou payloads de retorno da API.
- **SC-005**: 100% das operações de exclusão de usuário com dados vinculados (`accounts`, `transactions`, `investments`) devem comprovar no pós-teste a ausência completa de registros órfãos no banco de dados e zero ocorrências de erro HTTP 500 por integridade referencial.
- **SC-006**: Todos os cenários da suíte de testes devem ser executáveis de forma independente e concorrente (mínimo de 3 threads paralelas) com taxa de falhas por concorrência ou colisão de dados igual a 0%.

---

## Assumptions

- **Padrão de Dados Sintéticos**: Cada execução de teste gerará seus próprios dados dinâmicos (e-mails com sufixos únicos e senhas aleatórias aderentes às regras) para viabilizar execução paralela em múltiplas threads sem dependência de massa estática pré-carregada.
- **Padrão de Status Code para Conflitos Cadastrais**: Em caso de tentativa de cadastro com e-mail duplicado, a API retorna erro de validação ou conflito (HTTP 422 ou 409), conforme previsto no schema de validação da aplicação.
- **Comportamento de Campos Extras (Mass Assignment)**: O backend está configurado para rejeitar (`422`) ou ignorar atributos adicionais não declarados em `UserCreate`, garantindo que campos sensíveis não sejam injetados.
- **Mecanismo de Desativação de Contas**: O status `is_active` é assumido como `true` por padrão no cadastro; para testar contas desativadas (`is_active = false`), assume-se a existência de controle administrativo ou alteração direta de estado para fins de validação do gate de segurança no login.
- **Conformidade com a Constituição do Repositório**: A automação destes cenários seguirá estritamente a Constituição ratificada em `.specify/memory/constitution.md`, incluindo desacoplamento de payloads externos, geração de dados via Datafaker (`pt-BR`) e ausência de segredos versionados.
