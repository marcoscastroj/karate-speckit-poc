@accounts @update
Feature: User Story 4 - Atualizacao de Conta ou Carteira (PUT /api/v1/accounts/{account_id})
  Como um usuario autenticado na plataforma Finance Organizer
  Quero atualizar o apelido de uma das minhas contas existentes
  Para refletir mudancas no nome ou na instituicao financeira onde mantenho meus recursos

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def accountResponseSchema = read('classpath:data/schemas/accounts/account-response-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-ACC-23 - Atualizacao de apelido de conta existente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria conta original
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Nome Antigo' }
    When method post
    Then status 201
    * def accountId = response.id
    * def originalCreatedAt = response.created_at

    # Atualiza apelido
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    And request { apelido: 'Banco Inter' }
    When method put
    Then status 200
    And match response == accountResponseSchema
    And match response.id == accountId
    And match response.apelido == 'Banco Inter'
    And match response.user_id == auth.userId
    And match response.created_at == originalCreatedAt

  @boundaries @happy_path
  Scenario Outline: SCEN-ACC-24 - Atualizacao de apelido nos limites permitidos (<limite>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria conta original
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Base' }
    When method post
    Then status 201
    * def accountId = response.id

    # Atualiza com apelido nos limites
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    And request { apelido: '<novo_apelido>' }
    When method put
    Then status 200
    And match response == accountResponseSchema
    And match response.apelido == '<novo_apelido>'

    Examples:
      | limite                   | novo_apelido                                                                                         |
      | limite mínimo (1 char)   | X                                                                                                    |
      | limite máximo (100 chars)| Carteira_de_Investimentos_Internacionais_Renda_Fixa_e_Acoes_Globais_Multimercado_High_Yield_100char |

  @boundaries @negative
  Scenario: SCEN-ACC-25 - Rejeicao de atualizacao com apelido vazio (0 caracteres)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Original' }
    When method post
    Then status 201
    * def accountId = response.id

    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    And request { apelido: '' }
    When method put
    Then status 422
    And match response == validationErrorSchema

  @boundaries @negative
  Scenario: SCEN-ACC-26 - Rejeicao de atualizacao com apelido acima de 100 caracteres
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Original' }
    When method post
    Then status 201
    * def accountId = response.id

    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    And request { apelido: 'Carteira_de_Investimentos_Internacionais_Renda_Fixa_e_Acoes_Globais_Multimercado_High_Yield_101charsX' }
    When method put
    Then status 422
    And match response == validationErrorSchema

  @negative @not_found
  Scenario: SCEN-ACC-27 - Atualizacao de conta inexistente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def randomUuid = java.util.UUID.randomUUID().toString()

    Given path accountsPath, randomUuid
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Fantasma' }
    When method put
    Then status 404

  @security @idor
  Scenario: SCEN-ACC-28 - Tentativa de atualizar conta de terceiro (IDOR)
    * def authB = call read('classpath:features/helpers/auth-helper.feature')
    * def authA = call read('classpath:features/helpers/auth-helper.feature')

    # Usuario B cria conta
    Given path accountsPath
    And header Authorization = authB.authHeader
    And request { apelido: 'Conta Segura de B' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    # Usuario A tenta atualizar conta do Usuario B
    Given path accountsPath, accountB_Id
    And header Authorization = authA.authHeader
    And request { apelido: 'Nome Invasor' }
    When method put
    Then status 404

    # Confirma que apelido da conta do Usuario B nao foi modificado
    Given path accountsPath, accountB_Id
    And header Authorization = authB.authHeader
    When method get
    Then status 200
    And match response.apelido == 'Conta Segura de B'

  @security @data_integrity
  Scenario: SCEN-ACC-29 - Preservacao de campos imutaveis durante atualizacao
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria conta original
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Intacta' }
    When method post
    Then status 201
    * def accountId = response.id

    # Tenta sobrescrever campos protegidos via PUT
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    And request
      """
      {
        "apelido": "Conta Modificada",
        "saldo_calculado": "999999.00",
        "user_id": "00000000-0000-0000-0000-000000000000",
        "id": "11111111-1111-1111-1111-111111111111"
      }
      """
    When method put
    Then status 200
    And match response.id == accountId
    And match response.user_id == auth.userId
    And match ['0', '0.00'] contains response.saldo_calculado
    And match response.apelido == 'Conta Modificada'

  @validation @negative
  Scenario: SCEN-ACC-30 - Atualizacao com path parameter nao-UUID
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath, 'formato-invalido'
    And header Authorization = auth.authHeader
    And request { apelido: 'Novo Nome' }
    When method put
    Then status 422
    And match response == validationErrorSchema

  @security @negative
  Scenario Outline: SCEN-ACC-31 - Atualizacao de conta sem credenciais (<condicao_auth>)
    * def fakeId = '00000000-0000-0000-0000-000000000000'

    Given path accountsPath, fakeId
    And header Authorization = '<header_val>'
    And request { apelido: 'Tentativa Anonima' }
    When method put
    Then status 401
    And match response.id == '#notpresent'

    Examples:
      | condicao_auth       | header_val              |
      | cabeçalho ausente   |                         |
      | token inválido      | Bearer token_falso_1234 |
      | esquema não bearer  | Basic dXNlcjpwYXNz      |
