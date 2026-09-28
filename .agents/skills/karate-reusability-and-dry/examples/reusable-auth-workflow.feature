@ignore
Feature: Exemplo de Helper Reutilizavel para Autenticacao e Provisionamento

  Background:
    * url baseUrl

  Scenario: Autenticar e provisionar contexto de usuario isolado
    * def uniqueEmail = dataGenerator.getRandomEmail()
    * def uniquePassword = dataGenerator.getRandomValidPassword()

    # 1. Registro da conta
    Given path '/api/v1/auth/register'
    * def regBody = read('classpath:data/payloads/auth/register-request.json')
    * set regBody.email = uniqueEmail
    * set regBody.password = uniquePassword
    And request regBody
    When method post
    Then status 201
    * def userId = response.id

    # 2. Login
    Given path '/api/v1/auth/login'
    * def loginBody = read('classpath:data/payloads/auth/login-request.json')
    * set loginBody.email = uniqueEmail
    * set loginBody.password = uniquePassword
    And request loginBody
    When method post
    Then status 200
    * def authToken = response.access_token
    * def authHeader = 'Bearer ' + authToken
