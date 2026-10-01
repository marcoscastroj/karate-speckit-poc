@ignore
Feature: Helper Reutilizavel - Cadastro de Posicao de Investimento

  Background:
    * url baseUrl
    * def investmentsPath = '/api/v1/investments/'

  Scenario: Criar posicao de investimento para testes
    # 1. Definir parametros com fallbacks dinamicos
    * def uniqueId = java.util.UUID.randomUUID().toString().substring(0, 4).toUpperCase()
    * def defaultTicker = 'TK' + uniqueId
    * def itemTicker = karate.get('targetTicker', defaultTicker)
    * def itemNome = karate.get('targetNome', 'Ativo Teste ' + itemTicker)
    * def itemClasse = karate.get('targetClasse', 'ACOES')
    * def itemQuantidade = karate.get('targetQuantidade', '10.0')
    * def itemPrecoMedio = karate.get('targetPrecoMedio', '50.00')
    * def itemCotacaoAtual = karate.get('targetCotacaoAtual', '60.00')

    # 2. Obter ou gerar token de autorizacao
    * def tokenHeader = karate.get('targetAuthHeader', null)
    * def isBearer = tokenHeader && ('' + tokenHeader).startsWith('Bearer ')
    * def finalAuthHeader = isBearer ? tokenHeader : karate.call('classpath:features/helpers/auth-helper.feature').authHeader

    # 3. Criar a posicao via POST
    Given path investmentsPath
    And header Authorization = finalAuthHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = itemTicker
    * set payload.nome = itemNome
    * set payload.classe = itemClasse
    * set payload.quantidade = itemQuantidade
    * set payload.preco_medio = itemPrecoMedio
    * set payload.cotacao_atual = itemCotacaoAtual
    And request payload
    When method post
    Then status 201
    * def investmentId = response.id
    * def investmentResponse = response
    * def createdTicker = response.ticker
    * def totalInvestido = response.total_investido
    * def patrimonioAtual = response.patrimonio_atual
    * def lucroPrejuizo = response.lucro_prejuizo_absoluto
    * def rentabilidade = response.rentabilidade_percentual
    * def authHeaderUsed = finalAuthHeader
