@transactions @create
Feature: User Story 1 - Registro de Transacoes Financeiras (POST /api/v1/transactions/)
  Como um usuario autenticado na plataforma Finance Organizer
  Quero registrar movimentacoes financeiras de receitas ou despesas vinculadas a uma das minhas contas
  Para que o sistema atribua automaticamente o status correto baseado na data, consolide meu saldo e registre meu historico financeiro

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def transactionsPath = '/api/v1/transactions/'
    * def transactionResponseSchema = read('classpath:data/schemas/transactions/transaction-response-schema.json')
    * def accountResponseSchema = read('classpath:data/schemas/accounts/account-response-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-TX-01 - Registro bem-sucedido de receita com data <= hoje atribuindo status EFETIVADA
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    # 1. Cria conta para o usuario
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Receitas' }
    When method post
    Then status 201
    * def accountId = response.id

    # 2. Cria transacao de RECEITA com data atual (<= hoje)
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.valor = 1250.50
    * set payload.tipo = 'RECEITA'
    * set payload.data = today
    * set payload.descricao = 'Salário Mensal'
    * set payload.conta_id = accountId
    * set payload.recorrencia = 'UNICA'
    And request payload
    When method post
    Then status 201
    And match response == transactionResponseSchema
    And match response.id == '#uuid'
    And match response.user_id == auth.userId
    And match response.conta_id == accountId
    And match response.tipo == 'RECEITA'
    And match response.status == 'EFETIVADA'
    And match response.data == today
    And match response.descricao == 'Salário Mensal'
    And match response.recorrencia == 'UNICA'
    And match response.created_at == '#regex ^\\d{4}-\\d{2}-\\d{2}T.*'
    And match response.valor == '#regex ^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d{0,2}0*$'

  @business_rule @temporal
  Scenario: SCEN-TX-02 - Registro de despesa futura com data > hoje atribuindo status AGENDADA
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def futureDate = java.time.LocalDate.now().plusDays(5).toString()

    # Cria conta
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Despesas Futuras' }
    When method post
    Then status 201
    * def accountId = response.id

    # Cria transacao com data futura (D+5)
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.valor = 300.00
    * set payload.tipo = 'DESPESA'
    * set payload.data = futureDate
    * set payload.descricao = 'Fatura Cartão Futura'
    * set payload.conta_id = accountId
    * set payload.recorrencia = 'UNICA'
    And request payload
    When method post
    Then status 201
    And match response == transactionResponseSchema
    And match response.tipo == 'DESPESA'
    And match response.status == 'AGENDADA'
    And match response.data == futureDate

  @happy_path @parameterized
  Scenario Outline: SCEN-TX-03 - Suporte aos padroes de recorrencia (<recorrencia>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Recorrencias' }
    When method post
    Then status 201
    * def accountId = response.id

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.valor = 500.00
    * set payload.tipo = 'RECEITA'
    * set payload.data = today
    * set payload.descricao = 'Recorrencia Teste'
    * set payload.conta_id = accountId
    * set payload.recorrencia = '<recorrencia>'
    And request payload
    When method post
    Then status 201
    And match response == transactionResponseSchema
    And match response.recorrencia == '<recorrencia>'

    Examples:
      | recorrencia |
      | UNICA       |
      | SEMANAL     |
      | MENSAL      |
      | ANUAL       |

  @boundaries @happy_path
  Scenario Outline: SCEN-TX-04 - Aceitacao de valores monetarios validos (<descricao>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Decimal' }
    When method post
    Then status 201
    * def accountId = response.id

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.valor = <valor_input>
    * set payload.tipo = 'RECEITA'
    * set payload.data = today
    * set payload.descricao = 'Teste Decimal'
    * set payload.conta_id = accountId
    * set payload.recorrencia = 'UNICA'
    And request payload
    When method post
    Then status 201
    And match response == transactionResponseSchema
    And match response.valor == '#regex ^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d{0,2}0*$'

    Examples:
      | descricao           | valor_input |
      | inteiro simples     | 100         |
      | decimal com 1 casa  | 100.5       |
      | decimal com 2 casas | 100.55      |

  @integration @balance
  Scenario: SCEN-TX-05 - Atualizacao automatica e dinamica do saldo da conta
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    # 1. Cria conta nova com saldo zero
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Balanco Dinamico' }
    When method post
    Then status 201
    * def accountId = response.id
    * match response.saldo_calculado == '0.00'

    # 2. Registra RECEITA de 2000.00
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload1 = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload1.valor = 2000.00
    * set payload1.tipo = 'RECEITA'
    * set payload1.data = today
    * set payload1.descricao = 'Salario Dinamico'
    * set payload1.conta_id = accountId
    And request payload1
    When method post
    Then status 201

    # 3. Consulta conta: saldo deve ser 2000.00
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == accountResponseSchema
    And match response.saldo_calculado == '2000.00'

    # 4. Registra DESPESA de 450.00
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload2 = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload2.valor = 450.00
    * set payload2.tipo = 'DESPESA'
    * set payload2.data = today
    * set payload2.descricao = 'Conta de Luz'
    * set payload2.conta_id = accountId
    And request payload2
    When method post
    Then status 201

    # 5. Consulta conta: saldo deve ser 1550.00 (2000.00 - 450.00)
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == accountResponseSchema
    And match response.saldo_calculado == '1550.00'

  @boundaries @negative
  Scenario Outline: SCEN-TX-06 - Rejeicao de transacao com valor monetario invalido (<motivo>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Invalida' }
    When method post
    Then status 201
    * def accountId = response.id

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.conta_id = accountId
    * set payload.data = today
    * set payload.valor = <valor_invalido>
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema

    Examples:
      | motivo               | valor_invalido |
      | valor zero           | 0              |
      | valor negativo       | -50.00         |
      | mais de 2 decimais   | 100.999        |
      | valor textual/letras | 'cem_reais'    |

  @validation @negative
  Scenario Outline: SCEN-TX-07 - Rejeicao de campos com valores fora do dominio (<cenario>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Dominio' }
    When method post
    Then status 201
    * def accountId = response.id

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.conta_id = accountId
    * set payload.data = today
    * payload['<campo>'] = '<valor>'
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema

    Examples:
      | cenario             | campo        | valor          |
      | tipo invalido       | tipo         | TRANSFERENCIA  |
      | recorrencia fora    | recorrencia  | DIARIA         |
      | data formato errado | data         | 28/09/2026     |

  @boundaries @negative
  Scenario Outline: SCEN-TX-08 - Validacao de limites na descricao da transacao (<cenario>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Limites' }
    When method post
    Then status 201
    * def accountId = response.id

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.conta_id = accountId
    * set payload.data = today
    * set payload.descricao = '<descricao_teste>'
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema

    Examples:
      | cenario                   | descricao_teste                                                                                                              |
      | string vazia (0 chars)    |                                                                                                                              |
      | acima do limite (256 car) | DescricaoComMaisDeDuzentosECinquentaECincoCaracteres_LoremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididuntUtLaboreEtDoloreMagnaAliquaUtEnimAdMinimVeniamQuisNostrudExercitationUllamcoLaborisNisiUtAliquipExEaCommodoConsequatDuisAuteIrureDolorInReprehenderit256charsX |

  @validation @negative
  Scenario Outline: SCEN-TX-09 - Rejeicao por omissao de campos obrigatorios (<campo_ausente>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Obrigatorios' }
    When method post
    Then status 201
    * def accountId = response.id

    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.conta_id = accountId
    * set payload.data = today
    * karate.remove('payload', '<campo_ausente>')
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema

    Examples:
      | campo_ausente |
      | valor         |
      | tipo          |
      | data          |
      | descricao     |
      | conta_id      |

  @security @idor
  Scenario: SCEN-TX-10 - Tentativa de registrar transacao vinculada a conta de terceiro ou UUID inexistente
    # 1. Provisiona Usuario B com uma conta
    * def authB = call read('classpath:features/helpers/auth-helper.feature')
    Given path accountsPath
    And header Authorization = authB.authHeader
    And request { apelido: 'Conta Segura B' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    # 2. Provisiona Usuario A
    * def authA = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    # 3. Usuario A tenta criar transacao vinculada a conta do Usuario B (IDOR)
    Given path transactionsPath
    And header Authorization = authA.authHeader
    * def payloadB = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payloadB.conta_id = accountB_Id
    * set payloadB.data = today
    And request payloadB
    When method post
    Then match [403, 404] contains responseStatus

    # 4. Usuario A tenta criar transacao com UUID aleatorio inexistente
    * def randomUuid = java.util.UUID.randomUUID().toString()
    Given path transactionsPath
    And header Authorization = authA.authHeader
    * def payloadRandom = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payloadRandom.conta_id = randomUuid
    * set payloadRandom.data = today
    And request payloadRandom
    When method post
    Then match [403, 404] contains responseStatus

  @security @negative
  Scenario Outline: SCEN-TX-11 - Tentativa de registro sem autenticacao valida (<condicao_auth>)
    * def randomUuid = java.util.UUID.randomUUID().toString()
    * def today = java.time.LocalDate.now().toString()

    Given path transactionsPath
    And header Authorization = '<header_val>'
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.conta_id = randomUuid
    * set payload.data = today
    And request payload
    When method post
    Then status 401
    And match response.id == '#notpresent'

    Examples:
      | condicao_auth       | header_val              |
      | cabeçalho ausente   |                         |
      | token inválido      | Bearer token_falso_1234 |
      | esquema não bearer  | Basic dXNlcjpwYXNz      |
