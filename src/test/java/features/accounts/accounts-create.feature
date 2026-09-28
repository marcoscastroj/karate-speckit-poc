@accounts @create
Feature: User Story 1 - Criacao de Contas e Carteiras (POST /api/v1/accounts/)
  Como um usuario autenticado na plataforma Finance Organizer
  Quero cadastrar novas contas ou carteiras financeiras
  Para que eu possa organizar meus recursos financeiros e registrar movimentacoes

  Background:
    * url baseUrl
    * def accountsPath = '/api/v1/accounts/'
    * def accountResponseSchema = read('classpath:data/schemas/accounts/account-response-schema.json')
    * def validationErrorSchema = read('classpath:data/schemas/auth/validation-error-schema.json')
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-ACC-01 - Criacao bem-sucedida de conta com apelido valido
    # 1. Provisiona contexto de usuario isolado
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 2. Cria conta com apelido valido
    Given path accountsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/accounts/account-create-request.json')
    * set payload.apelido = 'Nubank'
    And request payload
    When method post
    Then status 201
    And match response == accountResponseSchema
    And match response.apelido == 'Nubank'
    And match response.user_id == auth.userId
    And match response.saldo_calculado == '0.00'

  @boundaries @happy_path
  Scenario Outline: SCEN-ACC-02-03 - Criacao de conta nos limites de caracteres (<descricao>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/accounts/account-create-request.json')
    * set payload.apelido = '<apelido_teste>'
    And request payload
    When method post
    Then status 201
    And match response == accountResponseSchema
    And match response.apelido == '<apelido_teste>'
    And match response.user_id == auth.userId
    And match response.saldo_calculado == '0.00'

    Examples:
      | descricao                | apelido_teste                                                                                        |
      | limite mínimo (1 char)   | C                                                                                                    |
      | limite máximo (100 chars)| Carteira_de_Investimentos_Internacionais_Renda_Fixa_e_Acoes_Globais_Multimercado_High_Yield_100char |

  @boundaries @negative
  Scenario Outline: SCEN-ACC-04-05 - Rejeicao de conta com apelido fora dos limites permitidos (<motivo>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/accounts/account-create-request.json')
    * set payload.apelido = '<apelido_invalido>'
    And request payload
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { loc: '#[]', msg: '#string', type: '#string' }

    Examples:
      | motivo                     | apelido_invalido                                                                                      |
      | string vazia (0 chars)     |                                                                                                       |
      | acima do limite (101 chars)| Carteira_de_Investimentos_Internacionais_Renda_Fixa_e_Acoes_Globais_Multimercado_High_Yield_101charsX|

  @validation @negative
  Scenario Outline: SCEN-ACC-06 - Rejeicao por ausencia ou nulidade do campo apelido (<cenario>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request <payload>
    When method post
    Then status 422
    And match response == validationErrorSchema

    Examples:
      | cenario       | payload              |
      | campo ausente | {}                   |
      | valor nulo    | { "apelido": null }  |

  @validation @negative
  Scenario Outline: SCEN-ACC-07 - Rejeicao de apelido com tipos de dados invalidos (<tipo_invalido>)
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    And request <payload>
    When method post
    Then status 422
    And match response == validationErrorSchema
    And match each response.detail contains { msg: '#string', type: '#string' }

    Examples:
      | tipo_invalido | payload                               |
      | inteiro       | { "apelido": 98765 }                  |
      | boolean       | { "apelido": true }                   |
      | array         | { "apelido": ["Nubank"] }             |
      | objeto        | { "apelido": { "nome": "Nubank" } }   |

  @security @data_integrity
  Scenario: SCEN-ACC-08 - Bloqueio e sanitizacao de Mass Assignment em campos somente leitura
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    Given path accountsPath
    And header Authorization = auth.authHeader
    * def payload =
      """
      {
        "apelido": "Carteira Sanitizada",
        "saldo_calculado": "999999.00",
        "user_id": "00000000-0000-0000-0000-000000000000",
        "id": "11111111-1111-1111-1111-111111111111"
      }
      """
    And request payload
    When method post
    Then status 201
    And match response.saldo_calculado == '0.00'
    And match response.user_id == auth.userId
    And match response.id != '11111111-1111-1111-1111-111111111111'


  @security @negative
  Scenario Outline: SCEN-ACC-09 - Tentativa de criacao de conta sem autenticacao (<condicao_auth>)
    Given path accountsPath
    And header Authorization = '<header_val>'
    * def payload = read('classpath:data/payloads/accounts/account-create-request.json')
    * set payload.apelido = 'Carteira Nao Autorizada'
    And request payload
    When method post
    Then status 401
    And match response.id == '#notpresent'

    Examples:
      | condicao_auth       | header_val              |
      | cabeçalho ausente   |                         |
      | token inválido      | Bearer token_falso_1234 |
      | esquema não bearer  | Basic dXNlcjpwYXNz      |
