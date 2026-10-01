@accounts @detail
Feature: User Story 3 - Consulta de Detalhes e Saldo Dinamico (GET /api/v1/accounts/{account_id})
  Como um usuario da plataforma Finance Organizer
  Quero consultar os detalhes de uma conta especifica pelo seu identificador account_id
  Para inspecionar o saldo consolidado atualizado e os dados cadastrais da carteira

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def transactionsPath = '/api/v1/transactions/'
    * def accountResponseSchema = read('classpath:data/schemas/accounts/account-response-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-ACC-17 - Consulta bem-sucedida de conta por ID valido
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria conta previa
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Carteira Principal' }
    When method post
    Then status 201
    * def accountId = response.id

    # Consulta detalhes da conta criada
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == accountResponseSchema
    And match response.id == accountId
    And match response.apelido == 'Carteira Principal'
    And match response.user_id == auth.userId
    And match ['0', '0.00'] contains response.saldo_calculado

  @calculation @integration
  Scenario: SCEN-ACC-18 - Calculo dinamico de saldo (receitas menos despesas)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 1. Cria conta nova com saldo zero
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Carteira Balanco' }
    When method post
    Then status 201
    * def accountId = response.id
    * match response.saldo_calculado == '0.00'

    # 2. Registra Receita 1: 1500.50
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And request
      """
      {
        "valor": 1500.50,
        "tipo": "RECEITA",
        "data": "2026-09-28",
        "descricao": "Salario Mensal",
        "conta_id": "#(accountId)",
        "recorrencia": "UNICA"
      }
      """
    When method post
    Then status 201

    # 3. Registra Receita 2: 500.00
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And request
      """
      {
        "valor": 500.00,
        "tipo": "RECEITA",
        "data": "2026-09-28",
        "descricao": "Freelance Design",
        "conta_id": "#(accountId)",
        "recorrencia": "UNICA"
      }
      """
    When method post
    Then status 201

    # 4. Registra Despesa 1: 350.25
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And request
      """
      {
        "valor": 350.25,
        "tipo": "DESPESA",
        "data": "2026-09-28",
        "descricao": "Compras Mercado",
        "conta_id": "#(accountId)",
        "recorrencia": "UNICA"
      }
      """
    When method post
    Then status 201

    # 5. Consulta conta e valida calculo consolidado: 1500.50 + 500.00 - 350.25 = 1650.25
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == accountResponseSchema
    And match response.saldo_calculado == '1650.25'
    And match response.saldo_calculado == '#regex ^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d*$'

  @negative @not_found
  Scenario: SCEN-ACC-19 - Consulta de conta com UUID inexistente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def randomUuid = java.util.UUID.randomUUID().toString()

    Given path accountsPath, randomUuid
    And header Authorization = auth.authHeader
    When method get
    Then status 404

  @security @idor
  Scenario: SCEN-ACC-20 - Tentativa do Usuario A acessar a conta do Usuario B (IDOR)
    * def authB = call read('classpath:features/helpers/auth-helper.feature')
    * def authA = call read('classpath:features/helpers/auth-helper.feature')

    # Usuario B cria conta
    Given path accountsPath
    And header Authorization = authB.authHeader
    And request { apelido: 'Conta Segredo B' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    # Usuario A tenta consultar conta do Usuario B
    Given path accountsPath, accountB_Id
    And header Authorization = authA.authHeader
    When method get
    Then status 404
    And match response.apelido == '#notpresent'

  @validation @negative
  Scenario: SCEN-ACC-21 - Consulta com account_id fora do formato UUID
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath, 'id-invalido-12345'
    And header Authorization = auth.authHeader
    When method get
    Then status 422
    And match response == validationErrorSchema

  @security @negative
  Scenario Outline: SCEN-ACC-22 - Consulta individual de conta sem autenticacao (<condicao_auth>)
    * def fakeId = '00000000-0000-0000-0000-000000000000'

    Given path accountsPath, fakeId
    And header Authorization = '<header_val>'
    When method get
    Then status 401
    And match response.id == '#notpresent'

    Examples:
      | condicao_auth       | header_val              |
      | cabeçalho ausente   |                         |
      | token inválido      | Bearer token_falso_1234 |
      | esquema não bearer  | Basic dXNlcjpwYXNz      |
