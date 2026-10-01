@ignore
Feature: Helper Reutilizavel - Autenticacao e Provisionamento Dinamico

  Background:
    * url baseUrl
    * def registerPath = '/api/v1/auth/register'
    * def loginPath = '/api/v1/auth/login'

  Scenario: Criar usuario exclusivo e retornar token JWT
    # Recebe email e senha opcionais ou gera dinamicamente se nao forem passados
    * def userEmail = karate.get('targetEmail', dataGenerator.getRandomEmail())
    * def userPassword = karate.get('targetPassword', dataGenerator.getRandomValidPassword())

    # 1. Cadastro da nova conta
    Given path registerPath
    * def regPayload = read('classpath:data/payloads/auth/register-request.json')
    * set regPayload.email = userEmail
    * set regPayload.password = userPassword
    And request regPayload
    When method post
    Then status 201
    * def userId = response.id

    # 2. Login com as credenciais cadastradas
    Given path loginPath
    * def loginPayload = read('classpath:data/payloads/auth/login-request.json')
    * set loginPayload.email = userEmail
    * set loginPayload.password = userPassword
    And request loginPayload
    And retry until responseStatus != 429
    When method post
    Then status 200
    * def authToken = response.access_token
    * def authHeader = 'Bearer ' + authToken
