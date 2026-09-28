---
name: karate-authoring
description: >-
  Diretrizes e melhores práticas de mercado para escrita, modelagem e refatoração de features
  e cenários em Karate DSL. Utilize ao criar novos testes, elaborar testes parametrizados
  (Scenario Outline / Examples), garantir independência estrita entre cenários, aplicar validação
  de schemas com fuzzy matchers e implementar assertivas resilientes.
---

# Karate Authoring — Melhores Práticas de Escrita de Testes

Este guia estabelece as convenções de escrita e boas práticas de mercado para a construção de suítes de teste de alta qualidade em **Karate DSL**.

---

## 1. 🛡️ Independência Estrita de Testes (Test Isolation)

### Princípio Fundamental
**Nenhum teste pode depender do estado criado por outro teste ou da ordem de execução.**
O Karate foi desenhado para execução concorrente massiva (`.parallel(N)`). Se o Cenário B depende de um usuário cadastrado no Cenário A, a suíte falhará imprevisivelmente durante execuções paralelas ou ao rodar com filtros de tags (`-Dkarate.tags`).

### Regras Mandatórias:
1. **Dados Únicos por Execução**: Nunca utilize identificadores estáticos como `"usuario@teste.com"` ou `"12345678900"`. Utilize sempre `dataGenerator.getRandomEmail()` e `dataGenerator.getRandomCpf()`.
2. **Setup Autocontido**: Se um cenário precisa de um usuário autenticado (como em `GET /api/v1/auth/me`), o próprio cenário (ou via helper feature) deve:
   - Cadastrar um novo usuário exclusivo.
   - Efetuar login e obter o token.
   - Executar a ação de teste sob validação.
3. **Limpeza ou Dados Efêmeros**:
   - Sempre que a API suportar deleção (`DELETE`), efetue a limpeza dos dados criados, ou adote o padrão de criação de dados com identificadores únicos com timestamp/UUID para não colidir com outros testes.

### Exemplo de Antipattern vs Padrão Recomendado:

❌ **Antipattern (Acoplamento entre cenários):**
```gherkin
Scenario: Cenário 1 - Cadastrar usuário fixo
  Given path '/api/v1/auth/register'
  And request { email: 'admin@sistema.com', password: 'Password123' }
  When method post
  Then status 201

Scenario: Cenário 2 - Consultar usuário do Cenário 1 (QUEBRA EM PARALELO!)
  Given path '/api/v1/auth/login'
  And request { email: 'admin@sistema.com', password: 'Password123' }
  When method post
  Then status 200
  * def token = response.access_token
  Given path '/api/v1/auth/me'
  And header Authorization = 'Bearer ' + token
  When method get
  Then status 200
```

✅ **Padrão Recomendado (Cenário 100% autocontido):**
```gherkin
@smoke @happy_path
Scenario: SCEN-ME-01 - Consulta de perfil de usuário com sessao valida
  # 1. Setup autocontido com credenciais dinamicas unicas
  * def userEmail = dataGenerator.getRandomEmail()
  * def userPassword = dataGenerator.getRandomValidPassword()
  * def regPayload = read('classpath:data/payloads/auth/register-request.json')
  * set regPayload.email = userEmail
  * set regPayload.password = userPassword
  Given path '/api/v1/auth/register'
  And request regPayload
  When method post
  Then status 201

  # 2. Login para emissao do token
  * def loginPayload = read('classpath:data/payloads/auth/login-request.json')
  * set loginPayload.email = userEmail
  * set loginPayload.password = userPassword
  Given path '/api/v1/auth/login'
  And request loginPayload
  When method post
  Then status 200
  * def authToken = response.access_token

  # 3. Acao principal em teste
  Given path '/api/v1/auth/me'
  And header Authorization = 'Bearer ' + authToken
  When method get
  Then status 200
  And match response == userResponseSchema
  And match response.email == userEmail
```

---

## 2. 📊 Testes Parametrizados (Data-Driven Testing)

Utilize `Scenario Outline` com `Examples` para testar variações de entrada, validações de borda (boundary testing), valores nulos, malformados e matrizes de permissão.

### A. Tabela de Exemplos Inline
Utilize para testar regras de validação de campos (ex: validação sintática de e-mails ou tamanhos de senha):

```gherkin
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
```

### B. Teste Parametrizado com Payloads Complexos ou Nulos
Para verificar múltiplos campos obrigatórios e tipos de dados inválidos:

```gherkin
@validation @negative
Scenario Outline: SCEN-LOG-05 - Payload de login com campos vazios ou nulos (<cenario>)
  Given path loginPath
  And request <payload>
  When method post
  Then status 422
  And match response == validationErrorSchema

  Examples:
    | cenario            | payload                                                        |
    | email ausente      | { password: 'ValidPassword123' }                               |
    | senha ausente      | { email: 'valid_user@example.com' }                            |
    | email nulo         | { email: null, password: 'ValidPassword123' }                  |
    | senha nula         | { email: 'valid_user@example.com', password: null }            |
    | corpo vazio        | {}                                                             |
```

### C. Exemplos Lidos de Arquivos Externos (JSON ou CSV)
Para matrizes de teste muito extensas:
```gherkin
Scenario Outline: SCEN-VAL-06 - Matriz de validacao de campos
  Given path '/api/v1/validate'
  And request { input: '<input>' }
  When method post
  Then status <statusEsperado>

  Examples:
    | read('classpath:data/test-matrix.json') |
```

---

## 3. 📦 Desacoplamento de Payloads e Mutação Dinâmica

### Regra:
**Nunca insira JSONs grandes ou estáticos inline dentro do arquivo `.feature`.**
Mantenha os payloads modelo sob `src/test/resources/data/payloads/<dominio>/`.

### Ciclo de Vida do Payload no Teste:
1. **Leitura**: Ler o arquivo base:
   ```gherkin
   * def payload = read('classpath:data/payloads/auth/register-request.json')
   ```
2. **Mutação com `set`**: Modificar propriedades necessárias com dados sintéticos:
   ```gherkin
   * set payload.email = dataGenerator.getRandomEmail()
   * set payload.password = dataGenerator.generatePassword(10)
   * set payload.user.address.zipcode = '01001-000'
   ```
3. **Remoção de Campos com `remove`**: Para testar a omissão de campos opcionais ou obrigatórios:
   ```gherkin
   * remove payload.phone
   * remove payload.address
   ```

---

## 4. 🔍 Validação de Contratos com Karate Fuzzy Matchers

### Regra:
Sempre separe o schema de contrato sob `src/test/resources/data/schemas/<dominio>/`.
Utilize os matchers nativos do Karate para validar a tipagem estrita e regras de formato sem acoplamento a valores estáticos:

```json
{
  "id": "#uuid",
  "email": "#regex ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
  "is_active": "#boolean",
  "created_at": "#regex ^\\d{4}-\\d{2}-\\d{2}T.*"
}
```

### Guia Rápido de Fuzzy Matchers:
- `#string` — Qualquer texto não nulo.
- `##string` — Texto ou nulo/ausente (opcional).
- `#number` — Valor numérico (inteiro ou decimal).
- `#boolean` — `true` ou `false`.
- `#array` — Array JSON (`#[]`).
- `#uuid` — UUID válido (v4).
- `#regex <expressao>` — Validação via expressão regular.
- `#present` — Campo deve estar presente no JSON.
- `#notpresent` — Campo **não** deve estar presente (ex: senhas ou hashes nunca devem vazar no response).
- `#null` — Campo deve ser explicitamente nulo.

### Tipos de Asserções `match`:
- `match response == schema` — Validação estrita: todos os campos do schema devem bater com a resposta.
- `match response contains { is_active: true }` — Validação parcial: garante que as chaves informadas existem com os valores especificados.
- `match each response.items contains { id: '#uuid' }` — Valida cada item de uma lista JSON.

---

## 5. ⏱️ Resiliência a Rate Limiting e Operações Assíncronas

Em ambientes integrados ou serviços com Rate Limiting (ex: HTTP 429), configure retry inteligente para evitar falsos positivos:

```gherkin
Background:
  * configure retry = { count: 12, interval: 10000 }

Scenario: SCEN-LOG-01 - Login com tolerancia a rate limit
  Given path '/api/v1/auth/login'
  And request payload
  # Executa tentativas caso o servidor responda 429 (Too Many Requests)
  And retry until responseStatus != 429
  When method post
  Then status 200
```

---

## 6. 🏷️ Padrão de Nomenclatura e Tags

### Nomenclatura de Cenários
Siga o padrão: `SCEN-<DOMINIO>-<NUMERO> - <Descricao Objetiva>`:
- `SCEN-REG-01 - Cadastro bem-sucedido com senha minima (8 caracteres)`
- `SCEN-LOG-02 - Tentativa de autenticacao com senha invalida`
- `SCEN-DEL-02 - Exclusao com limpeza em cascata de dados correlacionados`

### Estrutura de Tags:
- **Domínio/Módulo**: `@auth`, `@users`, `@accounts`, `@transactions`
- **Operação/Ação**: `@register`, `@login`, `@me`, `@delete`
- **Classificação de Teste**:
  - `@smoke`: Cenários críticos de fluxo principal (happy path rápido).
  - `@regression`: Todos os cenários funcionais para regressão completa.
  - `@happy_path`: Fluxos de sucesso com 200, 201, 204.
  - `@negative`: Fluxos de exceção, regras de negócio violadas, 400, 401, 403, 404, 409, 422.
  - `@boundaries`: Limites de tamanho, caracteres mínimos e máximos.
  - `@security`: Autenticação ausente, token adulterado ou expirado.
  - `@ignore`: Testes intencionalmente desabilitados ou em quarentena (o `TestRunner` ignora por padrão).
