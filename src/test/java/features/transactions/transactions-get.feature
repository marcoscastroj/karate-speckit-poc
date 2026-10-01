@transactions @detail
Feature: User Story 4 - Consulta de Detalhes de Transacao por ID (GET /api/v1/transactions/{transaction_id})
  Como um usuario autenticado
  Quero consultar os dados detalhados de uma transacao pelo seu identificador transaction_id
  Para inspecionar metadados, valores e conferir a conta associada a movimentacao

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def transactionsPath = '/api/v1/transactions/'
    * def transactionResponseSchema = read('classpath:data/schemas/transactions/transaction-response-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-TX-25 - Consulta de transacao por ID existente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    # Cria conta
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Get Detalhe' }
    When method post
    Then status 201
    * def accountId = response.id

    # Cria transacao
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.conta_id = accountId
    * set payload.data = today
    * set payload.descricao = 'Aluguel'
    * set payload.valor = 1500.00
    * set payload.tipo = 'DESPESA'
    And request payload
    When method post
    Then status 201
    * def txId = response.id

    # Consulta por ID
    Given path transactionsPath, txId
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == transactionResponseSchema
    And match response.id == txId
    And match response.descricao == 'Aluguel'
    And match response.tipo == 'DESPESA'
    And match response.conta_id == accountId
    And match response.user_id == auth.userId

  @security @idor
  Scenario: SCEN-TX-26 - Bloqueio de acesso a transacao de terceiro (IDOR)
    # 1. Usuario B cria conta e transacao confidencial
    * def authB = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = authB.authHeader
    And request { apelido: 'Conta Secreta B' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    Given path transactionsPath
    And header Authorization = authB.authHeader
    * def payloadB = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payloadB.conta_id = accountB_Id
    * set payloadB.data = today
    * set payloadB.descricao = 'Salario Confidencial B'
    And request payloadB
    When method post
    Then status 201
    * def txB_Id = response.id

    # 2. Usuario A tenta consultar a transacao de B
    * def authA = call read('classpath:features/helpers/auth-helper.feature')

    Given path transactionsPath, txB_Id
    And header Authorization = authA.authHeader
    When method get
    Then match [403, 404] contains responseStatus
    And match response.descricao == '#notpresent'

  @validation @negative
  Scenario Outline: SCEN-TX-27 - Consulta de transacao com ID invalido ou inexistente (<motivo>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path transactionsPath, '<id_informado>'
    And header Authorization = auth.authHeader
    When method get
    Then status <status_esperado>

    Examples:
      | motivo              | id_informado                          | status_esperado |
      | UUID não cadastrado | 00000000-0000-0000-0000-000000000000 | 404             |
      | formato não-UUID    | id-invalido-1234                      | 422             |

  @security @negative
  Scenario: SCEN-TX-28 - Consulta por ID sem token de sessao
    * def randomUuid = java.util.UUID.randomUUID().toString()
    Given path transactionsPath, randomUuid
    When method get
    Then status 401
