@investments @create
Feature: Gestão de Investimentos - Registo de Posições (POST /api/v1/investments/)

  Background:
    * url baseUrl
    * def investmentsPath = '/api/v1/investments/'
    * def investmentResponseSchema = read('classpath:data/schemas/investments/investment-response-schema.json')
    * def basePayload = read('classpath:data/payloads/investments/investment-create-request.json')
    * def makeString = function(len) { var s = ''; for (var i = 0; i < len; i++) s += 'X'; return s; }
    * configure retry = { count: 12, interval: 10000 }

  @smoke @happy_path
  Scenario: SCEN-INV-01 - Registo bem-sucedido de ativo em acoes com rentabilidade positiva
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'PETR' + java.util.UUID.randomUUID().toString().substring(0, 4).toUpperCase()
    * set payload.nome = 'Petrobras PN'
    * set payload.classe = 'ACOES'
    * set payload.quantidade = '100.0'
    * set payload.preco_medio = '30.00'
    * set payload.cotacao_atual = '36.00'
    And request payload
    When method post
    Then status 201
    And match response == investmentResponseSchema
    And match response.ticker == payload.ticker
    And match response.nome == payload.nome
    And match response.classe == 'ACOES'
    And match response.user_id == auth.userId
    * def totalEsperado = 100.0 * 30.00
    * def patrimonioEsperado = 100.0 * 36.00
    * def lucroEsperado = patrimonioEsperado - totalEsperado
    * def rentabilidadeEsperada = (lucroEsperado / totalEsperado) * 100.0
    * assert Math.abs(parseFloat(response.total_investido) - totalEsperado) < 0.01
    * assert Math.abs(parseFloat(response.patrimonio_atual) - patrimonioEsperado) < 0.01
    * assert Math.abs(parseFloat(response.lucro_prejuizo_absoluto) - lucroEsperado) < 0.01
    * assert Math.abs(parseFloat(response.rentabilidade_percentual) - rentabilidadeEsperada) < 0.05

  @happy_path @parameterized
  Scenario Outline: SCEN-INV-02 - Cadastro de investimento na classe de ativo <classe>
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = '<ticker>' + java.util.UUID.randomUUID().toString().substring(0, 3).toUpperCase()
    * set payload.nome = '<nome>'
    * set payload.classe = '<classe>'
    * set payload.quantidade = '<quantidade>'
    * set payload.preco_medio = '<preco_medio>'
    * set payload.cotacao_atual = '<cotacao_atual>'
    And request payload
    When method post
    Then status 201
    And match response == investmentResponseSchema
    And match response.classe == '<classe>'
    * assert Math.abs(parseFloat(response.total_investido) - parseFloat('<total_esperado>')) < 0.05
    * assert Math.abs(parseFloat(response.patrimonio_atual) - parseFloat('<patrimonio_esperado>')) < 0.05

    Examples:
      | classe            | ticker | nome                      | quantidade | preco_medio | cotacao_atual | total_esperado | patrimonio_esperado |
      | ACOES             | VALE   | Vale SA                   | 50.0       | 60.00       | 65.00         | 3000.00        | 3250.00             |
      | FIIS              | HGLG   | CSHG Logistica            | 10.0       | 160.00      | 165.00        | 1600.00        | 1650.00             |
      | RENDA_FIXA        | CDB    | CDB Pos-Fixado 100 CDI    | 1.0        | 5000.00     | 5200.00       | 5000.00        | 5200.00             |
      | CRIPTO            | BTC    | Bitcoin                   | 0.05       | 300000.00   | 350000.00     | 15000.00       | 17500.00            |
      | ETF               | BOVA   | iShares Ibovespa ETF      | 20.0       | 115.00      | 120.00        | 2300.00        | 2400.00             |
      | RENDA_EMERGENCIAL | NUBK   | Reserva Emergencia NuBank | 1.0        | 1000.00     | 1000.00       | 1000.00        | 1000.00             |

  @boundary @precision
  Scenario: SCEN-INV-03 - Cadastro de criptoativo com alta precisao decimal em quantidade fracionaria
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'ETH' + java.util.UUID.randomUUID().toString().substring(0, 3).toUpperCase()
    * set payload.nome = 'Ethereum'
    * set payload.classe = 'CRIPTO'
    * set payload.quantidade = '0.00452180'
    * set payload.preco_medio = '18500.25'
    * set payload.cotacao_atual = '21200.75'
    And request payload
    When method post
    Then status 201
    And match response == investmentResponseSchema
    * def qtd = 0.00452180
    * def totalCalc = qtd * 18500.25
    * def patrimonioCalc = qtd * 21200.75
    * def lucroCalc = patrimonioCalc - totalCalc
    * def rentabilidadeCalc = (lucroCalc / totalCalc) * 100.0
    * assert Math.abs(parseFloat(response.total_investido) - totalCalc) < 0.05
    * assert Math.abs(parseFloat(response.patrimonio_atual) - patrimonioCalc) < 0.05
    * assert Math.abs(parseFloat(response.lucro_prejuizo_absoluto) - lucroCalc) < 0.05
    * assert Math.abs(parseFloat(response.rentabilidade_percentual) - rentabilidadeCalc) < 0.05

  @financial @edge_case
  Scenario: SCEN-INV-04 - Variacao de lucro/prejuizo nominal e percentual
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 1. Rentabilidade nula
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p1 = read('classpath:data/payloads/investments/investment-create-request.json')
    * set p1.ticker = 'TK_NUL' + java.util.UUID.randomUUID().toString().substring(0, 3).toUpperCase()
    * set p1.nome = 'Ativo Teste Nula'
    * set p1.classe = 'ACOES'
    * set p1.quantidade = '10.0'
    * set p1.preco_medio = '50.00'
    * set p1.cotacao_atual = '50.00'
    And request p1
    When method post
    Then status 201
    And match response == investmentResponseSchema
    * assert Math.abs(parseFloat(response.lucro_prejuizo_absoluto) - 0.00) < 0.05
    * assert Math.abs(parseFloat(response.rentabilidade_percentual) - 0.00) < 0.05

    # 2. Prejuizo moderado (-20%)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p2 = read('classpath:data/payloads/investments/investment-create-request.json')
    * set p2.ticker = 'TK_PRJ' + java.util.UUID.randomUUID().toString().substring(0, 3).toUpperCase()
    * set p2.nome = 'Ativo Teste Prejuizo'
    * set p2.classe = 'ACOES'
    * set p2.quantidade = '10.0'
    * set p2.preco_medio = '100.00'
    * set p2.cotacao_atual = '80.00'
    And request p2
    When method post
    Then status 201
    And match response == investmentResponseSchema
    * assert Math.abs(parseFloat(response.lucro_prejuizo_absoluto) - (-200.00)) < 0.05
    * assert Math.abs(parseFloat(response.rentabilidade_percentual) - (-20.00)) < 0.05

    # 3. Queda severa (-90%)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p3 = read('classpath:data/payloads/investments/investment-create-request.json')
    * set p3.ticker = 'TK_SEV' + java.util.UUID.randomUUID().toString().substring(0, 3).toUpperCase()
    * set p3.nome = 'Ativo Teste Queda Severa'
    * set p3.classe = 'ACOES'
    * set p3.quantidade = '10.0'
    * set p3.preco_medio = '100.00'
    * set p3.cotacao_atual = '10.00'
    And request p3
    When method post
    Then status 201
    And match response == investmentResponseSchema
    * assert Math.abs(parseFloat(response.lucro_prejuizo_absoluto) - (-900.00)) < 0.05
    * assert Math.abs(parseFloat(response.rentabilidade_percentual) - (-90.00)) < 0.05

  @boundary @validation
  Scenario: SCEN-INV-05 - Validacao de limites de tamanho para ticker e nome
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # Ticker minimo de 1 caractere (201)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'A'
    * set payload.nome = 'Nome Valido'
    And request payload
    When method post
    Then status 201

    # Ticker maximo de 20 caracteres (201)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = makeString(20)
    * set payload.nome = 'Nome Valido'
    And request payload
    When method post
    Then status 201

    # Nome minimo de 1 caractere (201)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'TK_MIN_NM'
    * set payload.nome = 'A'
    And request payload
    When method post
    Then status 201

    # Nome maximo de 255 caracteres (201)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'TK_MAX_NM'
    * set payload.nome = makeString(255)
    And request payload
    When method post
    Then status 201

    # Ticker vazio - tamanho 0 (422)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = ''
    * set payload.nome = 'Nome Valido'
    And request payload
    When method post
    Then status 422

    # Ticker excede 20 caracteres - tamanho 21 (422)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = makeString(21)
    * set payload.nome = 'Nome Valido'
    And request payload
    When method post
    Then status 422

    # Nome vazio - tamanho 0 (422)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'TK_VLD1'
    * set payload.nome = ''
    And request payload
    When method post
    Then status 422

    # Nome excede 255 caracteres - tamanho 256 (422)
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'TK_VLD2'
    * set payload.nome = makeString(256)
    And request payload
    When method post
    Then status 422

  @negative @contract
  Scenario: SCEN-INV-06 - Rejeicao por omissao de campo obrigatorio
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 1. Sem ticker
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p1 = read('classpath:data/payloads/investments/investment-create-request.json')
    * karate.remove('p1', 'ticker')
    And request p1
    When method post
    Then status 422

    # 2. Sem nome
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p2 = read('classpath:data/payloads/investments/investment-create-request.json')
    * karate.remove('p2', 'nome')
    And request p2
    When method post
    Then status 422

    # 3. Sem classe
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p3 = read('classpath:data/payloads/investments/investment-create-request.json')
    * karate.remove('p3', 'classe')
    And request p3
    When method post
    Then status 422

    # 4. Sem quantidade
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p4 = read('classpath:data/payloads/investments/investment-create-request.json')
    * karate.remove('p4', 'quantidade')
    And request p4
    When method post
    Then status 422

    # 5. Sem preco_medio
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p5 = read('classpath:data/payloads/investments/investment-create-request.json')
    * karate.remove('p5', 'preco_medio')
    And request p5
    When method post
    Then status 422

    # 6. Sem cotacao_atual
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p6 = read('classpath:data/payloads/investments/investment-create-request.json')
    * karate.remove('p6', 'cotacao_atual')
    And request p6
    When method post
    Then status 422

  @negative @contract
  Scenario: SCEN-INV-07 - Rejeicao ao cadastrar ativo com classe inexistente no enum
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.classe = 'DERIVATIVOS_INVALIDOS'
    And request payload
    When method post
    Then status 422

  @negative @boundary
  Scenario: SCEN-INV-08 - Rejeicao de valores numericos que violam os limites contratuais
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

    # 1. Quantidade zero
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p1 = read('classpath:data/payloads/investments/investment-create-request.json')
    * set p1.quantidade = 0.0
    And request p1
    When method post
    Then status 422

    # 2. Quantidade negativa
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p2 = read('classpath:data/payloads/investments/investment-create-request.json')
    * set p2.quantidade = -5.0
    And request p2
    When method post
    Then status 422

    # 3. Preco medio negativo
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p3 = read('classpath:data/payloads/investments/investment-create-request.json')
    * set p3.preco_medio = -1.00
    And request p3
    When method post
    Then status 422

    # 4. Cotacao atual negativa
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p4 = read('classpath:data/payloads/investments/investment-create-request.json')
    * set p4.cotacao_atual = -0.01
    And request p4
    When method post
    Then status 422

    # 5. Quantidade nao-numérica
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def p5 = read('classpath:data/payloads/investments/investment-create-request.json')
    * set p5.quantidade = 'dez'
    And request p5
    When method post
    Then status 422

  @security @data_integrity
  Scenario: SCEN-INV-09 - Tentativa de forcar valores calculados e user_id arbitrario no POST
    * def auth = call read('classpath:features/helpers/auth-helper.feature')
    Given path investmentsPath
    And header Authorization = auth.authHeader
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'TK' + java.util.UUID.randomUUID().toString().substring(0, 4).toUpperCase()
    * set payload.nome = 'Teste Sanitizacao'
    * set payload.classe = 'ACOES'
    * set payload.quantidade = '10.0'
    * set payload.preco_medio = '20.00'
    * set payload.cotacao_atual = '25.00'
    * set payload.id = '00000000-0000-0000-0000-000000000000'
    * set payload.user_id = '99999999-9999-9999-9999-999999999999'
    * set payload.total_investido = '1.00'
    * set payload.patrimonio_atual = '999999.00'
    * set payload.lucro_prejuizo_absoluto = '999998.00'
    * set payload.rentabilidade_percentual = '99999.00'
    And request payload
    When method post
    Then status 201
    And match response.user_id == auth.userId
    And match response.id != '00000000-0000-0000-0000-000000000000'
    * assert Math.abs(parseFloat(response.total_investido) - 200.00) < 0.01
    * assert Math.abs(parseFloat(response.patrimonio_atual) - 250.00) < 0.01
    * assert Math.abs(parseFloat(response.lucro_prejuizo_absoluto) - 50.00) < 0.01

  @security @authentication
  Scenario Outline: SCEN-INV-10 - Rejeicao de registo sem credenciais validas (<condicao_auth>)
    Given path investmentsPath
    And header Authorization = '<header_auth>'
    * def payload = read('classpath:data/payloads/investments/investment-create-request.json')
    * set payload.ticker = 'TK' + java.util.UUID.randomUUID().toString().substring(0, 4).toUpperCase()
    And request payload
    When method post
    Then status 401

    Examples:
      | condicao_auth      | header_auth                     |
      | token ausente      |                                 |
      | token JWT invalido | Bearer token_falso_invalido_123 |
      | esquema nao-bearer | Basic dXNlcjpwYXNz              |
