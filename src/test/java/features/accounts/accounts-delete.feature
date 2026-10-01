@accounts @delete
Feature: User Story 5 - Exclusao de Conta e Integridade Referencial (DELETE /api/v1/accounts/{account_id})
  Como um usuario da plataforma Finance Organizer
  Quero encerrar ou excluir uma conta ou carteira que nao utilizo mais
  Para manter minha visao consolidada limpa e organizada

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def transactionsPath = '/api/v1/transactions/'
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-ACC-32 - Exclusao bem-sucedida de conta sem dependencias
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Cria conta
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta para Deletar' }
    When method post
    Then status 201
    * def accountId = response.id

    # Deleta conta vazia
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method delete
    Then status 204
    And match response == ''

    # Valida inacessibilidade subsequente
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method get
    Then status 404

  @integrity @referential_integrity
  Scenario: SCEN-ACC-33 - Integridade referencial ao excluir conta com transacoes vinculadas
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 1. Cria conta
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Com Transacao' }
    When method post
    Then status 201
    * def accountId = response.id

    # 2. Registra transacao filha
    Given path transactionsPath
    And header Authorization = auth.authHeader
    And request
      """
      {
        "valor": 100.00,
        "tipo": "RECEITA",
        "data": "2026-09-28",
        "descricao": "Deposito de Teste",
        "conta_id": "#(accountId)",
        "recorrencia": "UNICA"
      }
      """
    When method post
    Then status 201

    # 3. Tenta deletar a conta com transacao associada
    Given path accountsPath, accountId
    And header Authorization = auth.authHeader
    When method delete
    # Servidor deve responder ou com Cascade Delete (204) ou com Protecao de Integridade (400 ou 409), nunca 500
    Then match [204, 400, 409] contains responseStatus
    And match responseStatus != 500

    # 4. Checagem de consistencia de acordo com o status retornado
    * if (responseStatus == 204) karate.log('API executou delecao em cascata')
    * if (responseStatus != 204) karate.log('API protegeu a integridade referencial com status ' + responseStatus)

  @negative @not_found
  Scenario: SCEN-ACC-34 - Exclusao de conta com identificador inexistente
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    * def randomUuid = java.util.UUID.randomUUID().toString()

    Given path accountsPath, randomUuid
    And header Authorization = auth.authHeader
    When method delete
    Then status 404

  @security @idor
  Scenario: SCEN-ACC-35 - Tentativa de deletar conta de outro usuario (IDOR)
    * def authB = call read('classpath:features/helpers/auth-helper.feature')
    * def authA = call read('classpath:features/helpers/auth-helper.feature')

    # Usuario B cria conta
    Given path accountsPath
    And header Authorization = authB.authHeader
    And request { apelido: 'Conta Protegida B' }
    When method post
    Then status 201
    * def accountB_Id = response.id

    # Usuario A tenta deletar a conta do Usuario B
    Given path accountsPath, accountB_Id
    And header Authorization = authA.authHeader
    When method delete
    Then status 404

    # Confirma que a conta do Usuario B continua existindo intacta
    Given path accountsPath, accountB_Id
    And header Authorization = authB.authHeader
    When method get
    Then status 200
    And match response.id == accountB_Id
    And match response.apelido == 'Conta Protegida B'

  @validation @negative
  Scenario: SCEN-ACC-36 - Exclusao com account_id nao-UUID
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath, 'id-invalido-abc'
    And header Authorization = auth.authHeader
    When method delete
    Then status 422
    And match response == validationErrorSchema

  @security @negative
  Scenario Outline: SCEN-ACC-37 - Exclusao de conta sem autenticacao (<condicao_auth>)
    * def fakeId = '00000000-0000-0000-0000-000000000000'

    Given path accountsPath, fakeId
    And header Authorization = '<header_val>'
    When method delete
    Then status 401
    And match response.id == '#notpresent'

    Examples:
      | condicao_auth       | header_val              |
      | cabeçalho ausente   |                         |
      | token inválido      | Bearer token_falso_1234 |
      | esquema não bearer  | Basic dXNlcjpwYXNz      |
