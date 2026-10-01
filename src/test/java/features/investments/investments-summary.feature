@investments @summary
Feature: Gestão de Investimentos - Métricas Consolidadas do Portfólio (GET /api/v1/investments/summary)

  Background:
    * url baseUrl
    * def summaryPath = '/api/v1/investments/summary'
    * def investmentsPath = '/api/v1/investments/'
    * def portfolioSummarySchema = read('classpath:data/schemas/investments/portfolio-summary-schema.json')
    * def classAllocationSchema = read('classpath:data/schemas/investments/class-allocation-schema.json')
    * def sumPerc = function(items) { var s = 0.0; for (var i = 0; i < items.length; i++) s += parseFloat(items[i].percentual_carteira); return s; }
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-INV-11 - Obtenção de metricas consolidadas de usuario com carteira vazia
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path summaryPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == portfolioSummarySchema
    And match response.patrimonio_total == '0.00'
    And match response.total_investido == '0.00'
    And match response.lucro_prejuizo_absoluto == '0.00'
    And match response.rentabilidade_percentual == '0.00'
    And match response.alocacao_por_classe == '#[0]'

  @happy_path @aggregation
  Scenario: SCEN-INV-12 - Consolidacao exata de patrimonio e alocacao por classe
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 1. Cria ativo em ACOES
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'ITUB4', nome: 'Itau Unibanco PN', classe: 'ACOES', quantidade: '100.0', preco_medio: '30.00', cotacao_atual: '40.00' }
    When method post
    Then status 201

    # 2. Cria ativo em FIIS
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'KNRI11', nome: 'Kinea Renda Imobiliaria', classe: 'FIIS', quantidade: '20.0', preco_medio: '150.00', cotacao_atual: '150.00' }
    When method post
    Then status 201

    # 3. Cria ativo em RENDA_FIXA
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'CDB01', nome: 'CDB Pos 100 CDI', classe: 'RENDA_FIXA', quantidade: '1.0', preco_medio: '3000.00', cotacao_atual: '3000.00' }
    When method post
    Then status 201

    # 4. Consulta resumo consolidado
    Given path summaryPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == portfolioSummarySchema
    * assert Math.abs(parseFloat(response.total_investido) - 9000.00) < 0.05
    * assert Math.abs(parseFloat(response.patrimonio_total) - 10000.00) < 0.05
    * assert Math.abs(parseFloat(response.lucro_prejuizo_absoluto) - 1000.00) < 0.05
    * assert Math.abs(parseFloat(response.rentabilidade_percentual) - 11.11) < 0.05
    And match response.alocacao_por_classe == '#[3]'

  @mathematical @invariant
  Scenario: SCEN-INV-13 - A soma das fatias de alocacao por classe deve totalizar 100%
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria ativos em 3 classes distintas
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'VALE3', nome: 'Vale SA', classe: 'ACOES', quantidade: '10.0', preco_medio: '50.00', cotacao_atual: '60.00' }
    When method post
    Then status 201

    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'HGLG11', nome: 'CSHG Logistica', classe: 'FIIS', quantidade: '10.0', preco_medio: '100.00', cotacao_atual: '120.00' }
    When method post
    Then status 201

    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'BTC', nome: 'Bitcoin', classe: 'CRIPTO', quantidade: '0.01', preco_medio: '100000.00', cotacao_atual: '150000.00' }
    When method post
    Then status 201

    # Valida soma das fatias de percentual
    Given path summaryPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == portfolioSummarySchema
    * def totalSoma = sumPerc(response.alocacao_por_classe)
    * assert Math.abs(totalSoma - 100.0) <= 0.05

  @security @multi_tenancy
  Scenario: SCEN-INV-14 - Ativos de outros usuarios nao podem interferir no resumo consolidado
    # Provisiona Usuario A e Usuario B
    * def authUserA = call read('classpath:features/helpers/auth-helper.feature')
    * def authUserB = call read('classpath:features/helpers/auth-helper.feature')

    # Usuario A cria ativo de 50.000 em ACOES
    Given path investmentsPath
    And header Authorization = authUserA.authHeader
    And request { ticker: 'PETR4', nome: 'Petrobras', classe: 'ACOES', quantidade: '1000.0', preco_medio: '50.00', cotacao_atual: '50.00' }
    When method post
    Then status 201

    # Usuario B cria ativo de 2.000 em CRIPTO
    Given path investmentsPath
    And header Authorization = authUserB.authHeader
    And request { ticker: 'ETH', nome: 'Ethereum', classe: 'CRIPTO', quantidade: '1.0', preco_medio: '2000.00', cotacao_atual: '2000.00' }
    When method post
    Then status 201

    # Usuario B consulta resumo: deve ver apenas seus 2000.00 em CRIPTO
    Given path summaryPath
    And header Authorization = authUserB.authHeader
    When method get
    Then status 200
    And match response == portfolioSummarySchema
    * assert Math.abs(parseFloat(response.patrimonio_total) - 2000.00) < 0.01
    * assert Math.abs(parseFloat(response.total_investido) - 2000.00) < 0.01
    And match response.alocacao_por_classe == '#[1]'
    And match response.alocacao_por_classe[0].classe == 'CRIPTO'
    * assert Math.abs(parseFloat(response.alocacao_por_classe[0].percentual_carteira) - 100.0) <= 0.05

  @security @authentication
  Scenario: SCEN-INV-15 - Consulta de metricas consolidadas sem cabecalho Authorization
    Given path summaryPath
    When method get
    Then status 401
