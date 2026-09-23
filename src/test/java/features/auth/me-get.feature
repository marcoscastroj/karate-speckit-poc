@auth @me
Feature: User Story 3 - Consulta de Perfil do Usuario Autenticado (GET /api/v1/auth/me)
  Como um usuario autenticado
  Quero consultar meu perfil atual atraves do meu token de sessao
  Para verificar meus dados cadastrais e confirmar que minha sessao permanece valida e integra

  Background:
    * url baseUrl
    * def mePath = '/api/v1/auth/me'
    * def registerPath = '/api/v1/auth/register'
    * def loginPath = '/api/v1/auth/login'
    * def userResponseSchema = read('classpath:data/schemas/auth/user-response-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-ME-01 - Obtencao dos dados do usuario logado via token valido
    # 1. Cadastro de usuario
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.getRandomValidPassword()
    * def regPayload = read('classpath:data/payloads/auth/register-request.json')
    * set regPayload.email = userEmail
    * set regPayload.password = userPassword
    Given path registerPath
    And request regPayload
    When method post
    Then status 201

    # 2. Login para obtencao de token JWT
    Given path loginPath
    * def loginPayload = read('classpath:data/payloads/auth/login-request.json')
    * set loginPayload.email = userEmail
    * set loginPayload.password = userPassword
    And request loginPayload
    And retry until responseStatus != 429
    When method post
    Then status 200
    * def authToken = response.access_token

    # 3. Consulta ao perfil do usuario logado
    Given path mePath
    And header Authorization = 'Bearer ' + authToken
    When method get
    Then status 200
    And match response == userResponseSchema
    And match response.email == userEmail
    And match response.is_active == true
    And match response.password == '#notpresent'
    And match response.hashed_password == '#notpresent'

  @security @negative
  Scenario: SCEN-ME-02 - Acesso nao autorizado por ausencia de cabecalho
    Given path mePath
    When method get
    Then status 401
    And match response.id == '#notpresent'

  @security @negative
  Scenario Outline: SCEN-ME-03 - Cabecalho de autorizacao com formato incorreto (<descricao_problema>)
    Given path mePath
    And header Authorization = '<cabecalho_malformado>'
    When method get
    Then status 401
    And match response.id == '#notpresent'

    Examples:
      | cabecalho_malformado         | descricao_problema               |
      | token_sem_prefixo_bearer_123 | ausencia do prefixo Bearer       |
      | Basic dXNlcjpwYXNz           | esquema de autorizacao incorreto |
      | Bearer                       | prefixo sem token associado      |

  @security @negative
  Scenario Outline: SCEN-ME-04 - Token invalido, expirado ou com assinatura adulterada (<condicao_token>)
    Given path mePath
    And header Authorization = 'Bearer <token_invalido>'
    When method get
    Then status 401
    And match response.id == '#notpresent'

    Examples:
      | condicao_token        | token_invalido                                           |
      | assinatura adulterada | eyJhbGciOiJIUzI1NiJ9.payload_falso.assinatura_adulterada |
      | token expirado        | token_jwt_com_claim_exp_no_passado                       |
      | string arbitraria     | token_totalmente_invalido_12345                          |
