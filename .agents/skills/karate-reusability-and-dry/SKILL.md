---
name: karate-reusability-and-dry
description: >-
  Melhores práticas para não repetição de código (DRY) no Karate DSL.
  Utilize para modularizar cenários, criar features utilitárias reutilizáveis com karate.call e
  karate.callonce, gerenciar helpers de autenticação compartilhados, compor schemas de contratos
  e centralizar payloads e utilitários Java/JavaScript.
---

# Karate Reusability and DRY — Modularização e Reuso Eficiente

O princípio **DRY (Don't Repeat Yourself)** no Karate DSL visa eliminar a duplicação de fluxos comuns (como autenticação, cadastro e setups complexos) sem violar a **independência e o paralelismo dos testes**.

---

## 1. 🔄 `karate.call` vs `karate.callonce`: Quando Usar Cada Um

A escolha entre `call` e `callonce` é crucial para balancear performance e independência:

```
┌──────────────────────────────┬──────────────────────────────┐
│         karate.call          │       karate.callonce        │
├──────────────────────────────┼──────────────────────────────┤
│ Executa SEMPRE que chamado   │ Executa UMA VEZ por feature  │
│ (a cada cenário individual)  │ e faz CACHE do resultado     │
├──────────────────────────────┼──────────────────────────────┤
│ ✅ Criação de novas contas    │ ✅ Autenticação de Admin     │
│    dinâmicas (test isolation)│    (leitura apenas / RO)     │
│ ✅ Dados mutáveis ou estado   │ ✅ Obtenção de tabelas de    │
│    que será alterado/deletado│    domínio ou dados estáticos│
├──────────────────────────────┼──────────────────────────────┤
│ ❌ Cuidado com overhead se   │ ❌ NUNCA use se o cenário    │
│    a chamada for estática    │    modificar/deletar o estado│
└──────────────────────────────┴──────────────────────────────┘
```

### Regra de Ouro:
> **Se o cenário altera, deleta ou consome o estado do recurso, use sempre `call` para gerar um recurso novo e exclusivo.**
> **Se o recurso for apenas lido de forma imutável (ex: consulta de catálogo público com token de admin de leitura), use `callonce`.**

---

## 2. 🧩 Padrão de Feature Utilitária (Helper Pattern)

Todas as features que servem exclusivamente como helpers reutilizáveis devem:
1. Conter a tag `@ignore` no topo (para que o `TestRunner` não as execute como testes de negócio).
2. Estar localizadas em um diretório padronizado, como `src/test/java/features/helpers/` ou `src/test/resources/helpers/`.
3. Declarar explicitamente as variáveis de saída esperadas (ex: `authToken`, `userId`).

### Exemplo de Helper de Autenticação (`src/test/java/features/helpers/auth-helper.feature`):
```gherkin
@ignore
Feature: Helper - Autenticacao Reutilizavel

  Background:
    * url baseUrl

  Scenario: Criar usuario e autenticar
    # Parametros opcionais recebidos pelo caller, ou gerados dinamicamente se ausentes
    * def email = karate.get('userEmail', dataGenerator.getRandomEmail())
    * def password = karate.get('userPassword', dataGenerator.getRandomValidPassword())

    # 1. Cadastro
    Given path '/api/v1/auth/register'
    * def regBody = read('classpath:data/payloads/auth/register-request.json')
    * set regBody.email = email
    * set regBody.password = password
    And request regBody
    When method post
    Then status 201
    * def userId = response.id

    # 2. Login
    Given path '/api/v1/auth/login'
    * def loginBody = read('classpath:data/payloads/auth/login-request.json')
    * set loginBody.email = email
    * set loginBody.password = password
    And request loginBody
    When method post
    Then status 200
    * def authToken = response.access_token
    * def authHeader = 'Bearer ' + authToken
```

### Como Consumir o Helper em Múltiplos Domínios:
```gherkin
@accounts
Feature: Gestão de Contas Bancárias

  Background:
    * url baseUrl
    # Invoca o helper para cada cenario isolado:
    * def auth = call read('classpath:features/helpers/auth-helper.feature')

  Scenario: Criar uma carteira bancária para a conta ativa
    Given path '/api/v1/accounts/'
    And header Authorization = auth.authHeader
    And request { apelido: 'Conta Investimentos' }
    When method post
    Then status 201
    And match response.user_id == auth.userId
```

---

## 3. 📦 Composição e Reuso de Schemas Contratuais

Evite repetir campos comuns (ex: timestamps de auditoria, endereços, paginação) em dezenas de schemas JSON. Use composição de schemas do Karate.

### Exemplo de Composição:
Defina schemas granulares em `src/test/resources/data/schemas/`:

**`common/pagination-schema.json`**:
```json
{
  "page": "#number",
  "page_size": "#number",
  "total_records": "#number",
  "total_pages": "#number"
}
```

**`users/user-list-schema.json`**:
```json
{
  "items": "#[] userResponseSchema",
  "pagination": "##(paginationSchema)"
}
```

No `.feature`:
```gherkin
Background:
  * def userResponseSchema = read('classpath:data/schemas/auth/user-response-schema.json')
  * def paginationSchema = read('classpath:data/schemas/common/pagination-schema.json')
  * def userListSchema = read('classpath:data/schemas/users/user-list-schema.json')

Scenario: Listar usuarios com paginacao
  Given path '/api/v1/users'
  When method get
  Then status 200
  And match response == userListSchema
```

---

## 4. ⚙️ Centralização no `karate-config.js`

O arquivo `src/test/resources/karate-config.js` é o ponto único de verdade (Single Source of Truth) para inicialização:
- Define variáveis globais (`baseUrl`, `timeout`).
- Disponibiliza helpers Java (`dataGenerator`, `credentialUtils`).
- Define políticas globais de timeout e retry.

```javascript
function fn() {
  var env = karate.env || 'dev';
  karate.log('Iniciando execucao no ambiente:', env);

  var envs = karate.read('classpath:config/environments.json');
  var envConfig = envs[env] || envs['dev'];
  var credentials = karate.call('classpath:utils/credentials-reader.js');
  var dataGenerator = Java.type('utils.DataGenerator');
  var credentialUtils = Java.type('utils.CredentialUtils');

  var config = {
    env: env,
    baseUrl: envConfig.baseUrl,
    timeout: envConfig.timeout || 10000,
    credentials: credentials,
    dataGenerator: dataGenerator,
    credentialUtils: credentialUtils
  };

  karate.configure('connectTimeout', config.timeout);
  karate.configure('readTimeout', config.timeout);
  karate.configure('retry', { count: 12, interval: 10000 });

  return config;
}
```

Com isso, **nenhum** `.feature` precisa fazer `Java.type(...)` ou carregar `environments.json` manualmente.
