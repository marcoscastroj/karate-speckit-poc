---
name: karate-dsl
description: >-
  Guia mestre e blueprint de arquitetura para automação de testes de API com Karate DSL.
  Use ao projetar, estruturar, avaliar ou refatorar suítes de testes Karate, garantindo aderência
  às melhores práticas de mercado: independência de testes, testes parametrizados, segurança de credenciais (.env/properties),
  não repetição de código (DRY) e geração dinâmica de dados sintéticos.
---

# Karate DSL — Guia Mestre e Arquitetura de Testes

Este guia define os padrões e a arquitetura de referência para automação de testes de API em **Karate DSL** (versão 1.5+), integrando **Java 21 LTS**, **Maven**, **JUnit 5** e **Net Datafaker**.

---

## 🏛️ Os 7 Pilares Constitucionais de Automação Karate

Toda implementação ou refatoração de testes no projeto deve seguir rigorosamente estes 7 pilares:

```
┌────────────────────────────────────────────────────────────────────────┐
│               7 PILARES DE EXCELÊNCIA EM KARATE DSL                   │
├──────────────────────────────────┬─────────────────────────────────────┤
│ 1. Independência Estrita        │ Cenários 100% autocontidos e        │
│    (Parallel Safety)            │ seguros para execução concorrente   │
├──────────────────────────────────┼─────────────────────────────────────┤
│ 2. Testes Parametrizados        │ Scenario Outline + Examples para    │
│    (Data-Driven)                │ limites, contratos e status codes   │
├──────────────────────────────────┼─────────────────────────────────────┤
│ 3. Desacoplamento de Payloads   │ JSONs base em data/payloads/        │
│    e Mutação Dinâmica           │ com mutações via set / remove       │
├──────────────────────────────────┼─────────────────────────────────────┤
│ 4. Validação de Contrato        │ Schemas formais em data/schemas/    │
│    (Fuzzy Matchers)             │ com matchers #uuid, #regex, #string │
├──────────────────────────────────┼─────────────────────────────────────┤
│ 5. Gestão Segura de Segredos    │ Leitura via env vars, -Dproperties  │
│    (Zero-Secret Exposure)       │ ou .env, sem senhas no repositório  │
├──────────────────────────────────┼─────────────────────────────────────┤
│ 6. Reusabilidade sem Acoplamento│ Helpers reutilizáveis via call /    │
│    (DRY - Don't Repeat Yourself)│ callonce e funções JavaScript/Java  │
├──────────────────────────────────┼─────────────────────────────────────┤
│ 7. Execução Granular e Relatórios│ Tags padronizadas (@smoke, etc.),   │
│    (TestRunner + JUnit 5)       │ runner paralelo e relatórios HTML   │
└──────────────────────────────────┴─────────────────────────────────────┘
```

---

## 📁 Estrutura de Diretórios Padronizada

A arquitetura do projeto separa claramente responsabilidades entre código Java, features Gherkin, massas de dados e configurações:

```text
karate-speckit-poc/
├── pom.xml                                    # Dependências (karate-junit5, datafaker, maven plugins)
└── src/
    └── test/
        ├── java/
        │   ├── features/                      # Suítes de testes organizadas por domínio/módulo
        │   │   ├── TestRunner.java            # Runner JUnit 5 geral (executa em paralelo com N threads)
        │   │   ├── auth/                      # Domínio de Autenticação
        │   │   │   ├── register.feature       # POST /api/v1/auth/register
        │   │   │   ├── login.feature          # POST /api/v1/auth/login
        │   │   │   ├── me-get.feature         # GET /api/v1/auth/me
        │   │   │   └── me-delete.feature      # DELETE /api/v1/auth/me
        │   │   └── helpers/                   # Features utilitárias reutilizáveis (ex: login-helper)
        │   └── utils/                         # Classes utilitárias Java (extensibilidade para o Karate)
        │       ├── CredentialUtils.java       # Helpers para headers Auth (Basic, Bearer) e System env/prop
        │       └── DataGenerator.java         # Gerador dinâmico com Datafaker (pt-BR, emails, senhas)
        └── resources/
            ├── config/                        # Configurações de ambientes
            │   └── environments.json          # URLs base e timeouts por target (dev, qa, e2e)
            ├── data/
            │   ├── payloads/                  # Payloads JSON base desacoplados dos cenários
            │   │   └── auth/
            │   │       ├── register-request.json
            │   │       └── login-request.json
            │   └── schemas/                   # Contratos JSON com Fuzzy Matchers do Karate
            │       └── auth/
            │           ├── user-response-schema.json
            │           ├── token-schema.json
            │           └── validation-error-schema.json
            ├── utils/                         # Funções utilitárias JavaScript
            │   └── credentials-reader.js      # Leitor seguro de variáveis de ambiente e properties
            ├── karate-config.js               # Bootstrap global de inicialização do Karate
            └── logback-test.xml               # Configuração de logging e mascaramento de dados sensíveis
```

---

## 🗺️ Mapa de Skills Especializadas

Para executar tarefas específicas, consulte as skills especializadas da suíte:

| Skill | Quando Ativar | Foco Principal |
| :--- | :--- | :--- |
| **`karate-authoring`** | Criação ou refatoração de `.feature` | Independência de testes, `Scenario Outline`, mutação de payloads, fuzzy matchers, assertivas e retry |
| **`karate-data-and-secrets`** | Gestão de senhas, credenciais e dados | Leitura de `.env`, properties, variáveis de ambiente, `DataGenerator.java` e geração de contas on-the-fly |
| **`karate-reusability-and-dry`** | Evitar duplicação de código | `karate.call` vs `karate.callonce`, helpers de autenticação compartilhados, payloads e schemas centralizados |
| **`karate-execution-and-ops`** | Execução e diagnóstico | Configuração do `TestRunner.java`, threads paralelas, estratégia de tags, comandos Maven e relatórios HTML |

---

## 📋 Checklist de Qualidade Antes de Concluir um Teste

Antes de dar uma feature ou cenário por concluído, valide os seguintes itens:

1. [ ] **Independência**: O cenário roda isoladamente sem depender da execução prévia de outro cenário?
2. [ ] **Paralelismo**: Se rodar 10 vezes em paralelo, há risco de colisão de dados (ex: e-mail duplicado)?
3. [ ] **Dados Dinâmicos**: E-mails, CPFs e dados únicos estão sendo gerados via `dataGenerator`?
4. [ ] **Payloads Desacoplados**: O corpo da requisição é lido de `data/payloads/` e não escrito como JSON fixo no `.feature`?
5. [ ] **Validação de Schema**: A resposta valida o schema contratual formal (`match response == userResponseSchema`)?
6. [ ] **Status Codes**: O teste cobre tanto cenários de sucesso (200, 201, 204) quanto negativos (400, 401, 403, 404, 409, 422)?
7. [ ] **Resiliência a Rate Limit**: Há `retry until responseStatus != 429` onde aplicável para evitar intermitência em APIs com throttling?
8. [ ] **Zero Segredos**: Nenhuma senha, token real ou chave privada está commitada em texto puro?
9. [ ] **Tagging**: O cenário e a feature contêm as tags adequadas (`@auth`, `@smoke`, `@negative`, etc.)?
