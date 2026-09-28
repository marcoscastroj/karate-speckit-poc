# Feature Specification: Gestão de Portfólio de Investimentos (Investments API)

**Feature Branch**: `004-investments-portfolio`

**Created**: 2026-09-28

**Status**: Draft

**Input**: User description: "Gestão de Portfólio de Investimentos (Investments) - Matriz rigorosa de cenários de testes de API cobrindo operações de custódia de ativos, enums de classes, validações numéricas e de limites de campos, cálculos derivados de rentabilidade/património, agregação consolidada de portfólio e isolamento estrito entre utilizadores (multi-tenancy)."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registo de Posições de Investimento (`POST /api/v1/investments/`) (Priority: P1) 🎯 MVP

Como um investidor autenticado na plataforma Finance Organizer,  
Quero registrar uma nova posição de custódia de ativo (ações, FIIs, renda fixa, criptomoedas, ETFs ou reserva de emergência),  
Para que a plataforma armazene a posição e calcule de forma imediata o total investido, o patrimônio atual, o lucro/prejuízo nominal e o percentual de rentabilidade da posição.

**Why this priority**: O cadastro de ativos é a fundação de todo o módulo de investimentos. Sem a capacidade de registrar e calcular os saldos de custódia, os serviços de listagem e consolidação de carteira não têm utilidade.

**Independent Test**: Provisionar um novo usuário via helper de autenticação, enviar uma requisição `POST /api/v1/investments/` com carga válida, validar a resposta `201 Created` contra o schema `InvestmentResponse` e verificar que todas as métricas derivadas (`total_investido`, `patrimonio_atual`, `lucro_prejuizo_absoluto`, `rentabilidade_percentual`) foram computadas com exatidão matemática.

**Acceptance Scenarios**:

#### SCEN-INV-01: Registo bem-sucedido de ativo com lucro positivo e métricas derivadas
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Happy Path / Business Rule
```gherkin
Scenario: SCEN-INV-01 - Registo bem-sucedido de ativo em ações com rentabilidade positiva
  Given um usuário devidamente autenticado na API
  And um payload de criação de investimento com:
    | campo         | valor              |
    | ticker        | "PETR4"            |
    | nome          | "Petrobras PN"     |
    | classe        | "ACOES"            |
    | quantidade    | "100.0"            |
    | preco_medio   | "30.00"            |
    | cotacao_atual | "36.00"            |
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 201
  And o corpo da resposta deve validar estritamente o schema InvestmentResponse:
    | campo                    | tipo   | validação / expectativa                              |
    | id                       | string | formato UUID v4 válido                                |
    | user_id                  | string | idêntico ao identificador do usuário autenticado     |
    | ticker                   | string | "PETR4"                                              |
    | nome                     | string | "Petrobras PN"                                       |
    | classe                   | string | "ACOES"                                              |
    | quantidade               | string | "100.0"                                              |
    | preco_medio              | string | "30.00"                                              |
    | cotacao_atual            | string | "36.00"                                              |
    | total_investido          | string | "3000.00" (100.0 * 30.00)                            |
    | patrimonio_atual         | string | "3600.00" (100.0 * 36.00)                            |
    | lucro_prejuizo_absoluto  | string | "600.00" (3600.00 - 3000.00)                         |
    | rentabilidade_percentual | string | "20.00" ((600.00 / 3000.00) * 100)                   |
    | created_at               | string | formato ISO 8601 (date-time)                          |
    | updated_at               | string | formato ISO 8601 (date-time)                          |
```

#### SCEN-INV-02: Registo parametrizado de ativos em todas as classes suportadas (`InvestmentClass`)
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Happy Path / Parameterized
```gherkin
Scenario Outline: SCEN-INV-02 - Cadastro de investimento na classe de ativo <classe>
  Given um usuário devidamente autenticado na API
  And um payload de criação com ticker "<ticker>", nome "<nome>", classe "<classe>", quantidade "<quantidade>", preco_medio "<preco_medio>" e cotacao_atual "<cotacao_atual>"
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 201
  And o campo "classe" na resposta deve ser "<classe>"
  And o campo "total_investido" deve corresponder a "<total_esperado>"
  And o campo "patrimonio_atual" deve corresponder a "<patrimonio_esperado>"

  Examples:
    | classe            | ticker    | nome                      | quantidade | preco_medio | cotacao_atual | total_esperado | patrimonio_esperado |
    | ACOES             | VALE3     | Vale SA                   | 50.0       | 60.00       | 65.00         | 3000.00        | 3250.00             |
    | FIIS              | HGLG11    | CSHG Logística            | 10.0       | 160.00      | 165.00        | 1600.00        | 1650.00             |
    | RENDA_FIXA        | CDB-INTER | CDB Pós-Fixado 100% CDI   | 1.0        | 5000.00     | 5200.00       | 5000.00        | 5200.00             |
    | CRIPTO            | BTC       | Bitcoin                   | 0.05       | 300000.00   | 350000.00     | 15000.00       | 17500.00            |
    | ETF               | BOVA11    | iShares Ibovespa ETF      | 20.0       | 115.00      | 120.00        | 2300.00        | 2400.00             |
    | RENDA_EMERGENCIAL | RES-NUBK  | Reserva Emergência NuBank | 1.0        | 1000.00     | 1000.00       | 1000.00        | 1000.00             |
```

#### SCEN-INV-03: Suporte a fracionamento com múltiplas casas decimais (Criptoativos)
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Boundary / Precision
```gherkin
Scenario: SCEN-INV-03 - Cadastro de criptoativo com alta precisão decimal em quantidade fracionária
  Given um usuário devidamente autenticado na API
  And um payload de criação com:
    | campo         | valor              |
    | ticker        | "ETH"              |
    | nome          | "Ethereum"         |
    | classe        | "CRIPTO"           |
    | quantidade    | "0.00452180"       |
    | preco_medio   | "18500.25"         |
    | cotacao_atual | "21200.75"         |
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 201
  And os campos "total_investido", "patrimonio_atual" e "lucro_prejuizo_absoluto" devem refletir a multiplicação de ponto flutuante sem perda de precisão
  And o campo "rentabilidade_percentual" deve ser aproximadamente "14.59"
```

#### SCEN-INV-04: Recálculo de rentabilidade nula (empate) e rentabilidade negativa (prejuízo)
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Business Rule / Financial Edge Case
```gherkin
Scenario Outline: SCEN-INV-04 - Variação de lucro/prejuízo nominal e percentual (<cenario>)
  Given um usuário devidamente autenticado na API
  And um payload de investimento com preco_medio "<preco_medio>" e cotacao_atual "<cotacao_atual>" para quantidade "10"
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 201
  And o campo "lucro_prejuizo_absoluto" deve ser "<lucro_esperado>"
  And o campo "rentabilidade_percentual" deve ser "<rentabilidade_esperada>"

  Examples:
    | cenario                  | preco_medio | cotacao_atual | lucro_esperado | rentabilidade_esperada |
    | Rentabilidade nula       | 50.00       | 50.00         | 0.00           | 0.00                   |
    | Prejuízo moderado (-20%) | 100.00      | 80.00         | -200.00        | -20.00                 |
    | Queda severa (-90%)      | 100.00      | 10.00         | -900.00        | -90.00                 |
```

#### SCEN-INV-05: Validações de limites de caracteres em ticker e nome
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Contract / Boundary Validation
```gherkin
Scenario Outline: SCEN-INV-05 - Validação de tamanho de string para ticker e nome (<cenario>)
  Given um usuário devidamente autenticado na API
  And um payload com ticker de tamanho <len_ticker> e nome de tamanho <len_nome>
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser <status_esperado>

  Examples:
    | cenario                           | len_ticker | len_nome | status_esperado |
    | Ticker mínimo de 1 caractere      | 1          | 10       | 201             |
    | Ticker máximo de 20 caracteres    | 20         | 50       | 201             |
    | Nome mínimo de 1 caractere        | 5          | 1        | 201             |
    | Nome máximo de 255 caracteres     | 5          | 255      | 201             |
    | Ticker vazio (tamanho 0)          | 0          | 20       | 422             |
    | Ticker excede 20 caracteres (21)  | 21         | 20       | 422             |
    | Nome vazio (tamanho 0)            | 5          | 0        | 422             |
    | Nome excede 255 caracteres (256)  | 5          | 256      | 422             |
```

#### SCEN-INV-06: Omissão de campos obrigatórios no registo
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Contract / Missing Fields (422)
```gherkin
Scenario Outline: SCEN-INV-06 - Rejeição por omissão de campo obrigatório (<campo_ausente>)
  Given um usuário devidamente autenticado na API
  And um payload de investimento sem o campo obrigatório "<campo_ausente>"
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 422
  And o corpo de resposta deve conter indicação de erro para o campo "<campo_ausente>"

  Examples:
    | campo_ausente |
    | ticker        |
    | nome          |
    | classe        |
    | quantidade    |
    | preco_medio   |
    | cotacao_atual |
```

#### SCEN-INV-07: Rejeição de classe inexistente ou fora do enum
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Contract / Invalid Enum (422)
```gherkin
Scenario: SCEN-INV-07 - Rejeição ao cadastrar ativo com classe inválida
  Given um usuário devidamente autenticado na API
  And um payload de investimento com classe "DERIVATIVOS_INVALIDOS"
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 422
  And o corpo de erro deve detalhar que a classe não pertence aos valores permitidos de InvestmentClass
```

#### SCEN-INV-08: Rejeição de valores numéricos que violam os limites contratuais
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Boundary / Numeric Constraints (422)
```gherkin
Scenario Outline: SCEN-INV-08 - Rejeição de valores numéricos inválidos (<cenario>)
  Given um usuário devidamente autenticado na API
  And um payload de investimento com quantidade "<quantidade>", preco_medio "<preco_medio>" e cotacao_atual "<cotacao_atual>"
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 422
  And o corpo de resposta deve detalhar a violação no campo "<campo_invalido>"

  Examples:
    | cenario                     | quantidade | preco_medio | cotacao_atual | campo_invalido |
    | Quantidade zero             | 0.0        | 50.00       | 50.00         | quantidade     |
    | Quantidade negativa         | -5.0       | 50.00       | 50.00         | quantidade     |
    | Preço médio negativo        | 10.0       | -1.00       | 50.00         | preco_medio    |
    | Cotação atual negativa      | 10.0       | 50.00       | -0.01         | cotacao_atual  |
    | Quantidade string não-num   | "dez"      | 50.00       | 50.00         | quantidade     |
```

#### SCEN-INV-09: Sanitização contra injeção de campos read-only e dados de terceiros
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Security / Data Integrity
```gherkin
Scenario: SCEN-INV-09 - Tentativa de forçar valores calculados e user_id arbitrário no POST
  Given um usuário devidamente autenticado com id "USR-ORIGINAL"
  And um payload malicioso contendo:
    | campo                    | valor forçado                          |
    | id                       | "00000000-0000-0000-0000-000000000000" |
    | user_id                  | "99999999-9999-9999-9999-999999999999" |
    | total_investido          | "1.00"                                 |
    | patrimonio_atual         | "999999.00"                            |
    | lucro_prejuizo_absoluto  | "999998.00"                            |
    | rentabilidade_percentual | "99999.00"                             |
    | ticker                   | "TEST3"                                |
    | nome                     | "Teste Sanitização"                    |
    | classe                   | "ACOES"                                |
    | quantidade               | "10.0"                                 |
    | preco_medio              | "20.00"                                |
    | cotacao_atual            | "25.00"                                |
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 201
  And o campo "user_id" na resposta deve ser o do usuário autenticado no token, ignorando a injeção
  And o campo "id" deve ser gerado pelo sistema e diferente do valor forçado
  And o campo "total_investido" deve ser calculado como "200.00"
  And o campo "patrimonio_atual" deve ser calculado como "250.00"
  And o campo "lucro_prejuizo_absoluto" deve ser "50.00"
```

#### SCEN-INV-10: Bloqueio de chamada não autenticada no registo
- **Endpoint**: `POST /api/v1/investments/`
- **Categoria**: Security / Authentication (401)
```gherkin
Scenario Outline: SCEN-INV-10 - Rejeição de registo sem credenciais válidas (<condicao_auth>)
  Given uma requisição sem autenticação ou com credencial inválida (<condicao_auth>)
  And um payload válido de investimento
  When o cliente envia uma requisição POST para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 401
  And o corpo de resposta deve conter a mensagem de recusa de autorização

  Examples:
    | condicao_auth            |
    | ausência de token        |
    | token JWT expirado       |
    | token malformado         |
```

---

### User Story 2 - Métricas Consolidadas do Portfólio (`GET /api/v1/investments/summary`) (Priority: P1) 🎯 MVP

Como um investidor autenticado,  
Quero obter um resumo consolidado de todo o meu patrimônio alocado em investimentos,  
Para que eu acompanhe o valor total de patrimônio, o custo total de aquisição, o ganho ou perda acumulada e a distribuição percentual da minha carteira por classe de ativo.

**Why this priority**: A consolidação da carteira é a visão analítica essencial para qualquer investidor. Sem esta agregação, o usuário não consegue tomar decisões estratégicas nem balancear seus ativos.

**Independent Test**: Provisionar um usuário novo sem ativos e validar que `/summary` retorna zeros e lista de alocação vazia. Em seguida, cadastrar posições em 3 classes distintas e verificar se as somas, lucro consolidado e a soma dos percentuais (100%) batem com precisão.

**Acceptance Scenarios**:

#### SCEN-INV-11: Resumo de portfólio para usuário novo sem investimentos
- **Endpoint**: `GET /api/v1/investments/summary`
- **Categoria**: Happy Path / Zero State
```gherkin
Scenario: SCEN-INV-11 - Obtenção de métricas consolidadas de usuário com carteira vazia
  Given um novo usuário recém-criado sem qualquer ativo cadastrado
  When o cliente envia uma requisição GET para "/api/v1/investments/summary"
  Then o código de status HTTP retornado deve ser 200
  And o corpo da resposta deve validar estritamente o schema PortfolioSummaryResponse:
    | campo                    | valor / formato |
    | patrimonio_total         | "0.00"          |
    | total_investido          | "0.00"          |
    | lucro_prejuizo_absoluto  | "0.00"          |
    | rentabilidade_percentual | "0.00"          |
    | alocacao_por_classe      | [] (array vazio)|
```

#### SCEN-INV-12: Agregação global e distribuição por classes com múltiplos ativos
- **Endpoint**: `GET /api/v1/investments/summary`
- **Categoria**: Happy Path / Aggregation Logic
```gherkin
Scenario: SCEN-INV-12 - Consolidação exata de patrimônio e alocação por classe
  Given um usuário autenticado com os seguintes ativos em custódia:
    | ticker | classe     | quantidade | preco_medio | cotacao_atual | total_investido | patrimonio_atual |
    | ITUB4  | ACOES      | 100        | 30.00       | 40.00         | 3000.00         | 4000.00          |
    | KNRI11 | FIIS       | 20         | 150.00      | 150.00        | 3000.00         | 3000.00          |
    | CDB01  | RENDA_FIXA | 1          | 3000.00     | 3000.00       | 3000.00         | 3000.00          |
  When o cliente envia uma requisição GET para "/api/v1/investments/summary"
  Then o código de status HTTP retornado deve ser 200
  And as métricas globais consolidadas devem ser:
    | métrica                  | valor esperado | fórmula de validação                             |
    | total_investido          | "9000.00"      | 3000 + 3000 + 3000                               |
    | patrimonio_total         | "10000.00"     | 4000 + 3000 + 3000                               |
    | lucro_prejuizo_absoluto  | "1000.00"      | 10000.00 - 9000.00                               |
    | rentabilidade_percentual | "11.11"        | ((10000.00 - 9000.00) / 9000.00) * 100           |
  And o array "alocacao_por_classe" deve conter 3 itens com as distribuições:
    | classe     | patrimonio_total | total_investido | percentual_carteira |
    | ACOES      | "4000.00"        | "3000.00"       | "40.00"             |
    | FIIS       | "3000.00"        | "3000.00"       | "30.00"             |
    | RENDA_FIXA | "3000.00"        | "3000.00"       | "30.00"             |
```

#### SCEN-INV-13: Verificação de completude da carteira (soma de percentuais = 100%)
- **Endpoint**: `GET /api/v1/investments/summary`
- **Categoria**: Business Rule / Mathematical Invariant
```gherkin
Scenario: SCEN-INV-13 - A soma das fatias de alocação por classe deve totalizar 100%
  Given um usuário autenticado com múltiplos ativos cadastrados em diferentes classes
  When o cliente envia uma requisição GET para "/api/v1/investments/summary"
  Then o código de status retornado deve ser 200
  And a soma do campo "percentual_carteira" de todos os elementos em "alocacao_por_classe" deve ser igual a 100.00 (com tolerância máxima de arredondamento de +-0.05)
```

#### SCEN-INV-14: Isolamento rigoroso de multi-tenancy no cálculo de métricas consolidadas
- **Endpoint**: `GET /api/v1/investments/summary`
- **Categoria**: Security / Multi-Tenancy Isolation
```gherkin
Scenario: SCEN-INV-14 - Ativos de outros usuários não podem interferir no resumo consolidado
  Given um usuário "A" com ativo em "ACOES" com patrimonio_atual de "50000.00"
  And um usuário "B" com ativo em "CRIPTO" com patrimonio_atual de "2000.00"
  When o usuário "B" envia uma requisição GET para "/api/v1/investments/summary"
  Then o código de status HTTP retornado deve ser 200
  And o "patrimonio_total" do usuário "B" deve ser estritamente "2000.00"
  And o array "alocacao_por_classe" do usuário "B" deve conter apenas "CRIPTO" com 100.00%
  And nenhum dado de "ACOES" do usuário "A" deve constar na resposta do usuário "B"
```

#### SCEN-INV-15: Rejeição de resumo sem autenticação
- **Endpoint**: `GET /api/v1/investments/summary`
- **Categoria**: Security / Authentication (401)
```gherkin
Scenario: SCEN-INV-15 - Consulta de métricas consolidadas sem cabeçalho Authorization
  Given uma requisição sem credenciais de autenticação
  When o cliente envia uma requisição GET para "/api/v1/investments/summary"
  Then o código de status retornado deve ser 401
```

---

### User Story 3 - Listagem Paginada e Filtrada de Investimentos (`GET /api/v1/investments/`) (Priority: P2)

Como um investidor autenticado,  
Quero listar minhas posições custodiadas com suporte a paginação e filtro por classe de ativo,  
Para que eu possa inspecionar organizadamente meus ativos e focar na análise de segmentos específicos de mercado.

**Why this priority**: Uma carteira de investimentos pode acumular dezenas de posições. A listagem paginada e filtrada previne sobrecarga de rede e viabiliza a navegação focada por classes.

**Independent Test**: Cadastrar 5 ativos de classes variadas para um usuário e verificar que o filtro `classe=ACOES` retorna apenas ações, enquanto `skip` e `limit` fatiam a lista com precisão.

**Acceptance Scenarios**:

#### SCEN-INV-16: Listagem geral de posições exclusivas do usuário logado
- **Endpoint**: `GET /api/v1/investments/`
- **Categoria**: Happy Path / Data Isolation
```gherkin
Scenario: SCEN-INV-16 - Listagem de investimentos pertencentes unicamente ao usuário autenticado
  Given um usuário "A" com 2 ativos cadastrados
  And um usuário "B" com 3 ativos cadastrados
  When o usuário "A" envia uma requisição GET para "/api/v1/investments/"
  Then o código de status HTTP retornado deve ser 200
  And a lista retornada deve conter exatamente 2 registros
  And o campo "user_id" de todos os registros retornados deve coincidir com o ID do usuário "A"
```

#### SCEN-INV-17: Filtragem de ativos por classe específica (`classe`)
- **Endpoint**: `GET /api/v1/investments/`
- **Categoria**: Happy Path / Filtering
```gherkin
Scenario Outline: SCEN-INV-17 - Filtrar listagem pela classe de investimento <classe_filtro>
  Given um usuário autenticado com posições cadastradas em classes diversificadas ("ACOES", "FIIS", "CRIPTO", "RENDA_FIXA")
  When o cliente envia uma requisição GET para "/api/v1/investments/" com query param "classe=<classe_filtro>"
  Then o código de status HTTP retornado deve ser 200
  And todos os itens da lista retornada devem possuir a propriedade "classe" igual a "<classe_filtro>"
  And nenhum ativo de classe diferente de "<classe_filtro>" deve estar presente na resposta

  Examples:
    | classe_filtro     |
    | ACOES             |
    | FIIS              |
    | RENDA_FIXA        |
    | CRIPTO            |
    | ETF               |
    | RENDA_EMERGENCIAL |
```

#### SCEN-INV-18: Paginação de investimentos com skip e limit
- **Endpoint**: `GET /api/v1/investments/`
- **Categoria**: Happy Path / Pagination
```gherkin
Scenario: SCEN-INV-18 - Paginação de posições utilizando skip e limit
  Given um usuário com 5 posições de investimento cadastradas ordenadas
  When o cliente envia uma requisição GET para "/api/v1/investments/?skip=0&limit=2"
  Then o código de status deve ser 200
  And a lista deve conter exatamente 2 registros (página 1)
  When o cliente envia uma requisição GET para "/api/v1/investments/?skip=2&limit=2"
  Then o código de status deve ser 200
  And a lista deve conter 2 registros distintos da página 1 (página 2)
  When o cliente envia uma requisição GET para "/api/v1/investments/?skip=4&limit=2"
  Then a lista deve conter 1 registro restante (página 3)
```

#### SCEN-INV-19: Rejeição de filtro com classe inválida
- **Endpoint**: `GET /api/v1/investments/`
- **Categoria**: Contract / Validation (422)
```gherkin
Scenario: SCEN-INV-19 - Erro ao passar valor desconhecido no parâmetro classe
  Given um usuário devidamente autenticado
  When o cliente envia uma requisição GET para "/api/v1/investments/?classe=POUPANCA"
  Then o código de status retornado deve ser 422
  And a resposta deve acusar que o parâmetro classe é inválido
```

#### SCEN-INV-20: Rejeição de limites de paginação fora do intervalo permitido
- **Endpoint**: `GET /api/v1/investments/`
- **Categoria**: Boundary / Validation (422)
```gherkin
Scenario Outline: SCEN-INV-20 - Violação de limites de paginação (<cenario>)
  Given um usuário devidamente autenticado
  When o cliente envia uma requisição GET para "/api/v1/investments/?skip=<skip>&limit=<limit>"
  Then o código de status retornado deve ser 422

  Examples:
    | cenario                   | skip | limit |
    | Skip negativo             | -1   | 10    |
    | Limit zero                | 0    | 0     |
    | Limit superior ao máximo  | 0    | 101   |
    | Limit negativo            | 0    | -5    |
```

#### SCEN-INV-21: Consulta não autenticada na listagem
- **Endpoint**: `GET /api/v1/investments/`
- **Categoria**: Security / Authentication (401)
```gherkin
Scenario: SCEN-INV-21 - Tentativa de listar investimentos sem credenciais
  Given uma chamada HTTP sem cabeçalho Authorization
  When o cliente envia uma requisição GET para "/api/v1/investments/"
  Then o código de status retornado deve ser 401
```

---

### User Story 4 - Consulta de Posição Específica por ID (`GET /api/v1/investments/{investment_id}`) (Priority: P2)

Como um investidor autenticado,  
Quero obter os detalhes de uma posição de investimento específica por meio de seu identificador UUID,  
Para que eu possa visualizar o histórico, cotação e métricas detalhadas daquele ativo.

**Why this priority**: A navegação detalhada por ativo é necessária para telas de visualização individual, conciliação e pré-condição para edição.

**Independent Test**: Criar um investimento, capturar seu ID, realizar o `GET /{id}` e conferir conformidade completa do schema `InvestmentResponse`. Testar com outro usuário e verificar que o acesso é negado (404/403).

**Acceptance Scenarios**:

#### SCEN-INV-22: Consulta bem-sucedida de ativo existente do próprio usuário
- **Endpoint**: `GET /api/v1/investments/{investment_id}`
- **Categoria**: Happy Path
```gherkin
Scenario: SCEN-INV-22 - Obtenção com sucesso de investimento existente próprio
  Given um usuário autenticado com uma posição cadastrada de ID "INV-01"
  When o cliente envia uma requisição GET para "/api/v1/investments/{INV-01}"
  Then o código de status HTTP retornado deve ser 200
  And o corpo da resposta deve validar o schema InvestmentResponse com id igual a "INV-01"
```

#### SCEN-INV-23: Bloqueio de acesso a investimento de outro usuário (Proteção IDOR)
- **Endpoint**: `GET /api/v1/investments/{investment_id}`
- **Categoria**: Security / IDOR Prevention
```gherkin
Scenario: SCEN-INV-23 - Usuário "A" tentando consultar investimento criado pelo usuário "B"
  Given um usuário "B" com investimento cadastrado de ID "INV-USER-B"
  And um usuário "A" devidamente autenticado com seu próprio token
  When o usuário "A" envia uma requisição GET para "/api/v1/investments/{INV-USER-B}"
  Then o código de status HTTP retornado deve ser 404 (Not Found) ou 403 (Forbidden)
  And nenhum dado financeiro do usuário "B" deve ser exposto ao usuário "A"
```

#### SCEN-INV-24: Consulta de identificador inexistente
- **Endpoint**: `GET /api/v1/investments/{investment_id}`
- **Categoria**: Negative / Not Found (404)
```gherkin
Scenario: SCEN-INV-24 - Consulta de investment_id inexistente no sistema
  Given um usuário devidamente autenticado
  When o cliente envia uma requisição GET para "/api/v1/investments/00000000-0000-0000-0000-000000000000"
  Then o código de status HTTP retornado deve ser 404
  And a mensagem de erro deve indicar que o investimento não foi encontrado
```

#### SCEN-INV-25: Rejeição de formato não-UUID no path parameter
- **Endpoint**: `GET /api/v1/investments/{investment_id}`
- **Categoria**: Contract / Validation (422)
```gherkin
Scenario Outline: SCEN-INV-25 - Rejeição de ID com formato inválido (<formato_id>)
  Given um usuário devidamente autenticado
  When o cliente envia uma requisição GET para "/api/v1/investments/<formato_id>"
  Then o código de status HTTP retornado deve ser 422
  And o detalhe do erro deve apontar violação de formato UUID no parâmetro investment_id

  Examples:
    | formato_id        |
    | 12345             |
    | id-invalido-abc   |
    | true              |
```

#### SCEN-INV-26: Consulta de detalhe sem autenticação
- **Endpoint**: `GET /api/v1/investments/{investment_id}`
- **Categoria**: Security / Authentication (401)
```gherkin
Scenario: SCEN-INV-26 - Consulta de detalhes de investimento sem token
  Given uma requisição sem token de autenticação
  When o cliente envia uma requisição GET para "/api/v1/investments/11111111-1111-1111-1111-111111111111"
  Then o código de status retornado deve ser 401
```

---

### User Story 5 - Atualização de Ativos e Recálculo Dinâmico (`PUT /api/v1/investments/{investment_id}`) (Priority: P2)

Como um investidor autenticado,  
Quero atualizar as propriedades de um investimento em custódia (como alteração de cotação atual, compra adicional alterando preço médio ou ajuste de quantidade),  
Para que o sistema reavalie instantaneamente o valor de mercado da posição, o resultado nominal, a rentabilidade percentual e o resumo global do portfólio.

**Why this priority**: Cotações de mercado e posições custodiadas variam continuamente. A atualização com recálculo consistente é vital para a precisão dos dados patrimoniais.

**Independent Test**: Cadastrar uma posição com `quantidade=10` e `cotacao_atual=100.00`. Executar `PUT` elevando a cotação para `150.00`, validar que o retorno `200 OK` recalcula `patrimonio_atual` para `1500.00` e consultar `/investments/summary` atestando que o valor total da carteira aumentou no montante exato.

**Acceptance Scenarios**:

#### SCEN-INV-27: Atualização de cotação atual com recálculo instantâneo de métricas
- **Endpoint**: `PUT /api/v1/investments/{investment_id}`
- **Categoria**: Happy Path / Dynamic Recalculation
```gherkin
Scenario: SCEN-INV-27 - Atualização de cotação atual gerando novo patrimônio e rentabilidade
  Given um usuário com um investimento ativo com:
    | campo         | valor original |
    | quantidade    | "50.0"         |
    | preco_medio   | "20.00"        |
    | cotacao_atual | "20.00"        |
  When o cliente envia uma requisição PUT para "/api/v1/investments/{id}" com:
    | campo         | novo valor |
    | cotacao_atual | "30.00"    |
  Then o código de status HTTP retornado deve ser 200
  And as métricas recalculadas na resposta devem ser:
    | métrica                  | valor esperado | fórmula                                  |
    | total_investido          | "1000.00"      | inalterado (50 * 20.00)                  |
    | patrimonio_atual         | "1500.00"      | recalculado (50 * 30.00)                 |
    | lucro_prejuizo_absoluto  | "500.00"       | 1500.00 - 1000.00                        |
    | rentabilidade_percentual | "50.00"        | ((1500.00 - 1000.00) / 1000.00) * 100    |
```

#### SCEN-INV-28: Atualização simultânea de quantidade e preço médio
- **Endpoint**: `PUT /api/v1/investments/{investment_id}`
- **Categoria**: Happy Path / Position Sizing
```gherkin
Scenario: SCEN-INV-28 - Atualização de aporte adicional ajustando quantidade e preço médio
  Given um usuário com investimento previamente registrado
  When o cliente envia uma requisição PUT com nova "quantidade"="100.0" e "preco_medio"="25.00"
  Then o código de status HTTP retornado deve ser 200
  And o campo "total_investido" deve ser atualizado para "2500.00"
```

#### SCEN-INV-29: Propagação imediata da atualização nas métricas consolidadas em /summary
- **Endpoint**: `PUT /api/v1/investments/{investment_id}` & `GET /api/v1/investments/summary`
- **Categoria**: Business Rule / Portfolio Consistency
```gherkin
Scenario: SCEN-INV-29 - Reflexo imediato do PUT na consolidação de /investments/summary
  Given um usuário com resumo consolidado inicial verificado
  When o cliente executa a atualização de cotação do seu ativo via PUT
  And envia em seguida uma requisição GET para "/api/v1/investments/summary"
  Then o código de status retornado deve ser 200
  And o "patrimonio_total" em /summary deve refletir exatamente o novo valor somado da posição
```

#### SCEN-INV-30: Rejeição de valores que violam limites na atualização
- **Endpoint**: `PUT /api/v1/investments/{investment_id}`
- **Categoria**: Boundary / Validation (422)
```gherkin
Scenario Outline: SCEN-INV-30 - Rejeição de dados inválidos no PUT (<cenario>)
  Given um usuário com investimento existente
  When o cliente envia uma requisição PUT atualizando com campo inválido (<campo>=<valor>)
  Then o código de status HTTP retornado deve ser 422

  Examples:
    | cenario                     | campo         | valor                                  |
    | Quantidade zero             | quantidade    | 0.0                                    |
    | Quantidade negativa         | quantidade    | -10.0                                  |
    | Preço médio negativo        | preco_medio   | -5.00                                  |
    | Cotação atual negativa      | cotacao_atual | -0.50                                  |
    | Ticker vazio                | ticker        | ""                                     |
    | Ticker acima de 20 chars    | ticker        | "TICKER_SUPER_LONGO_INVALIDO"          |
    | Nome acima de 255 chars     | nome          | [string com 256 caracteres]            |
```

#### SCEN-INV-31: Bloqueio de atualização em investimento de outro usuário (IDOR)
- **Endpoint**: `PUT /api/v1/investments/{investment_id}`
- **Categoria**: Security / IDOR Prevention
```gherkin
Scenario: SCEN-INV-31 - Tentativa de alterar investimento pertencente a outro usuário
  Given um ativo cadastrado pelo usuário "B" com ID "INV-USER-B"
  And o usuário "A" autenticado com suas próprias credenciais
  When o usuário "A" envia uma requisição PUT para "/api/v1/investments/{INV-USER-B}" com alteração de cotação
  Then o código de status HTTP retornado deve ser 404 ou 403
  And os dados do investimento do usuário "B" devem permanecer inalterados
```

#### SCEN-INV-32: Atualização de investimento com UUID inexistente
- **Endpoint**: `PUT /api/v1/investments/{investment_id}`
- **Categoria**: Negative / Not Found (404)
```gherkin
Scenario: SCEN-INV-32 - Atualização de investment_id inexistente
  Given um usuário devidamente autenticado
  When o cliente envia uma requisição PUT para "/api/v1/investments/00000000-0000-0000-0000-000000000000"
  Then o código de status retornado deve ser 404
```

#### SCEN-INV-33: Rejeição de identificador malformado na atualização
- **Endpoint**: `PUT /api/v1/investments/{investment_id}`
- **Categoria**: Contract / Validation (422)
```gherkin
Scenario: SCEN-INV-33 - Atualização com ID não-UUID
  Given um usuário devidamente autenticado
  When o cliente envia uma requisição PUT para "/api/v1/investments/abc-123"
  Then o código de status retornado deve ser 422
```

#### SCEN-INV-34: Atualização não autenticada
- **Endpoint**: `PUT /api/v1/investments/{investment_id}`
- **Categoria**: Security / Authentication (401)
```gherkin
Scenario: SCEN-INV-34 - Tentativa de atualização sem credenciais válidas
  Given uma requisição sem token no cabeçalho Authorization
  When o cliente envia uma requisição PUT para "/api/v1/investments/11111111-1111-1111-1111-111111111111"
  Then o código de status retornado deve ser 401
```

---

### User Story 6 - Encerramento de Custódia e Exclusão (`DELETE /api/v1/investments/{investment_id}`) (Priority: P3)

Como um investidor autenticado,  
Quero excluir uma posição de investimento da minha carteira de custódia,  
Para que ativos liquidados ou descontinuados sejam eliminados da minha listagem e deixem de impactar os totais patrimoniais e a alocação da carteira.

**Why this priority**: A exclusão/liquidação é a operação final do ciclo de vida de custódia. É necessária para manter a carteira limpa e compatível com a realidade patrimonial do usuário.

**Independent Test**: Cadastrar uma posição, conferir inclusão no `/investments/summary`, executar `DELETE /{id}`, validar `204 No Content`, verificar que o `GET /{id}` subsequente retorna `404 Not Found` e constatar que as métricas de `/summary` foram decrementadas no valor total do ativo.

**Acceptance Scenarios**:

#### SCEN-INV-35: Exclusão bem-sucedida de ativo próprio
- **Endpoint**: `DELETE /api/v1/investments/{investment_id}`
- **Categoria**: Happy Path (204 No Content)
```gherkin
Scenario: SCEN-INV-35 - Exclusão com sucesso de investimento próprio
  Given um usuário autenticado com uma posição cadastrada de ID "INV-DEL-01"
  When o cliente envia uma requisição DELETE para "/api/v1/investments/{INV-DEL-01}"
  Then o código de status HTTP retornado deve ser 204
  And o corpo da resposta deve ser vazio (No Content)
```

#### SCEN-INV-36: Verificação de remoção permanente da posição
- **Endpoint**: `GET /api/v1/investments/{investment_id}`
- **Categoria**: Post-Condition / Persistence Verification
```gherkin
Scenario: SCEN-INV-36 - Consulta do ativo após exclusão confirma remoção
  Given um ativo previamente excluído com sucesso via DELETE
  When o cliente envia uma requisição GET para "/api/v1/investments/{id_excluido}"
  Then o código de status HTTP retornado deve ser 404 (Not Found)
```

#### SCEN-INV-37: Recálculo imediato de /investments/summary após exclusão
- **Endpoint**: `DELETE /api/v1/investments/{investment_id}` & `GET /api/v1/investments/summary`
- **Categoria**: Business Rule / Financial Impact
```gherkin
Scenario: SCEN-INV-37 - Eliminação do impacto financeiro do ativo no resumo consolidado
  Given um usuário com 2 ativos totalizando "5000.00" de patrimônio total
  When o cliente envia uma requisição DELETE para o ativo cujo patrimônio era "2000.00"
  Then o código de status HTTP da exclusão deve ser 204
  When o cliente envia uma requisição GET para "/api/v1/investments/summary"
  Then o novo "patrimonio_total" consolidado deve ser exatamente "3000.00"
  And o "total_investido" deve ser decrementado no montante exato do ativo excluído
```

#### SCEN-INV-38: Bloqueio de exclusão em ativo de outro usuário (IDOR)
- **Endpoint**: `DELETE /api/v1/investments/{investment_id}`
- **Categoria**: Security / IDOR Prevention
```gherkin
Scenario: SCEN-INV-38 - Usuário "A" tentando excluir investimento pertencente ao usuário "B"
  Given um ativo cadastrado pelo usuário "B" com ID "INV-USER-B"
  And o usuário "A" autenticado com suas próprias credenciais
  When o usuário "A" envia uma requisição DELETE para "/api/v1/investments/{INV-USER-B}"
  Then o código de status HTTP retornado deve ser 404 ou 403
  When o usuário "B" consulta o ativo com seu próprio token
  Then o código de status deve ser 200 comprovando que o ativo permanece íntegro
```

#### SCEN-INV-39: Exclusão de identificador UUID inexistente
- **Endpoint**: `DELETE /api/v1/investments/{investment_id}`
- **Categoria**: Negative / Not Found (404)
```gherkin
Scenario: SCEN-INV-39 - Tentativa de exclusão de ID inexistente
  Given um usuário devidamente autenticado
  When o cliente envia uma requisição DELETE para "/api/v1/investments/00000000-0000-0000-0000-000000000000"
  Then o código de status retornado deve ser 404
```

#### SCEN-INV-40: Rejeição de formato não-UUID na exclusão
- **Endpoint**: `DELETE /api/v1/investments/{investment_id}`
- **Categoria**: Contract / Validation (422)
```gherkin
Scenario: SCEN-INV-40 - Tentativa de exclusão com ID malformado
  Given um usuário devidamente autenticado
  When o cliente envia uma requisição DELETE para "/api/v1/investments/invalido"
  Then o código de status retornado deve ser 422
```

#### SCEN-INV-41: Exclusão não autenticada
- **Endpoint**: `DELETE /api/v1/investments/{investment_id}`
- **Categoria**: Security / Authentication (401)
```gherkin
Scenario: SCEN-INV-41 - Tentativa de exclusão sem cabeçalho Authorization
  Given uma requisição sem credenciais válidas
  When o cliente envia uma requisição DELETE para "/api/v1/investments/11111111-1111-1111-1111-111111111111"
  Then o código de status retornado deve ser 401
```

---

### Edge Cases

- **Divisão por Zero na Rentabilidade Percentual**: Caso um ativo possua `preco_medio == 0.00` (ex: bonificação de ações ou recebimento por airdrop/doação), a fórmula `((patrimonio_atual - total_investido) / total_investido) * 100` não pode gerar exceção de runtime (`DivisionByZero`), devendo retornar `0.00` ou tratar a variação de modo seguro e padronizado.
- **Tolerância de Ponto Flutuante na Alocação da Carteira**: Na soma das parcelas de `percentual_carteira` das classes de ativos no consolidado `/summary`, arredondamentos decimais (`String/Decimal`) podem gerar somatórios como `99.99` ou `100.01`. As asserções de teste devem empregar tolerância estrita de até `+-0.05%` ou validação normalizada.
- **Fracionamento de Criptoativos com Casas Decimais Excessivas**: Criptoativos suportam até 8 casas decimais (ex: `0.00045218`). O sistema deve persistir e calcular o produto `quantidade * cotacao_atual` sem truncar prematuramente os dígitos decimais.
- **Empate Financeiro Perfeito (`preco_medio == cotacao_atual`)**: Deve resultar estritamente em `lucro_prejuizo_absoluto = "0.00"` e `rentabilidade_percentual = "0.00"`, sem caracteres anômalos ou `-0.00`.
- **Prejuízos Severos e Drawdowns Extremos**: Cenários de queda de 99% ou desvalorização para cotação `0.00` devem produzir `lucro_prejuizo_absoluto` negativo com sinal explícito (ex: `"-1000.00"`) e `rentabilidade_percentual = "-100.00"`.
- **Validação de Injeção de Propriedades Calculadas**: No `POST` e `PUT`, tentativas maliciosas de submeter `total_investido`, `patrimonio_atual` ou `rentabilidade_percentual` arbitrárias devem ser desconsideradas pelo schema ou sobrescritas pelo cálculo do backend.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE disponibilizar o endpoint `POST /api/v1/investments/` para criação de posições de investimento para o usuário autenticado.
- **FR-002**: O sistema DEVE validar a presença obrigatória dos campos `ticker`, `nome`, `classe`, `quantidade`, `preco_medio` e `cotacao_atual` na criação da posição.
- **FR-003**: O sistema DEVE validar o enum `classe` estritamente contra os valores permitidos: `ACOES`, `FIIS`, `RENDA_FIXA`, `CRIPTO`, `ETF`, `RENDA_EMERGENCIAL`.
- **FR-004**: O sistema DEVE validar que o campo `ticker` possua entre 1 e 20 caracteres e `nome` entre 1 e 255 caracteres.
- **FR-005**: O sistema DEVE validar que `quantidade` seja estritamente superior a zero (`exclusiveMinimum: 0.0`) e que `preco_medio` e `cotacao_atual` sejam maiores ou iguais a zero (`minimum: 0.0`).
- **FR-006**: O sistema DEVE calcular e preencher automaticamente os campos read-only:
  - `total_investido = quantidade * preco_medio`
  - `patrimonio_atual = quantidade * cotacao_atual`
  - `lucro_prejuizo_absoluto = patrimonio_atual - total_investido`
  - `rentabilidade_percentual = ((patrimonio_atual - total_investido) / total_investido) * 100` (ou `0.00` se `total_investido == 0`).
- **FR-007**: O sistema DEVE atribuir o `user_id` da posição exclusivamente a partir da identidade do token JWT do usuário autenticado, ignorando qualquer tentativa de injeção manual.
- **FR-008**: O sistema DEVE gerar um identificador `id` único no formato UUID v4 e timestamps `created_at` e `updated_at` na persistência do investimento.
- **FR-009**: O sistema DEVE disponibilizar o endpoint `GET /api/v1/investments/summary` para retorno das métricas globais e consolidadas de patrimônio do usuário logado.
- **FR-010**: O endpoint de resumo DEVE retornar valores zerados (`patrimonio_total: "0.00"`, `total_investido: "0.00"`, `lucro_prejuizo_absoluto: "0.00"`, `rentabilidade_percentual: "0.00"` e `alocacao_por_classe: []`) para usuários sem investimentos cadastrados.
- **FR-011**: O endpoint de resumo DEVE agregar a soma de todos os ativos do usuário, computando o percentual de participação de cada classe no patrimônio total da carteira.
- **FR-012**: O sistema DEVE disponibilizar o endpoint `GET /api/v1/investments/` com suporte a paginação via query parameters `skip` (mínimo 0, padrão 0) e `limit` (mínimo 1, máximo 100, padrão 100).
- **FR-013**: O sistema DEVE permitir a filtragem de ativos na listagem por classe via parâmetro opcional `classe`, restringindo a resposta aos ativos correspondentes.
- **FR-014**: O sistema DEVE disponibilizar o endpoint `GET /api/v1/investments/{investment_id}` para recuperação detalhada dos atributos de uma posição de custódia.
- **FR-015**: O sistema DEVE bloquear o acesso de qualquer usuário a investimentos pertencentes a outros usuários (IDOR), retornando código de erro `404 Not Found` ou `403 Forbidden`.
- **FR-016**: O sistema DEVE disponibilizar o endpoint `PUT /api/v1/investments/{investment_id}` para atualização de propriedades da posição (`InvestmentUpdate`).
- **FR-017**: Ao receber uma atualização de `cotacao_atual`, `quantidade` ou `preco_medio` via `PUT`, o sistema DEVE recalcular imediatamente todos os campos derivados da posição.
- **FR-018**: Ao sofrer alteração ou exclusão de um investimento, o sistema DEVE refletir as mudanças instantaneamente nos cálculos consolidados de `/api/v1/investments/summary`.
- **FR-019**: O sistema DEVE disponibilizar o endpoint `DELETE /api/v1/investments/{investment_id}` retornando código `204 No Content` e removendo a posição de forma irreversível.
- **FR-020**: O sistema DEVE validar o formato do identificador `{investment_id}` nas rotas de detalhe, atualização e exclusão, retornando `422 Unprocessable Entity` quando não for um UUID válido.
- **FR-021**: O sistema DEVE exigir autenticação Bearer JWT válida em todos os endpoints de investimentos, respondendo com `401 Unauthorized` na ausência ou invalidade do token.
- **FR-022**: O sistema DEVE garantir isolamento total de dados entre tenants em todas as operações de listagem, consulta, agregação, atualização e exclusão.

### Key Entities *(include if feature involves data)*

- **Investment (`InvestmentResponse`)**: Representa uma posição de custódia de um ativo sob titularidade de um usuário específico.
  - `id`: UUID v4 primário da custódia.
  - `user_id`: UUID v4 do usuário titular.
  - `ticker`: Símbolo ou código de negociação do ativo (string, 1..20 chars).
  - `nome`: Descrição completa ou razão social do ativo (string, 1..255 chars).
  - `classe`: Categoria do investimento (`InvestmentClass`).
  - `quantidade`: Quantidade de cotas ou frações mantidas (decimal/string, estritamente > 0).
  - `preco_medio`: Custo médio unitário de aquisição (decimal/string, >= 0).
  - `cotacao_atual`: Valor de mercado unitário atualizado (decimal/string, >= 0).
  - `total_investido`: Valor total desembolsado (`quantidade * preco_medio`, read-only).
  - `patrimonio_atual`: Valor de mercado consolidado da posição (`quantidade * cotacao_atual`, read-only).
  - `lucro_prejuizo_absoluto`: Saldo de ganho ou perda de capital nominal (`patrimonio_atual - total_investido`, read-only).
  - `rentabilidade_percentual`: Retorno relativo acumulado da posição (`(lucro / total_investido) * 100`, read-only).
  - `created_at` e `updated_at`: Marcas temporais no padrão ISO 8601.

- **InvestmentClass (Enum)**: Conjunto fechado das modalidades de investimento suportadas:
  - `ACOES`: Ações e units do mercado acionário.
  - `FIIS`: Fundos de Investimento Imobiliário.
  - `RENDA_FIXA`: CDBs, LCIs, LCAs, Tesouro Direto e debêntures.
  - `CRIPTO`: Criptomoedas e tokens descentralizados.
  - `ETF`: Fundos de índice negociados em bolsa.
  - `RENDA_EMERGENCIAL`: Aplicações de liquidez imediata reservadas para emergências.

- **PortfolioSummary (`PortfolioSummaryResponse`)**: Consolidação matemática de todo o patrimônio investido pelo usuário.
  - `patrimonio_total`: Somatório do `patrimonio_atual` de todos os ativos do usuário.
  - `total_investido`: Somatório do `total_investido` de todos os ativos do usuário.
  - `lucro_prejuizo_absoluto`: Ganho ou perda global da carteira (`patrimonio_total - total_investido`).
  - `rentabilidade_percentual`: Taxa de retorno agregada de toda a carteira.
  - `alocacao_por_classe`: Lista de agrupamento contendo cada classe representada na carteira com `patrimonio_total`, `total_investido` e `percentual_carteira`.

- **ClassAllocation (`ClassAllocation`)**: Distribuição relativa de uma classe dentro da carteira do usuário.
  - `classe`: Categoria de investimento associada.
  - `patrimonio_total`: Volume financeiro total alocado nesta classe.
  - `total_investido`: Custo financeiro total alocado nesta classe.
  - `percentual_carteira`: Peso percentual em relação ao patrimônio global da carteira (`(patrimonio_classe / patrimonio_total) * 100`).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos endpoints do módulo de investimentos (`POST /`, `GET /`, `GET /summary`, `GET /{id}`, `PUT /{id}`, `DELETE /{id}`) possuem cobertura automatizada de testes cobrindo fluxos de sucesso e exceção.
- **SC-002**: 100% das asserções de validação de contrato contra as respostas da API estão rigorosamente alinhadas com as definições do `openapi.json` (`InvestmentResponse`, `PortfolioSummaryResponse`, `ClassAllocation`).
- **SC-003**: O isolamento de dados entre usuários (multi-tenancy) é 100% garantido em testes automatizados, atestando zero vazamento de posições, IDOR ou contaminação em agregações de resumo.
- **SC-004**: Todas as operações de cálculo de métricas derivadas (`total_investido`, `patrimonio_atual`, `lucro_prejuizo_absoluto`, `rentabilidade_percentual` e `alocacao_por_classe`) demonstram exatidão matemática com tolerância máxima de arredondamento de `0.05%`.
- **SC-005**: 100% dos cenários de teste são independentes, idempotentes e executáveis concorrentemente em 3 threads paralelas sem causar flakiness ou conflito de dados.
- **SC-006**: Todos os casos de teste que requerem autenticação utilizam provisionamento dinâmico via `auth-helper.feature` em cumprimento à Constituição do projeto (Princípio VII).
- **SC-007**: 100% das tentativas de submissão com payloads inválidos, tipos incompatíveis ou limites violados são rejeitadas com status `422 Unprocessable Entity` ou `400 Bad Request`.
- **SC-008**: 100% dos acessos sem token ou com credenciais inválidas são rejeitados com status `401 Unauthorized`.

---

## Assumptions

- **A-001 (Autenticação)**: O serviço depende da infraestrutura de autenticação JWT previamente implementada no módulo `001-auth-user-management`. Cada cenário criará seu próprio usuário limpo via `auth-helper.feature`.
- **A-002 (Ponto Flutuante e Strings)**: Conforme definido no schema OpenAPI `InvestmentCreate`, valores numéricos monetários e de cotas são aceitos tanto como números quanto como strings formatadas (regex `^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d*$`), sendo serializados como strings na resposta para preservar precisão decimal.
- **A-003 (Ambiente e Host)**: A suíte de testes executa primariamente contra o host alvo `http://100.75.210.114:8000` conforme estipulado pela Constituição Técnica do projeto.
- **A-004 (Divisão Segura)**: Caso `total_investido` seja zero (ex: bonificação de ações), o backend trata a rentabilidade atribuindo `0.00` em vez de falhar por divisão por zero.
- **A-005 (Desconexão com Contas Bancárias)**: Na versão atual da API, o módulo de custódia de investimentos opera de forma autônoma sem vincular obrigatoriamente um débito automático no `saldo_calculado` de uma conta bancária ao registrar um investimento.
