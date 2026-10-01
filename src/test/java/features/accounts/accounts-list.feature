@accounts @list
Feature: User Story 2 - Listagem e Paginacao de Contas (GET /api/v1/accounts/)
  Como um usuario autenticado na plataforma Finance Organizer
  Quero consultar a lista das minhas contas com suporte a paginacao (skip e limit)
  Para visualizar todas as minhas carteiras cadastradas com seus respectivos saldos de forma rapida e segura

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def accountResponseSchema = read('classpath:data/schemas/accounts/account-response-schema.json')
    * def accountListSchema = '#[] accountResponseSchema'
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-ACC-10 - Listagem padrao de contas do usuario logado
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria 2 contas para o usuario
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Corrente' }
    When method post
    Then status 201

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Poupanca' }
    When method post
    Then status 201

    # Consulta a lista de contas
    Given path accountsPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == accountListSchema
    And match karate.sizeOf(response) == 2
    And match each response[*].user_id == auth.userId

  @happy_path @empty_state
  Scenario: SCEN-ACC-11 - Listagem de contas para usuario sem registros
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == []
    And match karate.sizeOf(response) == 0

  @security @multi_tenant
  Scenario: SCEN-ACC-12 - Isolamento de dados entre usuarios distintos
    # Provisiona dois usuarios independentes
    * def authA = call read('classpath:features/helpers/auth-helper.feature')
    * def authB = call read('classpath:features/helpers/auth-helper.feature')

    # Usuario A cria 2 contas
    Given path accountsPath
    And header Authorization = authA.authHeader
    And request { apelido: 'Conta A1' }
    When method post
    Then status 201

    Given path accountsPath
    And header Authorization = authA.authHeader
    And request { apelido: 'Conta A2' }
    When method post
    Then status 201

    # Usuario B cria 1 conta
    Given path accountsPath
    And header Authorization = authB.authHeader
    And request { apelido: 'Conta B1' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    # Usuario A consulta suas contas
    Given path accountsPath
    And header Authorization = authA.authHeader
    When method get
    Then status 200
    And match response == accountListSchema
    And match karate.sizeOf(response) == 2
    And match each response[*].user_id == authA.userId
    # Assegura que nenhuma conta do Usuario B vazou para o Usuario A
    And match response[*].id !contains accountB_Id

  @pagination @happy_path
  Scenario: SCEN-ACC-13 - Paginacao customizada com skip e limit
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria 5 contas em sequencia
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta 1' }
    When method post
    Then status 201

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta 2' }
    When method post
    Then status 201

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta 3' }
    When method post
    Then status 201

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta 4' }
    When method post
    Then status 201

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta 5' }
    When method post
    Then status 201

    # Consulta com skip=2 e limit=2
    Given path accountsPath
    And header Authorization = auth.authHeader
    And params { skip: 2, limit: 2 }
    When method get
    Then status 200
    And match response == accountListSchema
    And match karate.sizeOf(response) == 2

  @pagination @boundaries
  Scenario: SCEN-ACC-14 - Consulta com skip superior ao total de contas existentes
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria 2 contas
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Alpha' }
    When method post
    Then status 201

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Beta' }
    When method post
    Then status 201

    # Consulta com skip=10 e limit=10
    Given path accountsPath
    And header Authorization = auth.authHeader
    And params { skip: 10, limit: 10 }
    When method get
    Then status 200
    And match response == []
    And match karate.sizeOf(response) == 0

  @validation @negative
  Scenario Outline: SCEN-ACC-15 - Validacao de erro para query params de paginacao invalidos (<parametro>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    And params <query_params>
    When method get
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

    Examples:
      | parametro     | query_params              |
      | skip texto    | { skip: 'invalido' }      |
      | limit texto   | { limit: 'nao_numerico' } |
      | skip booleano | { skip: true }            |

  @security @negative
  Scenario Outline: SCEN-ACC-16 - Rejeicao de listagem de contas sem autenticacao (<condicao_auth>)
    Given path accountsPath
    And header Authorization = '<header_val>'
    When method get
    Then status 401
    And match response.id == '#notpresent'

    Examples:
      | condicao_auth       | header_val              |
      | cabeçalho ausente   |                         |
      | token inválido      | Bearer token_falso_1234 |
      | esquema não bearer  | Basic dXNlcjpwYXNz      |
