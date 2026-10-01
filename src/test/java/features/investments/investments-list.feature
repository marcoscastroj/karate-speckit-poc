@investments @list
Feature: Gestão de Investimentos - Listagem e Filtros por Classe (GET /api/v1/investments/)

  Background:
    * url baseUrl
    * def investmentsPath = '/api/v1/investments/'
    * def investmentResponseSchema = read('classpath:data/schemas/investments/investment-response-schema.json')
    * def investmentListSchema = read('classpath:data/schemas/investments/investment-list-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path @data_isolation
  Scenario: SCEN-INV-16 - Listagem de investimentos pertencentes unicamente ao usuario autenticado
    * def authUserA = call read('classpath:features/helpers/auth-helper.feature')
    * def authUserB = call read('classpath:features/helpers/auth-helper.feature')

    # Usuario A cria 2 ativos
    Given path investmentsPath
    And header Authorization = authUserA.authHeader
    And request { ticker: 'A1_PETR4', nome: 'Ativo A1', classe: 'ACOES', quantidade: '10.0', preco_medio: '30.00', cotacao_atual: '35.00' }
    When method post
    Then status 201

    Given path investmentsPath
    And header Authorization = authUserA.authHeader
    And request { ticker: 'A2_VALE3', nome: 'Ativo A2', classe: 'ACOES', quantidade: '5.0', preco_medio: '60.00', cotacao_atual: '65.00' }
    When method post
    Then status 201

    # Usuario B cria 3 ativos
    Given path investmentsPath
    And header Authorization = authUserB.authHeader
    And request { ticker: 'B1_BTC', nome: 'Ativo B1', classe: 'CRIPTO', quantidade: '0.01', preco_medio: '100000.00', cotacao_atual: '120000.00' }
    When method post
    Then status 201

    # Usuario A consulta sua lista
    Given path investmentsPath
    And header Authorization = authUserA.authHeader
    When method get
    Then status 200
    And match response == investmentListSchema
    And match response == '#[2]'
    And match each response contains { user_id: '#(authUserA.userId)' }

  @happy_path @filtering
  Scenario: SCEN-INV-17 - Filtrar listagem por todas as classes de investimento
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cadastra posicoes nas 6 classes de InvestmentClass
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'TK_ACOES', nome: 'Acao Teste', classe: 'ACOES', quantidade: '10.0', preco_medio: '20.00', cotacao_atual: '22.00' }
    When method post
    Then status 201

    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'TK_FIIS', nome: 'FII Teste', classe: 'FIIS', quantidade: '5.0', preco_medio: '100.00', cotacao_atual: '105.00' }
    When method post
    Then status 201

    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'TK_CRIPTO', nome: 'Cripto Teste', classe: 'CRIPTO', quantidade: '0.1', preco_medio: '5000.00', cotacao_atual: '6000.00' }
    When method post
    Then status 201

    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'TK_RENDA', nome: 'Renda Fixa Teste', classe: 'RENDA_FIXA', quantidade: '1.0', preco_medio: '1000.00', cotacao_atual: '1050.00' }
    When method post
    Then status 201

    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'TK_ETF', nome: 'ETF Teste', classe: 'ETF', quantidade: '20.0', preco_medio: '50.00', cotacao_atual: '55.00' }
    When method post
    Then status 201

    Given path investmentsPath
    And header Authorization = auth.authHeader
    And request { ticker: 'TK_EMERG', nome: 'Reserva Emergencia', classe: 'RENDA_EMERGENCIAL', quantidade: '1.0', preco_medio: '500.00', cotacao_atual: '500.00' }
    When method post
    Then status 201

    # 1. Filtro ACOES
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And param classe = 'ACOES'
    When method get
    Then status 200
    And match response == investmentListSchema
    And match response == '#[1]'
    And match response[0].classe == 'ACOES'

    # 2. Filtro FIIS
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And param classe = 'FIIS'
    When method get
    Then status 200
    And match response == investmentListSchema
    And match response == '#[1]'
    And match response[0].classe == 'FIIS'

    # 3. Filtro CRIPTO
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And param classe = 'CRIPTO'
    When method get
    Then status 200
    And match response == investmentListSchema
    And match response == '#[1]'
    And match response[0].classe == 'CRIPTO'

    # 4. Filtro RENDA_FIXA
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And param classe = 'RENDA_FIXA'
    When method get
    Then status 200
    And match response == investmentListSchema
    And match response == '#[1]'
    And match response[0].classe == 'RENDA_FIXA'

    # 5. Filtro ETF
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And param classe = 'ETF'
    When method get
    Then status 200
    And match response == investmentListSchema
    And match response == '#[1]'
    And match response[0].classe == 'ETF'

    # 6. Filtro RENDA_EMERGENCIAL
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And param classe = 'RENDA_EMERGENCIAL'
    When method get
    Then status 200
    And match response == investmentListSchema
    And match response == '#[1]'
    And match response[0].classe == 'RENDA_EMERGENCIAL'

  @happy_path @pagination
  Scenario: SCEN-INV-18 - Paginacao de posicoes utilizando skip e limit
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria 5 ativos
    * def tickers = ['TK_PAG_1', 'TK_PAG_2', 'TK_PAG_3', 'TK_PAG_4', 'TK_PAG_5']
    * def createAsset =
    """
    function(t) {
      karate.call('classpath:features/helpers/investment-helper.feature', {
        targetAuthHeader: auth.authHeader,
        targetTicker: t,
        targetNome: 'Ativo ' + t,
        targetClasse: 'ACOES'
      });
    }
    """
    * karate.forEach(tickers, createAsset)

    # Pagina 1: skip=0, limit=2
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And params { skip: 0, limit: 2 }
    When method get
    Then status 200
    And match response == '#[2]'
    * def idPag1_1 = response[0].id
    * def idPag1_2 = response[1].id

    # Pagina 2: skip=2, limit=2
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And params { skip: 2, limit: 2 }
    When method get
    Then status 200
    And match response == '#[2]'
    * def idPag2_1 = response[0].id
    * def idPag2_2 = response[1].id
    * match idPag2_1 != idPag1_1
    * match idPag2_1 != idPag1_2

    # Pagina 3: skip=4, limit=2
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And params { skip: 4, limit: 2 }
    When method get
    Then status 200
    And match response == '#[1]'

  @negative @contract
  Scenario: SCEN-INV-19 - Erro ao passar valor desconhecido no parametro classe
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And param classe = 'POUPANCA'
    When method get
    Then status 422

  @negative @boundary
  Scenario: SCEN-INV-20 - Violacao de limites de paginacao
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Skip negativo
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And params { skip: -1, limit: 10 }
    When method get
    Then status 422

    # Limit zero
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And params { skip: 0, limit: 0 }
    When method get
    Then status 422

    # Limit superior ao maximo
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And params { skip: 0, limit: 101 }
    When method get
    Then status 422

    # Limit negativo
    Given path investmentsPath
    And header Authorization = auth.authHeader
    And params { skip: 0, limit: -5 }
    When method get
    Then status 422

  @security @authentication
  Scenario: SCEN-INV-21 - Tentativa de listar investimentos sem credenciais
    Given path investmentsPath
    When method get
    Then status 401
