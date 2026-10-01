@transactions @projections
Feature: User Story 3 - Projeções e Totalizadores Mensais (GET /api/v1/transactions/projections)
  Como um usuario autenticado na plataforma Finance Organizer
  Quero consultar as projecoes financeiras consolidando o total de receitas e despesas previstas e o saldo projetado de um mes e ano especificos
  Para que eu tenha clareza do fluxo de caixa previsto e planeje minhas financas com antecedencia

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def transactionsPath = '/api/v1/transactions/'
    * def projectionsPath = '/api/v1/transactions/projections'
    * def projectionsSchema = read('classpath:data/schemas/transactions/transaction-projections-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @calculation @happy_path
  Scenario: SCEN-TX-20 - Calculo dinamico de projecoes do mes (receitas, despesas e saldo projetado)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def now = java.time.LocalDate.now()
    * def mesRef = now.getMonthValue()
    * def anoRef = now.getYear()
    * def dateEfetivada = now.withDayOfMonth(5).toString()
    * def dateAgendada = now.withDayOfMonth(10).toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Projecoes' }
    When method post
    Then status 201
    * def accountId = response.id

    # 1. Receita efetivada: 3000.00
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def tx1 = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * tx1.conta_id = accountId
    * tx1.tipo = 'RECEITA'
    * tx1.valor = 3000.00
    * tx1.data = dateEfetivada
    * tx1.descricao = 'Receita 1'
    And request tx1
    When method post
    Then status 201

    # 2. Receita agendada: 1000.00
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def tx2 = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * tx2.conta_id = accountId
    * tx2.tipo = 'RECEITA'
    * tx2.valor = 1000.00
    * tx2.data = dateAgendada
    * tx2.descricao = 'Receita 2'
    And request tx2
    When method post
    Then status 201

    # 3. Despesa efetivada: 800.50
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def tx3 = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * tx3.conta_id = accountId
    * tx3.tipo = 'DESPESA'
    * tx3.valor = 800.50
    * tx3.data = dateEfetivada
    * tx3.descricao = 'Despesa 1'
    And request tx3
    When method post
    Then status 201

    # 4. Despesa agendada: 450.25
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def tx4 = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * tx4.conta_id = accountId
    * tx4.tipo = 'DESPESA'
    * tx4.valor = 450.25
    * tx4.data = dateAgendada
    * tx4.descricao = 'Despesa 2'
    And request tx4
    When method post
    Then status 201

    # Consulta de projecoes para o mes e ano
    Given path projectionsPath
    And header Authorization = auth.authHeader
    And param mes = mesRef
    And param ano = anoRef
    When method get
    Then status 200
    And match response == projectionsSchema
    And match response.mes == mesRef
    And match response.ano == anoRef
    And match response.conta_id == null
    And match response.receitas_previstas == '4000.00'
    And match response.despesas_previstas == '1250.75'
    And match response.saldo_projetado == '2749.25'

  @filtering @happy_path
  Scenario: SCEN-TX-21 - Projecao orcamentaria restrita a uma conta especifica
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def now = java.time.LocalDate.now()
    * def mesRef = now.getMonthValue()
    * def anoRef = now.getYear()
    * def dateRef = now.toString()

    # Conta A
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta A Proj' }
    When method post
    Then status 201
    * def accountA_Id = response.id

    # Conta B
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta B Proj' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    # Tx na Conta A: Receita 1500.00
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txA = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txA.conta_id = accountA_Id
    * txA.tipo = 'RECEITA'
    * txA.valor = 1500.00
    * txA.data = dateRef
    * txA.descricao = 'Tx Conta A'
    And request txA
    When method post
    Then status 201

    # Tx na Conta B: Receita 2000.00
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txB = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txB.conta_id = accountB_Id
    * txB.tipo = 'RECEITA'
    * txB.valor = 2000.00
    * txB.data = dateRef
    * txB.descricao = 'Tx Conta B'
    And request txB
    When method post
    Then status 201

    # Consulta projecao filtrando apenas Conta A
    Given path projectionsPath
    And header Authorization = auth.authHeader
    And param mes = mesRef
    And param ano = anoRef
    And param conta_id = accountA_Id
    When method get
    Then status 200
    And match response == projectionsSchema
    And match response.conta_id == accountA_Id
    And match response.receitas_previstas == '1500.00'
    And match ['0', '0.00'] contains response.despesas_previstas
    And match response.saldo_projetado == '1500.00'

  @empty_state @happy_path
  Scenario: SCEN-TX-22 - Consulta de projecoes em mes sem movimentacoes
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path projectionsPath
    And header Authorization = auth.authHeader
    And param mes = 1
    And param ano = 2099
    When method get
    Then status 200
    And match response == projectionsSchema
    And match response.mes == 1
    And match response.ano == 2099
    And match ['0', '0.00'] contains response.receitas_previstas
    And match ['0', '0.00'] contains response.despesas_previstas
    And match ['0', '0.00'] contains response.saldo_projetado

  @validation @negative
  Scenario Outline: SCEN-TX-23 - Rejeicao por parametros obrigatorios ausentes ou invalidos (<motivo>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path projectionsPath
    And header Authorization = auth.authHeader
    And params <query_params>
    When method get
    Then status 422
    And match response == validationErrorSchema

    Examples:
      | motivo             | query_params                                    |
      | ausência de mês    | { ano: 2026 }                                   |
      | ausência de ano    | { mes: 9 }                                      |
      | mês fora do limite | { mes: 13, ano: 2026 }                          |
      | ano fora do limite | { mes: 9, ano: 1800 }                           |
      | conta_id não-UUID  | { mes: 9, ano: 2026, conta_id: 'nao-uuid-val' } |

  @security @negative
  Scenario: SCEN-TX-24 - Consulta de projecoes sem cabecalho Authorization
    Given path projectionsPath
    And param mes = 9
    And param ano = 2026
    When method get
    Then status 401
