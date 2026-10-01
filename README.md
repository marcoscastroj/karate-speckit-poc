# Karate DSL - Test Automation Architecture

Projeto de automação de testes de API estruturado com as melhores práticas de arquitetura para **Karate DSL**, utilizando **Java 21**, **Maven**, **JUnit 5** e **Datafaker**.

## 📝 Considerações sobre SpecKit e qualidade

Esta POC também registra aprendizados sobre o uso de IA com SpecKit na
especificação e implementação de testes de API, incluindo a importância
do contexto de negócio, das skills de Karate DSL e da validação dos
cenários produzidos.

Leia as [considerações sobre o uso do SpecKit com foco em qualidade](docs/consideracoes-speckit-qualidade.md).

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
- Resolução hierárquica em camadas de segredos:
  1. Variáveis de ambiente do SO (`System.getenv`).
  2. Parâmetros JVM via linha de comando (`-Dkey=value`).
  3. Arquivo local `.env` ou `credentials.properties` (ignorado pelo `.gitignore`, com modelo em [`.env.example`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/.env.example)).
  4. Fallback seguro para ambiente de desenvolvimento.
- [`credentials-reader.js`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/src/test/resources/utils/credentials-reader.js) & [`CredentialUtils.java`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/src/test/java/utils/CredentialUtils.java): Unificam a extração de credenciais e geração de headers de autenticação (`Bearer`, `Basic`).

### 5. 🎯 Bootstrap Centralizado (`karate-config.js`)
- Carrega as configurações de ambiente, instancia utilitários e disponibiliza as variáveis globais (`baseUrl`, `credentials`, `dataGenerator`, `credentialUtils`) para todos os `.feature`.

### 6. 🧩 Helpers Reutilizáveis e DRY (`features/helpers/`)
- Features utilitárias marcadas com `@ignore` (ex: [`auth-helper.feature`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/src/test/java/features/helpers/auth-helper.feature)) para autenticação e provisionamento de usuários on-the-fly sem duplicação de código.

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

---

## 🤖 Skills do Antigravity para Karate DSL

O repositório inclui um conjunto de **Skills para o Antigravity** em [`.agents/skills/`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/.agents/skills) com as melhores práticas de mercado:

| Skill | Descrição e Finalidade |
| :--- | :--- |
| [`karate-dsl`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/.agents/skills/karate-dsl/SKILL.md) | Guia mestre de arquitetura, 7 pilares constitucionais e diretrizes gerais. |
| [`karate-authoring`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/.agents/skills/karate-authoring/SKILL.md) | Escrita de features, independência estrita de cenários, testes parametrizados (`Scenario Outline`), mutação de payloads e validação com fuzzy matchers. |
| [`karate-data-and-secrets`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/.agents/skills/karate-data-and-secrets/SKILL.md) | Gestão segura de segredos (`.env`, properties, env vars), zero-exposure, geração com Datafaker pt-BR e provisionamento dinâmico de contas. |
| [`karate-reusability-and-dry`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/.agents/skills/karate-reusability-and-dry/SKILL.md) | Eliminação de duplicação (DRY), uso correto de `call` vs `callonce`, helpers utilitários e composição de schemas. |
| [`karate-execution-and-ops`](file:///home/marcos/Documentos/repositorios/karate-speckit-poc/.agents/skills/karate-execution-and-ops/SKILL.md) | Configuração do JUnit 5 `TestRunner`, paralelismo, tags, comandos Maven e diagnóstico via relatórios HTML. |
