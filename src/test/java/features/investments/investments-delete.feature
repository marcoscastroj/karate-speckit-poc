@investments @delete
Feature: Gestão de Investimentos - Exclusão de Custódia (DELETE /api/v1/investments/{investment_id})

  Background:
    * url baseUrl
    * def investmentsPath = '/api/v1/investments/'
    * def summaryPath = '/api/v1/investments/summary'
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-INV-35 - Exclusão com sucesso de investimento proprio
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def helper = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader })
    * def assetId = helper.investmentId

    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    When method delete
    Then status 204

  @happy_path @persistence
  Scenario: SCEN-INV-36 - Consulta do ativo apos exclusão confirma remocao permanente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def helper = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader })
    * def assetId = helper.investmentId

    # 1. Exclui o ativo
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    When method delete
    Then status 204

    # 2. Tenta consultar via GET
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    When method get
    Then status 404

  @happy_path @summary_impact
  Scenario: SCEN-INV-37 - Eliminação do impacto financeiro do ativo no resumo consolidado
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria Ativo 1 (patrimonio = 3000.00)
    * def h1 = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader, targetTicker: 'TK_DEL_1', targetQuantidade: '10.0', targetPrecoMedio: '300.00', targetCotacaoAtual: '300.00' })
    
    # Cria Ativo 2 (patrimonio = 2000.00)
    * def h2 = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader, targetTicker: 'TK_DEL_2', targetQuantidade: '10.0', targetPrecoMedio: '200.00', targetCotacaoAtual: '200.00' })
    * def assetId2 = h2.investmentId

    # Verifica resumo inicial: 5000.00
    Given path summaryPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    * assert Math.abs(parseFloat(response.patrimonio_total) - 5000.00) < 0.01

    # Exclui Ativo 2
    Given path investmentsPath, assetId2
    And header Authorization = auth.authHeader
    When method delete
    Then status 204

    # Verifica resumo apos exclusão: deve ser exatamente 3000.00
    Given path summaryPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    * assert Math.abs(parseFloat(response.patrimonio_total) - 3000.00) < 0.01

  @security @idor
  Scenario: SCEN-INV-38 - Usuario A tentando excluir investimento pertencente ao usuario B
    # Usuario B cria seu investimento
    * def authUserB = call read('classpath:features/helpers/auth-helper.feature')
    * def helperB = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: authUserB.authHeader, targetTicker: 'TK_IDOR_DEL' })
    * def assetIdB = helperB.investmentId

    # Usuario A tenta excluir o ativo do Usuario B
    * def authUserA = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, assetIdB
    And header Authorization = authUserA.authHeader
    When method delete
    Then assert responseStatus == 404 || responseStatus == 403

    # Usuario B confirma que seu ativo ainda existe
    Given path investmentsPath, assetIdB
    And header Authorization = authUserB.authHeader
    When method get
    Then status 200

  @negative @not_found
  Scenario: SCEN-INV-39 - Tentativa de exclusão de ID inexistente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, '00000000-0000-0000-0000-000000000000'
    And header Authorization = auth.authHeader
    When method delete
    Then status 404

  @negative @contract
  Scenario: SCEN-INV-40 - Tentativa de exclusão com ID malformado
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, 'invalido'
    And header Authorization = auth.authHeader
    When method delete
    Then status 422

  @security @authentication
  Scenario: SCEN-INV-41 - Tentativa de exclusão sem cabecalho Authorization
    Given path investmentsPath, '11111111-1111-1111-1111-111111111111'
    When method delete
    Then status 401
