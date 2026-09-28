@transactions @delete
Feature: User Story 5 - Exclusao de Transacao e Reversao de Saldo (DELETE /api/v1/transactions/{transaction_id})
  Como um usuario da plataforma Finance Organizer
  Quero excluir uma transacao financeira registrada incorretamente ou cancelada
  Para que a movimentacao seja removida e o impacto financeiro no saldo da conta associada seja devidamente revertido

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def transactionsPath = '/api/v1/transactions/'
    * def accountResponseSchema = read('classpath:data/schemas/accounts/account-response-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-TX-29 - Exclusao bem-sucedida de transacao e inacessibilidade subsequente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    # Cria conta
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Delete Tx' }
    When method post
    Then status 201
    * def accountId = response.id

    # Cria transacao
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * set payload.conta_id = accountId
    * set payload.data = today
    * set payload.descricao = 'Tx Para Excluir'
    And request payload
    When method post
    Then status 201
    * def txId = response.id

    # Exclui transacao
    Given path transactionsPath, txId
    And header Authorization = auth.authHeader
    When method delete
    Then status 204
    And match response == ''

    # Consulta subsequente deve retornar 404
    Given path transactionsPath, txId
    And header Authorization = auth.authHeader
    When method get
    Then status 404

  @integration @balance @reversion
  Scenario Outline: SCEN-TX-30 - Reversao contabil imediata de saldo apos exclusao de <tipo>
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    # 1. Cria conta
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Reversao Saldo' }
    When method post
    Then status 201
    * def accountId = response.id

    # 2. Cria receita base de 1000.00 para estabelecer saldo base
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txBase = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txBase.conta_id = accountId
    * txBase.tipo = 'RECEITA'
    * txBase.valor = 1000.00
    * txBase.data = today
    * txBase.descricao = 'Saldo Base 1000'
    And request txBase
    When method post
    Then status 201

    # Verifica saldo base na conta
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response.saldo_calculado == '1000.00'

    # 3. Cria transacao do cenario (<tipo>, <valor>)
    Given path transactionsPath
    And header Authorization = auth.authHeader
    * def txTest = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * txTest.conta_id = accountId
    * txTest.tipo = '<tipo>'
    * txTest.valor = <valor>
    * txTest.data = today
    * txTest.descricao = 'Movimentacao Teste'
    And request txTest
    When method post
    Then status 201
    * def txTestId = response.id

    # 4. Exclui a transacao criada
    Given path transactionsPath, txTestId
    And header Authorization = auth.authHeader
    When method delete
    Then status 204

    # 5. Consulta conta e valida reversao para 1000.00
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method get
    Then status 200
    And match response == accountResponseSchema
    And match response.saldo_calculado == '1000.00'

    Examples:
      | tipo    | valor  |
      | RECEITA | 500.00 |
      | DESPESA | 250.00 |

  @security @idor
  Scenario: SCEN-TX-31 - Bloqueio de exclusao de transacao de terceiro (IDOR)
    # 1. Usuario B cria conta e transacao
    * def authB = call read('classpath:features/helpers/auth-helper.feature')
    * def today = java.time.LocalDate.now().toString()

    Given path accountsPath
    And header Authorization = authB.authHeader
    And request { apelido: 'Conta B Exclusao' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    Given path transactionsPath
    And header Authorization = authB.authHeader
    * def payloadB = read('classpath:data/payloads/transactions/transaction-create-request.json')
    * payloadB.conta_id = accountB_Id
    * payloadB.data = today
    * payloadB.descricao = 'Despesa Pessoal B'
    And request payloadB
    When method post
    Then status 201
    * def txB_Id = response.id

    # 2. Usuario A tenta excluir transacao de B
    * def authA = call read('classpath:features/helpers/auth-helper.feature')

    Given path transactionsPath, txB_Id
    And header Authorization = authA.authHeader
    When method delete
    Then match [403, 404] contains responseStatus

    # 3. Usuario B confirma que a transacao ainda existe
    Given path transactionsPath, txB_Id
    And header Authorization = authB.authHeader
    When method get
    Then status 200
    And match response.descricao == 'Despesa Pessoal B'

  @validation @negative
  Scenario Outline: SCEN-TX-32 - Exclusao com identificador invalido ou inexistente (<motivo>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path transactionsPath, '<id_informado>'
    And header Authorization = auth.authHeader
    When method delete
    Then status <status_esperado>

    Examples:
      | motivo              | id_informado                          | status_esperado |
      | UUID não cadastrado | 00000000-0000-0000-0000-000000000000 | 404             |
      | formato não-UUID    | id-invalido-xyz                       | 422             |

  @security @negative
  Scenario: SCEN-TX-33 - Tentativa de exclusao sem cabecalho Authorization
    * def randomUuid = java.util.UUID.randomUUID().toString()
    Given path transactionsPath, randomUuid
    When method delete
    Then status 401
