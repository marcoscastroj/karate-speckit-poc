# Karate DSL - Test Automation Architecture

Projeto de automação de testes de API estruturado com as melhores práticas de arquitetura para **Karate DSL**, utilizando **Java 21**, **Maven**, **JUnit 5** e **Datafaker**.

---

## 📁 Arquitetura do Projeto

Por ser um projeto dedicado a testes, toda a estrutura está organizada sob `src/test`:

```text
karate-speckit-poc/
├── pom.xml                                    # Dependências (Karate 1.5.2, Datafaker, plugins Maven)
└── src/
    └── test/
        ├── java/
        │   ├── features/                      # Suítes de testes agrupadas por contexto/domínio
        │   │   ├── TestRunner.java            # Runner JUnit 5 geral (executa todas as features)
        │   │   └── users/
        │   │       └── users.feature          # Cenários Gherkin (GET, POST, PUT)
        │   └── utils/                         # Classes utilitárias Java
        │       ├── CredentialUtils.java       # Helpers para headers Auth (Basic, Bearer) e env
        │       └── DataGenerator.java         # Gerador de dados dinâmicos (Faker pt-BR)
        └── resources/
            ├── config/                        # Configuração de ambientes
            │   └── environments.json          # URLs base e timeouts por ambiente (dev, qa, e2e)
            ├── data/
            │   └── payloads/                  # Payloads reais e templates JSON
            │       ├── user-create.json       # Template JSON para criação de usuário
            │       └── user-update.json       # Template JSON para atualização
            ├── utils/
            │   └── credentials-reader.js      # Utilitário JS para leitura de secrets e env vars
            ├── karate-config.js               # Bootstrap global de configuração do Karate
            └── logback-test.xml               # Configuração de logging do Karate
```

---

## 🏛️ Camadas da Arquitetura

### 1. ⚙️ Configuração de Ambientes (`config/`)
- Arquivo central: `src/test/resources/config/environments.json`
- Define `baseUrl` e `timeout` para cada ambiente (`dev`, `qa`, `e2e`).
- Ao executar via terminal, basta passar `-Dkarate.env=qa` para alternar o target.

### 2. 📦 Payloads e Massa de Testes (`data/payloads/`)
- Armazena arquivos JSON limpos e desacoplados dos cenários de teste.
- O teste lê o payload estático e sobrescreve campos dinâmicos usando `* set payload.campo = valor`.

### 3. 🎲 Geração Dinâmica de Dados (`DataGenerator.java` com Datafaker)
- Integrado diretamente ao Karate através do objeto global `dataGenerator`:
  ```gherkin
  * set userPayload.name = dataGenerator.getRandomName()
  * set userPayload.email = dataGenerator.getRandomEmail()
  * set userPayload.phone = dataGenerator.getRandomPhoneNumber()
  ```

### 4. 🔐 Leitor de Credenciais e Segurança (`utils/`)
- `credentials-reader.js`: Lê chaves de autenticação (`API_KEY`, `AUTH_TOKEN`, etc.) diretamente das variáveis de ambiente do sistema operacional ou `-Dproperties`.
- `CredentialUtils.java`: Fornece geradores de header `Bearer` ou `Basic` para inclusão nas requisições.

### 5. 🎯 Bootstrap Centralizado (`karate-config.js`)
- Carrega as configurações de ambiente, instanciar utilitários e disponibilizar as variáveis globais (`baseUrl`, `credentials`, `dataGenerator`, `credentialUtils`) para todos os `.feature`.

---

## 🚀 Como Executar os Testes

### Execução via Maven

O runner padrão ([`TestRunner.java`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/src/test/java/features/TestRunner.java)) já está configurado para:
1. **Executar em paralelo com 3 threads** simultâneas (`.parallel(3)`).
2. **Ignorar automaticamente** qualquer teste marcado com a tag `@ignore` (`.tags("~@ignore")`).

```bash
# Executar todos os testes (paralelo com 3 threads e ignorando @ignore)
mvn test

# Filtrar por tags adicionais mantendo o ignore (ex: rodar apenas cenários com a tag @users)
mvn test -Dkarate.tags="@users"

# Executar apontando para outro ambiente (ex: qa ou e2e)
mvn test -Dkarate.env=qa

# Passar credenciais via linha de comando
mvn test -DAUTH_TOKEN="meu-token-secreto"
```

### Execução via IDE (IntelliJ IDEA / VS Code)

- É possível rodar diretamente a classe `TestRunner` clicando no botão **Run** verde.
- Com o plugin do Karate instalado, é possível executar cenários individuais clicando diretamente no arquivo `.feature`.

---

## 📊 Relatórios de Execução

Após a execução, o relatório interativo em HTML gerado pelo Karate fica disponível em:
```text
target/karate-reports/karate-summary.html
```
