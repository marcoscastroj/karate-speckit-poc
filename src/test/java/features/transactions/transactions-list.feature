@transactions @list
Feature: User Story 2 - Listagem e Filtros Combinados de Transacoes (GET /api/v1/transactions/)
  Como um usuario autenticado
  Quero consultar a lista das minhas transacoes financeiras aplicando filtros por mes, ano, conta e status, alem de paginacao
  Para que eu possa auditar minhas movimentacoes e inspecionar lancamentos especificos de determinado periodo

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def transactionsPath = '/api/v1/transactions/'
    * def transactionResponseSchema = read('classpath:data/schemas/transactions/transaction-response-schema.json')
    * def transactionListSchema = read('classpath:data/schemas/transactions/transaction-list-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-TX-12 - Listagem padrao de transacoes do usuario (sem filtros)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    # Cria conta
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Listagem' }
    When method post
    Then status 201
    * def accountId = response.id

    # Cria 3 transacoes
    * def txTemplate = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txTemplate.conta_id = accountId
    * txTemplate.data = today

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * set txTemplate.descricao = 'Transacao 1'
    * set txTemplate.valor = 100.00
    * set txTemplate.tipo = 'RECEITA'
    And request txTemplate
    When method post
    Then status 201

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * set txTemplate.descricao = 'Transacao 2'
    * set txTemplate.valor = 50.00
    * set txTemplate.tipo = 'DESPESA'
    And request txTemplate
    When method post
    Then status 201

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * set txTemplate.descricao = 'Transacao 3'
    * set txTemplate.valor = 250.00
    * set txTemplate.tipo = 'RECEITA'
    And request txTemplate
    When method post
    Then status 201

    # Consulta listagem sem filtros
    Given path transactionsPath
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == transactionListSchema
    And match response == '#[3]'
    And match each response == transactionResponseSchema
    And match each response[*].user_id == auth.userId

  @security @multi_tenant
  Scenario: SCEN-TX-13 - Segregacao de transacoes entre usuarios distintos (Multi-tenancy)
    # 1. Usuario A cria conta e 2 transacoes
    * def authA = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = authA.authHeader
    And request { apelido: 'Conta Usuario A' }
    When method post
    Then status 201
    * def accountA_Id = response.id

    * def txA = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txA.conta_id = accountA_Id
    * txA.data = today

    Given path transactionsPath
    And header Authorization = authA.authHeader
    * set txA.descricao = 'Tx A1'
    And request txA
    When method post
    Then status 201
    * def txA1_Id = response.id

    Given path transactionsPath
    And header Authorization = authA.authHeader
    * set txA.descricao = 'Tx A2'
    And request txA
    When method post
    Then status 201
    * def txA2_Id = response.id

    # 2. Usuario B cria conta e 1 transacao
    * def authB = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = authB.authHeader
    And request { apelido: 'Conta Usuario B' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    * def txB = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txB.conta_id = accountB_Id
    * txB.data = today
    * txB.descricao = 'Tx B1 Secreta'

    Given path transactionsPath
    And header Authorization = authB.authHeader
    And request txB
    When method post
    Then status 201
    * def txB1_Id = response.id

    # 3. Usuario A lista transacoes: deve ver apenas as suas
    Given path transactionsPath
    And header Authorization = authA.authHeader
    When method get
    Then status 200
    And match response == '#[2]'
    And match each response[*].user_id == authA.userId
    * def returnedIds = karate.map(response, function(x){ return x.id })
    And match returnedIds contains txA1_Id
    And match returnedIds contains txA2_Id
    And match returnedIds !contains txB1_Id

  @filtering @happy_path
  Scenario: SCEN-TX-14 - Filtro de transacoes por mes e ano
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def now = java.time.LocalDate.now()
    * def currentMonth = now.getMonthValue()
    * def currentYear = now.getYear()
    * def dateThisMonth = now.toString()
    * def otherDate = now.minusMonths(2).toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Filtro Data' }
    When method post
    Then status 201
    * def accountId = response.id

    # Tx 1: mes corrente
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def tx1 = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * tx1.conta_id = accountId
    * tx1.data = dateThisMonth
    * tx1.descricao = 'Tx Mes Corrente'
    And request tx1
    When method post
    Then status 201

    # Tx 2: dois meses atras
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def tx2 = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * tx2.conta_id = accountId
    * tx2.data = otherDate
    * tx2.descricao = 'Tx Outro Mes'
    And request tx2
    When method post
    Then status 201

    # Consulta filtrando pelo mes e ano correntes
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And param mes = currentMonth
    And param ano = currentYear
    When method get
    Then status 200
    And match response == '#[1]'
    And match response[0].descricao == 'Tx Mes Corrente'
    And match response[0].data == dateThisMonth

  @filtering @happy_path
  Scenario: SCEN-TX-15 - Filtro de transacoes por conta especifica (conta_id)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    # Conta A
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta A Filtro' }
    When method post
    Then status 201
    * def accountA_Id = response.id

    # Conta B
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta B Filtro' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    # 2 transacoes na Conta A
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txA = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txA.conta_id = accountA_Id
    * txA.data = today
    * txA.descricao = 'Tx Conta A 1'
    And request txA
    When method post
    Then status 201

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * set txA.descricao = 'Tx Conta A 2'
    And request txA
    When method post
    Then status 201

    # 1 transacao na Conta B
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txB = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txB.conta_id = accountB_Id
    * txB.data = today
    * txB.descricao = 'Tx Conta B 1'
    And request txB
    When method post
    Then status 201

    # Filtra por Conta A
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And param conta_id = accountA_Id
    When method get
    Then status 200
    And match response == '#[2]'
    And match each response[*].conta_id == accountA_Id

  @filtering @happy_path
  Scenario: SCEN-TX-16 - Filtro de transacoes por status (EFETIVADA vs AGENDADA)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()
    * def futureDate = java.time.LocalDate.now().plusDays(5).toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Status Filtro' }
    When method post
    Then status 201
    * def accountId = response.id

    # 1. Transacao EFETIVADA (data hoje)
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txEfetivada = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txEfetivada.conta_id = accountId
    * txEfetivada.data = today
    * txEfetivada.descricao = 'Tx Efetivada'
    And request txEfetivada
    When method post
    Then status 201
    * match response.status == 'EFETIVADA'

    # 2. Transacao AGENDADA (data futura)
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txAgendada = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txAgendada.conta_id = accountId
    * txAgendada.data = futureDate
    * txAgendada.descricao = 'Tx Agendada'
    And request txAgendada
    When method post
    Then status 201
    * match response.status == 'AGENDADA'

    # Filtra por EFETIVADA
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And param status = 'EFETIVADA'
    When method get
    Then status 200
    And match response == '#[1]'
    And match response[0].status == 'EFETIVADA'

    # Filtra por AGENDADA
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And param status = 'AGENDADA'
    When method get
    Then status 200
    And match response == '#[1]'
    And match response[0].status == 'AGENDADA'

  @filtering @pagination @integration
  Scenario: SCEN-TX-17 - Combinacao de filtros (mes, ano, conta, status) e paginacao (skip, limit)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def now = java.time.LocalDate.now()
    * def currentMonth = now.getMonthValue()
    * def currentYear = now.getYear()
    * def today = now.toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Multi Filtros' }
    When method post
    Then status 201
    * def accountId = response.id

    # Cria transacao que atende a todos os criterios
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txMatch = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txMatch.conta_id = accountId
    * txMatch.data = today
    * txMatch.descricao = 'Tx Match Total'
    And request txMatch
    When method post
    Then status 201

    # Executa consulta com combinacao de todos os filtros
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And param mes = currentMonth
    And param ano = currentYear
    And param conta_id = accountId
    And param status = 'EFETIVADA'
    And param skip = 0
    And param limit = 10
    When method get
    Then status 200
    And match response == '#[1]'
    And match response[0].conta_id == accountId
    And match response[0].status == 'EFETIVADA'
    And match response[0].data == today

  @validation @negative
  Scenario Outline: SCEN-TX-18 - Rejeicao de query parameters fora do schema permitido (<parametro>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path transactionsPath
    And header Authorization = auth.authHeader
    And params <query_params>
    When method get
    Then status 422
    And match response == validationErrorSchema

    Examples:
      | parametro        | query_params                           |
      | mês menor que 1  | { mes: 0, ano: 2026 }                  |
      | mês maior que 12 | { mes: 13, ano: 2026 }                 |
      | ano menor que min| { mes: 9, ano: 1899 }                  |
      | ano maior que max| { mes: 9, ano: 2101 }                  |
      | status inválido  | { status: 'PENDENTE' }                 |
      | conta_id não-UUID| { conta_id: 'nao-uuid-1234' }          |
      | limit negativo   | { limit: -1 }                          |
      | limit acima 100  | { limit: 101 }                         |

  @security @negative
  Scenario: SCEN-TX-19 - Tentativa de listagem sem autenticacao
    Given path transactionsPath
    When method get
    Then status 401
