@auth @validation
Feature: Exemplo de Referencia - Testes Parametrizados e Limites com Karate DSL

  Background:
    * url baseUrl
    * def registerPath = '/api/v1/auth/register'
    * def userResponseSchema = read('classpath:data/schemas/auth/user-response-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')

  @boundaries @happy_path
  Scenario Outline: SCEN-EX-01 - Cadastro com senhas nos limites aceitos (<tamanho> caracteres)
    Given path registerPath
    * def userEmail = dataGenerator.getRandomEmail()
    * def userPassword = dataGenerator.generatePassword(<tamanho>)
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = userEmail
    * set payload.password = userPassword
    And request payload
    When method post
    Then status 201
    And match response == userResponseSchema
    And match response.email == userEmail
    And match response.is_active == true
    # Garante que senhas ou hashes nunca sao expostos na resposta
    And match response.password == '#notpresent'
    And match response.hashed_password == '#notpresent'

    Examples:
      | tamanho |
      | 8       |
      | 16      |
      | 72      |

  @validation @negative
  Scenario Outline: SCEN-EX-02 - Rejeicao de emails invalidos (<motivo>)
    Given path registerPath
    * def payload = read('classpath:data/payloads/auth/register-request.json')
    * set payload.email = '<email_invalido>'
    * set payload.password = dataGenerator.getRandomValidPassword()
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

    Examples:
      | email_invalido              | motivo                   |
      | sem_arroba.com              | ausência de arroba       |
      | usuario@sem_dominio         | sem domínio TLD          |
      | usuario com espaco@dom.com  | espaço em branco         |
      | @dominio.com                | ausência de usuário      |
