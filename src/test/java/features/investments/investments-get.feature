@investments @detail
Feature: Gestão de Investimentos - Detalhe de Posição por ID (GET /api/v1/investments/{investment_id})

  Background:
    * url baseUrl
    * def investmentsPath = '/api/v1/investments/'
    * def investmentResponseSchema = read('classpath:data/schemas/investments/investment-response-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-INV-22 - Obtenção com sucesso de investimento existente proprio
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def helper = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader, targetTicker: 'TK_GET1' })
    * def targetId = helper.investmentId

    Given path investmentsPath, targetId
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == investmentResponseSchema
    And match response.id == targetId
    And match response.user_id == auth.userId
    And match response.ticker == helper.createdTicker

  @security @idor
  Scenario: SCEN-INV-23 - Usuario A tentando consultar investimento criado pelo usuario B
    # 1. Usuario B provisiona e cria seu investimento
    * def authUserB = call read('classpath:features/helpers/auth-helper.feature')
    * def helperB = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: authUserB.authHeader, targetTicker: 'TK_B_IDOR' })
    * def assetIdB = helperB.investmentId

    # 2. Usuario A tenta consultar o ativo do Usuario B
    * def authUserA = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, assetIdB
    And header Authorization = authUserA.authHeader
    When method get
    Then assert responseStatus == 404 || responseStatus == 403

  @negative @not_found
  Scenario: SCEN-INV-24 - Consulta de investment_id inexistente no sistema
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, '00000000-0000-0000-0000-000000000000'
    And header Authorization = auth.authHeader
    When method get
    Then status 404

  @negative @contract
  Scenario Outline: SCEN-INV-25 - Rejeicao de ID com formato invalido (<formato_id>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, '<formato_id>'
    And header Authorization = auth.authHeader
    When method get
    Then status 422

    Examples:
      | formato_id      |
      | 12345           |
      | id-invalido-abc |
      | true            |

  @security @authentication
  Scenario: SCEN-INV-26 - Consulta de detalhes de investimento sem token
    Given path investmentsPath, '11111111-1111-1111-1111-111111111111'
    When method get
    Then status 401
