---
name: karate-data-and-secrets
description: >-
  Melhores práticas para gestão de credenciais seguras (.env, properties, variáveis de ambiente,
  system properties), zero exposição de segredos, mascaramento de logs, geração de dados sintéticos
  com Datafaker (pt-BR) e provisionamento dinâmico de novas contas no Karate DSL.
---

# Karate Data and Secrets — Credenciais, .env e Geração Dinâmica de Dados

Este guia documenta as melhores práticas de mercado para **gestão segura de segredos** e **geração dinâmica de massa de testes** em projetos com Karate DSL.

---

## 1. 🔐 Hierarquia de Resolução de Segredos e Credenciais

Nunca versione senhas, tokens reais ou chaves privadas no Git.
O projeto adota uma resolução de credenciais em camadas através do leitor centralizado `src/test/resources/utils/credentials-reader.js` e da classe `utils.CredentialUtils`:

```
┌────────────────────────────────────────────────────────┐
│          HIERARQUIA DE RESOLUÇÃO DE SEGREDOS          │
├────────────────────────────────────────────────────────┤
│ 1. Variáveis de Ambiente do Sistema (System.getenv)   │
│    Ex: export API_PASSWORD="super-secret-password"    │
├────────────────────────────────────────────────────────┤
│ 2. System Properties da JVM (System.getProperty / -D)  │
│    Ex: mvn test -DAPI_PASSWORD="super-secret-password"│
├────────────────────────────────────────────────────────┤
│ 3. Arquivo Local .env ou credentials.properties        │
│    (Ignorado pelo .gitignore, carregado se existir)    │
├────────────────────────────────────────────────────────┤
│ 4. Fallback Seguro de Desenvolvimento (Mock / Dev)    │
│    Ex: 'default-dev-key' / 'dev-secret'               │
└────────────────────────────────────────────────────────┘
```

---

## 2. 📄 Uso de Arquivos `.env` ou `.properties` para Senhas Locais

### Como Usar um Arquivo `.env` Local:
1. Crie o arquivo `.env` na raiz do projeto (ou `credentials.properties`):
   ```bash
   API_KEY=minha-chave-secreta-de-qa
   AUTH_TOKEN=jwt-token-valido-qa
   API_USERNAME=qa_automation_user
   API_PASSWORD=MinhaSenhaForte@2026
   ```

2. **Garantia de Segurança no `.gitignore`**:
   Certifique-se de que o `.gitignore` protege esses arquivos:
   ```gitignore
   # Segredos e variáveis de ambiente
   .env
   .env.*
   *.properties
   !src/test/resources/logback-test.xml
   ```

3. **Leitura Automatizada pelo `credentials-reader.js` ou `CredentialUtils.java`**:
   O helper lê o arquivo local caso exista, sem quebrar o build em ambientes de CI onde as credenciais vêm de variáveis de ambiente.

---

## 3. 🎲 Geração Dinâmica de Dados Sintéticos (`DataGenerator.java` com Datafaker)

### Por que NÃO usar dados estáticos?
- **Colisão de Registros**: Se dois testes usarem o mesmo e-mail, um deles falhará com HTTP 409 (Conflict).
- **Invalidação Paralela**: Testes concorrentes alterando o mesmo usuário causam instabilidade intermitente (flakiness).
- **LGPD / Compliance**: Proibido utilizar dados de clientes reais ou e-mails corporativos reais em testes.

### Utilitários Disponíveis no Objeto Global `dataGenerator`:

Integrado diretamente no `karate-config.js`, o `dataGenerator` pode ser chamado em qualquer `.feature`:

| Método | Retorno Exemplo | Utilidade |
| :--- | :--- | :--- |
| `dataGenerator.getRandomEmail()` | `user_1790193951_a1b2c3d4@example.com` | E-mail único com timestamp + UUID para garantir 0% de colisão |
| `dataGenerator.getRandomName()` | `Carlos Eduardo da Silva` | Nomes realistas em pt-BR via Net Datafaker |
| `dataGenerator.getRandomUsername()` | `carlos_silva_e3f2` | Username alfanumérico único |
| `dataGenerator.getRandomCpf()` | `82930491023` | CPF com dígitos verificadores matematicamente válidos |
| `dataGenerator.getRandomPhoneNumber()` | `(11) 98765-4321` | Telefones válidos formato Brasil |
| `dataGenerator.getRandomStreet()` | `Avenida Paulista, 1000` | Endereços em português |
| `dataGenerator.getRandomCity()` | `São Paulo` | Cidades brasileiras |
| `dataGenerator.getRandomZipCode()` | `01311-000` | CEPs válidos |
| `dataGenerator.generatePassword(N)` | `Aa1!b2C3d4...` | Senha com complexidade alfanumérica no tamanho exato |
| `dataGenerator.getRandomValidPassword()` | `Aa1!k7M9p2Q4` | Senha padrão válida (12 caracteres) |
| `dataGenerator.getRandomUser()` | `Map<String, Object>` | Objeto completo com dados de pessoa física |

### Exemplo de Uso no `.feature`:
```gherkin
Scenario: SCEN-REG-01 - Cadastro de usuario com dados gerados dinamicamente
  Given path '/api/v1/auth/register'
  * def userEmail = dataGenerator.getRandomEmail()
  * def userPassword = dataGenerator.getRandomValidPassword()
  * def payload = read('classpath:data/payloads/auth/register-request.json')
  * set payload.email = userEmail
  * set payload.password = userPassword
  And request payload
  When method post
  Then status 201
```

---

## 4. 👤 Provisionamento Dinâmico de Novas Contas (On-the-Fly)

### O Padrão "Conta Dinâmica por Cenário"
Em vez de depender de uma conta pré-existente no banco de dados da aplicação, o cenário gera uma nova conta sob demanda.

### Como Implementar com Helper Reutilizável:
Crie uma feature utilitária em `src/test/resources/helpers/create-authenticated-user.feature`:

```gherkin
@ignore
Feature: Helper - Criacao de Conta e Login Dinâmico On-The-Fly

  Scenario: Criar novo usuario e retornar token JWT
    * def uniqueEmail = dataGenerator.getRandomEmail()
    * def uniquePassword = dataGenerator.getRandomValidPassword()

    # 1. Cadastro
    Given url baseUrl
    And path '/api/v1/auth/register'
    * def regBody = { email: uniqueEmail, password: uniquePassword }
    And request regBody
    When method post
    Then status 201
    * def createdUserId = response.id

    # 2. Login
    Given url baseUrl
    And path '/api/v1/auth/login'
    And request { email: uniqueEmail, password: uniquePassword }
    When method post
    Then status 200
    * def authToken = response.access_token
    * def authHeader = 'Bearer ' + authToken
```

### Como Consumir em Qualquer Outra Feature:
```gherkin
Scenario: SCEN-ACC-01 - Criar carteira bancaria para usuario isolado
  # Cria uma conta nova e exclusiva em apenas 1 linha!
  * def userSession = call read('classpath:helpers/create-authenticated-user.feature')

  Given path '/api/v1/accounts/'
  And header Authorization = userSession.authHeader
  And request { apelido: 'Reserva de Emergência' }
  When method post
  Then status 201
  And match response.user_id == userSession.createdUserId
```

---

## 5. 🛡️ Mascaramento de Segredos em Logs (`logback-test.xml`)

Para impedir que senhas, tokens de autorização e chaves sejam gravados no log de execução (`target/karate.log`) ou expostos em pipelines de CI:

1. **Configuração do Logger HTTP**:
   Mantenha o nível do Karate em `INFO` em CI/CD e `DEBUG` apenas localmente.
2. **Ocultação de Headers Sensíveis**:
   O Karate oculta automaticamente os valores de `Authorization` nos relatórios quando configurado.
3. **Evitar Prints Inseguros**:
   Nunca faça `* print 'SENHA: ', userPassword` ou `* print 'TOKEN: ', authToken` em código versionado.
