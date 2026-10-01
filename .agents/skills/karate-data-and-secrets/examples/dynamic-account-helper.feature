@ignore
Feature: Helper Reutilizavel - Criacao Dinamica de Conta e Sessao de Usuario

  Background:
    * url baseUrl
    * def registerPath = '/api/v1/auth/register'
    * def loginPath = '/api/v1/auth/login'

  Scenario: Gerar credenciais dinamicas, cadastrar usuario e retornar autenticacao
    # 1. Gera credenciais unicas e matematicamente seguras contra colisoes
    * def dynamicEmail = dataGenerator.getRandomEmail()
    * def dynamicPassword = dataGenerator.getRandomValidPassword()

    # 2. Cadastro da nova conta
    Given path registerPath
    * def registerPayload = read('classpath:data/payloads/auth/register-request.json')
    * set registerPayload.email = dynamicEmail
    * set registerPayload.password = dynamicPassword
    And request registerPayload
    When method post
    Then status 201
    * def userId = response.id

    # 3. Autenticacao e obtencao do token de sessao
    Given path loginPath
    * def loginPayload = read('classpath:data/payloads/auth/login-request.json')
    * set loginPayload.email = dynamicEmail
    * set loginPayload.password = dynamicPassword
    And request loginPayload
    When method post
    Then status 200
    * def token = response.access_token
    * def authHeader = 'Bearer ' + token
