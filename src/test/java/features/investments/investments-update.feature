@investments @update
Feature: Gestão de Investimentos - Atualização de Ativos e Recálculo Dinâmico (PUT /api/v1/investments/{investment_id})

  Background:
    * url baseUrl
    * def investmentsPath = '/api/v1/investments/'
    * def summaryPath = '/api/v1/investments/summary'
    * def investmentResponseSchema = read('classpath:data/schemas/investments/investment-response-schema.json')
    * def makeString = function(len) { var s = ''; for (var i = 0; i < len; i++) s += 'X'; return s; }
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-INV-27 - Atualização de cotação atual gerando novo patrimônio e rentabilidade
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def helper = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader, targetQuantidade: '50.0', targetPrecoMedio: '20.00', targetCotacaoAtual: '20.00' })
    * def assetId = helper.investmentId

    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request { cotacao_atual: '30.00' }
    When method put
    Then status 200
    And match response == investmentResponseSchema
    * assert Math.abs(parseFloat(response.total_investido) - 1000.00) < 0.01
    * assert Math.abs(parseFloat(response.patrimonio_atual) - 1500.00) < 0.01
    * assert Math.abs(parseFloat(response.lucro_prejuizo_absoluto) - 500.00) < 0.01
    * assert Math.abs(parseFloat(response.rentabilidade_percentual) - 50.00) < 0.05

  @happy_path
  Scenario: SCEN-INV-28 - Atualização de aporte adicional ajustando quantidade e preco medio
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def helper = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader, targetQuantidade: '50.0', targetPrecoMedio: '20.00', targetCotacaoAtual: '20.00' })
    * def assetId = helper.investmentId

    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request { quantidade: '100.0', preco_medio: '25.00' }
    When method put
    Then status 200
    And match response == investmentResponseSchema
    * assert Math.abs(parseFloat(response.total_investido) - 2500.00) < 0.01

  @happy_path @summary_propagation
  Scenario: SCEN-INV-29 - Reflexo imediato do PUT na consolidação de /investments/summary
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def helper = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader, targetQuantidade: '10.0', targetPrecoMedio: '100.00', targetCotacaoAtual: '100.00' })
    * def assetId = helper.investmentId

    # 1. Verifica summary inicial (patrimonio = 1000.00)
    Given path summaryPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    * assert Math.abs(parseFloat(response.patrimonio_total) - 1000.00) < 0.01

    # 2. Executa PUT alterando cotacao_atual para 150.00 (novo patrimonio do ativo = 1500.00)
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request { cotacao_atual: '150.00' }
    When method put
    Then status 200

    # 3. Verifica se summary reflete 1500.00
    Given path summaryPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    * assert Math.abs(parseFloat(response.patrimonio_total) - 1500.00) < 0.01

  @negative @boundary
  Scenario: SCEN-INV-30 - Rejeição de dados invalidos no PUT
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def helper = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: auth.authHeader })
    * def assetId = helper.investmentId

    # 1. Quantidade zero
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request { quantidade: 0.0 }
    When method put
    Then status 422

    # 2. Quantidade negativa
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request { quantidade: -10.0 }
    When method put
    Then status 422

    # 3. Preco medio negativo
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request { preco_medio: -5.00 }
    When method put
    Then status 422

    # 4. Cotacao atual negativa
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request { cotacao_atual: -0.50 }
    When method put
    Then status 422

    # 5. Ticker vazio
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request { ticker: '' }
    When method put
    Then status 422

    # 6. Ticker acima de 20 chars
    * def longTickerPayload = ({ ticker: makeString(21) })
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request longTickerPayload
    When method put
    Then status 422

    # 7. Nome acima de 255 chars
    * def longNomePayload = ({ nome: makeString(256) })
    Given path investmentsPath, assetId
    And header Authorization = auth.authHeader
    And request longNomePayload
    When method put
    Then status 422

  @security @idor
  Scenario: SCEN-INV-31 - Tentativa de alterar investimento pertencente a outro usuario
    * def authUserB = call read('classpath:features/helpers/auth-helper.feature')
    * def helperB = karate.call('classpath:features/helpers/investment-helper.feature', { targetAuthHeader: authUserB.authHeader })
    * def assetIdB = helperB.investmentId

    * def authUserA = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, assetIdB
    And header Authorization = authUserA.authHeader
    And request { cotacao_atual: '9999.00' }
    When method put
    Then assert responseStatus == 404 || responseStatus == 403

    # Verifica integridade do ativo do Usuario B
    Given path investmentsPath, assetIdB
    And header Authorization = authUserB.authHeader
    When method get
    Then status 200
    And match response.cotacao_atual != '9999.0000'

  @negative @not_found
  Scenario: SCEN-INV-32 - Atualização de investment_id inexistente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, '00000000-0000-0000-0000-000000000000'
    And header Authorization = auth.authHeader
    And request { cotacao_atual: '50.00' }
    When method put
    Then status 404

  @negative @contract
  Scenario: SCEN-INV-33 - Atualização com ID nao-UUID
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath, 'abc-123'
    And header Authorization = auth.authHeader
    And request { cotacao_atual: '50.00' }
    When method put
    Then status 422

  @security @authentication
  Scenario: SCEN-INV-34 - Tentativa de atualização sem credenciais validas
    Given path investmentsPath, '11111111-1111-1111-1111-111111111111'
    And request { cotacao_atual: '50.00' }
    When method put
    Then status 401
