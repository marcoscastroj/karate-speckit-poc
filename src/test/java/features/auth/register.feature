@auth @register
Feature: User Story 1 - Cadastro e Validacao de Contas de Usuario (POST /api/v1/auth/register)
  Como um novo usuario da plataforma Finance Organizer
  Quero cadastrar minha conta informando e-mail e senha
  Para ter acesso aos servicos de organizacao financeira com garantia de unicidade e validacoes

  Background:
    * url baseUrl
    * def registerPath = '/api/v1/auth/register'
    * def userResponseSchema = read('classpath:data/schemas/auth/user-response-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')

  @smoke @happy_path
  Scenario: SCEN-REG-01 - Cadastro bem-sucedido com senha minima (8 caracteres)
    Given path registerPath
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.generatePassword(8)
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = userEmail
    * set payload.password = userPassword
    And request payload
    When method post
    Then status 201
    And match response == userResponseSchema
    And match response.email == userEmail
    And match response.is_active == true
    And match response.password == '#notpresent'
    And match response.hashed_password == '#notpresent'

  @boundaries @happy_path
  Scenario: SCEN-REG-02 - Cadastro bem-sucedido com senha maxima (72 caracteres)
    Given path registerPath
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.generatePassword(72)
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = userEmail
    * set payload.password = userPassword
    And request payload
    When method post
    Then status 201
    And match response == userResponseSchema
    And match response.email == userEmail
    And match response.is_active == true

  @validation @negative
  Scenario Outline: SCEN-REG-03 - Rejeicao de cadastro com e-mail malformado (<motivo_falha>)
    Given path registerPath
    * def userPassword = dataGenerator.getRandomValidPassword()
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = '<email_invalido>'
    * set payload.password = userPassword
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

    Examples:
      | email_invalido              | motivo_falha                   |
      | usuario_sem_arroba.com      | ausência de arroba             |
      | usuario@sem_dominio         | domínio de nível superior nulo |
      | usuario com espacos@dom.com | espaços em branco intercalados |
      | @dominio.com                | ausência de id local           |

  @conflict @negative
  Scenario: SCEN-REG-04 - Conflito cadastral para e-mail ja existente
    # 1. Primeiro cadastro bem-sucedido
    Given path registerPath
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.getRandomValidPassword()
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = userEmail
    * set payload.password = userPassword
    And request payload
    When method post
    Then status 201

    # 2. Tentativa de cadastro duplicado com o mesmo e-mail
    Given path registerPath
    * def duplicatePayload = read('classpath:data/payloads/auth/register-request.json')
    * set duplicatePayload.email = userEmail
    * set duplicatePayload.password = dataGenerator.getRandomValidPassword()
    And request duplicatePayload
    When method post
    Then assert responseStatus == 409 || responseStatus == 400
    And match response.detail == '#present'

  @boundaries @negative
  Scenario: SCEN-REG-05 - Rejeicao de senha com 7 caracteres
    Given path registerPath
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.generatePassword(7)
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = userEmail
    * set payload.password = userPassword
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

  @boundaries @negative
  Scenario: SCEN-REG-06 - Rejeicao de senha com 73 caracteres
    Given path registerPath
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.generatePassword(73)
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = userEmail
    * set payload.password = userPassword
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

  @validation @negative
  Scenario Outline: SCEN-REG-07 - Ausencia de campos obrigatorios no cadastro (<descricao_payload>)
    Given path registerPath
    And request <payload>
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

    Examples:
      | descricao_payload  | payload                                                    |
      | sem campo email    | { password: "ValidPassword123" }                           |
      | sem campo password | { email: "missing_pass_test@example.com" }                 |
      | payload vazio      | {}                                                         |

  @validation @negative
  Scenario: SCEN-REG-08 - Tipagem incorreta no e-mail
    Given path registerPath
    And request { email: 123456789, password: "ValidPassword123" }
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

  @security @negative
  Scenario: SCEN-REG-09 - Tentativa de injecao de atributos nao mapeados em UserCreate (Mass Assignment)
    Given path registerPath
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = dataGenerator.getRandomEmail()
    * set payload.password = dataGenerator.getRandomValidPassword()
    * set payload.is_active = false
    * set payload.role = 'admin'
    * set payload.superuser = true
    And request payload
    When method post
    Then assert responseStatus == 422 || (responseStatus == 201 && response.is_active == true)
