@auth @delete
Feature: User Story 4 - Exclusao Imediata da Conta e Efeito Cascata Transacional (DELETE /api/v1/auth/me)
  Como um usuario da plataforma Finance Organizer que deseja encerrar seu relacionamento
  Quero solicitar a exclusao imediata (Hard Delete) da minha conta
  Para que todos os meus dados cadastrais e entidades correlacionadas sejam expurgados com integridade

  Background:
    * url baseUrl
    * def mePath = '/api/v1/auth/me'
    * def loginPath = '/api/v1/auth/login'
    * def accountsPath = '/api/v1/accounts/'
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-DEL-01 - Exclusao imediata de usuario simples
    # 1. Setup autocontido via auth-helper
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 2. Exclusao da conta (Hard Delete)
    Given path mePath
    And header Authorization = auth.authHeader
    When method delete
    Then status 204
    And match response == ''

  @cascade @happy_path
  Scenario: SCEN-DEL-02 - Exclusao com limpeza em cascata de dados correlacionados
    # 1. Setup de usuario e autenticacao via auth-helper
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 2. Criacao de recurso filho (Carteira/Conta)
    Given path accountsPath
    And header Authorization = auth.authHeader
    And request { apelido: 'Carteira de Teste Cascata' }
    When method post
    Then status 201
    * def accountId = response.id

    # 3. Disparo do DELETE da conta do usuario
    Given path mePath
    And header Authorization = auth.authHeader
    When method delete
    Then status 204

    # 4. Validacao de inacessibilidade pos-exclusao (token e conta orfa)
    Given path accountsPath + accountId
    And header Authorization = auth.authHeader
    When method get
    Then assert responseStatus == 401 || responseStatus == 404

  @security @post_delete
  Scenario: SCEN-DEL-03 - Impossibilidade de login apos exclusao da conta
    # 1. Setup de usuario e autenticacao via auth-helper
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 2. Exclusao da conta
    Given path mePath
    And header Authorization = auth.authHeader
    When method delete
    Then status 204

    # 3. Tentativa de novo login com as credenciais deletadas
    Given path loginPath
    * def loginPayload = read('classpath:data/payloads/auth/login-request.json')
    * set loginPayload.email = auth.userEmail
    * set loginPayload.password = auth.userPassword
    And request loginPayload
    And retry until responseStatus != 429
    When method post
    Then status 401
    And match response.access_token == '#notpresent'

  @security @post_delete
  Scenario: SCEN-DEL-04 - Rejeicao de token de sessao previamente emitido apos exclusao
    # 1. Setup de usuario e autenticacao via auth-helper
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 2. Exclusao da conta
    Given path mePath
    And header Authorization = auth.authHeader
    When method delete
    Then status 204

    # 3. Tentativa de reusar o token para consultar /me
    Given path mePath
    And header Authorization = auth.authHeader
    When method get
    Then status 401
    And match response.id == '#notpresent'

  @security @negative
  Scenario Outline: SCEN-DEL-05 - Tentativa nao autorizada de exclusao de conta (<cenario>)
    Given path mePath
    And header Authorization = '<header_val>'
    When method delete
    Then status 401

    Examples:
      | cenario             | header_val              |
      | sem token           |                         |
      | token invalido      | Bearer token_falso_1234 |
      | esquema nao bearer  | Basic dXNlcjpwYXNz      |
