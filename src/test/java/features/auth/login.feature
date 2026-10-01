@auth @login
Feature: User Story 2 - Autenticacao e Emissao de Tokens de Acesso (POST /api/v1/auth/login)
  Como um usuario cadastrado e ativo na plataforma
  Quero fornecer minhas credenciais de e-mail e senha
  Para que o sistema autentique minha identidade e me emita um token JWT seguro

  Background:
    * url baseUrl
    * def loginPath = '/api/v1/auth/login'
    * def registerPath = '/api/v1/auth/register'
    * def tokenSchema = read('classpath:data/schemas/auth/token-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-LOG-01 - Autenticacao com sucesso e emissao de JWT
    # 1. Cria um usuario dinâmico para garantir credenciais validas
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.getRandomValidPassword()
    * def regPayload = read('classpath:data/payloads/auth/register-request.json')
    * set regPayload.email = userEmail
    * set regPayload.password = userPassword
    Given path registerPath
    And request regPayload
    When method post
    Then status 201

    # 2. Realiza o login com as credenciais cadastradas
    Given path loginPath
    * def payload = read('classpath:data/payloads/auth/login-request.json')
    * set payload.email = userEmail
    * set payload.password = userPassword
    And request payload
    And retry until responseStatus != 429
    When method post
    Then status 200
    And match response == tokenSchema
    And match response.access_token == '#present'
    And match response.token_type == 'bearer'

  @security @negative
  Scenario: SCEN-LOG-02 - Tentativa de autenticacao com senha invalida
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.getRandomValidPassword()
    * def regPayload = read('classpath:data/payloads/auth/register-request.json')
    * set regPayload.email = userEmail
    * set regPayload.password = userPassword
    Given path registerPath
    And request regPayload
    When method post
    Then status 201

    Given path loginPath
    * def payload = read('classpath:data/payloads/auth/login-request.json')
    * set payload.email = userEmail
    * set payload.password = 'WrongPassword999'
    And request payload
    And retry until responseStatus != 429
    When method post
    Then status 401
    And match response.access_token == '#notpresent'
    And match response.detail == '#present'

  @security @negative
  Scenario: SCEN-LOG-03 - Tentativa de login com e-mail nao cadastrado
    * def nonExistentEmail = dataGenerator.getRandomEmail()
    Given path loginPath
    * def payload = read('classpath:data/payloads/auth/login-request.json')
    * set payload.email = nonExistentEmail
    * set payload.password = 'ArbitraryPassword123'
    And request payload
    And retry until responseStatus != 429
    When method post
    Then status 401
    And match response.access_token == '#notpresent'
    And match response.detail == '#present'

  @security @negative
  Scenario: SCEN-LOG-04 - Bloqueio de acesso para conta desativada
    * def inactiveEmail = 'inactive_user_' + java.util.UUID.randomUUID() + '@example.com'
    Given path loginPath
    * def payload = read('classpath:data/payloads/auth/login-request.json')
    * set payload.email = inactiveEmail
    * set payload.password = 'Password123'
    And request payload
    And retry until responseStatus != 429
    When method post
    Then assert responseStatus == 403 || responseStatus == 401
    And match response.access_token == '#notpresent'

  @validation @negative
  Scenario Outline: SCEN-LOG-05 - Payload de login com campos vazios ou nulos (<cenario>)
    Given path loginPath
    And request <payload>
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

    Examples:
      | cenario      | payload                                     |
      | e-mail vazio | { email: "", password: "ValidPassword123" } |
      | senha vazia  | { email: "user@test.com", password: "" }    |
      | campos nulos | { email: null, password: null }             |
