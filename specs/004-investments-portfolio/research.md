# Phase 0 Research: Gestão de Portfólio de Investimentos (Investments API)

**Feature**: `004-investments-portfolio`  
**Date**: 2026-09-28  
**Status**: Completed  

---

## 1. Precisão de Ponto Flutuante e Validação de Strings Decimais no Karate DSL

### Contexto
O contrato OpenAPI (`InvestmentResponse` e `InvestmentCreate`) define grandezas financeiras (`quantidade`, `preco_medio`, `cotacao_atual`, `total_investido`, `patrimonio_atual`, `lucro_prejuizo_absoluto`, `rentabilidade_percentual`) com o padrão de expressão regular:
`^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d*$`
Para evitar perda de precisão binária (IEEE 754), a API trafega esses valores monetários e de custódia como representações em string com casas decimais.

### Decisão
- Validar o formato estrutural dos números utilizando fuzzy matchers regex do Karate (`'#regex ^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d*$'`).
- Para validações de regras matemáticas (cálculo de `total_investido`, `patrimonio_atual`, `lucro_prejuizo_absoluto` e `rentabilidade_percentual`), realizar a conversão explícita no Karate utilizando JavaScript nativo (`parseFloat()` ou `Number()`) e assertivas com tolerância de ponto flutuante:
  ```gherkin
  * def totalEsperado = parseFloat(quantidade) * parseFloat(precoMedio)
  * def totalObtido = parseFloat(response.total_investido)
  * assert Math.abs(totalObtido - totalEsperado) < 0.01
  ```
- Para rentabilidade percentual:
  ```gherkin
  * def rentabilidadeEsperada = ((patrimonioAtual - totalInvestido) / totalInvestido) * 100
  * def rentabilidadeObtida = parseFloat(response.rentabilidade_percentual)
  * assert Math.abs(rentabilidadeObtida - rentabilidadeEsperada) < 0.02
  ```

### Rationale
- Garante conformidade estrita com o formato retornado pela API sem acoplamento a pequenas discrepâncias de arredondamento na última casa decimal.
- Evita falhas intermitentes causadas por precisão de float no motor JavaScript/Nashorn/GraalVM do Karate DSL.

### Alternativas Consideradas
- **Comparação exata de string (`match response.total_investido == '3000.00'`)**: Frágil quando o backend retorna `"3000.0"` ou `"3000.0000"` (especialmente para criptoativos com 8 casas decimais).
- **Conversão via Java BigDecimal em classe utilitária**: Válido, mas adiciona complexidade desnecessária para asserções de teste que o `Math.abs(a - b) < delta` em JavaScript resolve diretamente e de forma idiomática no Karate.

---

## 2. Invariante da Soma de Alocação de Classes (100% da Carteira)

### Contexto
O endpoint `GET /api/v1/investments/summary` retorna um array `alocacao_por_classe`, onde cada item possui o campo `percentual_carteira`. Para uma carteira de investimentos válida com múltiplos ativos, a soma das alocações de todas as classes deve somar exatamente 100% da carteira (com tolerância de arredondamento).

### Decisão
Implementar uma função de agregação em JavaScript no Karate DSL para somar os percentuais de todas as classes retornadas:
```gherkin
* def calcularSomaAlocacao = 
"""
function(alocacoes) {
  var soma = 0.0;
  for (var i = 0; i < alocacoes.length; i++) {
    soma += parseFloat(alocacoes[i].percentual_carteira);
  }
  return soma;
}
"""
* def somaTotal = calcularSomaAlocacao(response.alocacao_por_classe)
* assert Math.abs(somaTotal - 100.0) <= 0.05
```

### Rationale
- Testa uma invariante crítica de negócio da consolidação de portfólio.
- Suporta qualquer quantidade de classes ativas dinamicamente sem hardcode de índices de array.

### Alternativas Consideradas
- **Assertiva fixa nos índices do array (`match response.alocacao_por_classe[0].percentual_carteira == '40.00'`)**: Inadequada para testes dinâmicos onde a ordem dos elementos no array de classes não é garantida por contrato.

---

## 3. Isolamento Multi-Tenancy e Testes de IDOR / BOLA

### Contexto
Cada usuário deve visualizar e manipular exclusivamente suas próprias posições de custódia e seus próprios resumos patrimoniais. Tentativas de acesso entre contas distintas (IDOR - Insecure Direct Object Reference) devem resultar em `404 Not Found` ou `403 Forbidden`.

### Decisão
- Utilizar o helper `src/test/java/features/helpers/auth-helper.feature` para provisionar dois usuários distintos e independentes no mesmo teste:
  ```gherkin
  # Usuário Vitima / Dono do Recurso
  * def authUserB = call read('classpath:features/helpers/auth-helper.feature')
  # Usuário Atacante
  * def authUserA = call read('classpath:features/helpers/auth-helper.feature')
  ```
- O usuário B cria o ativo e obtém o `investment_id`.
- O usuário A tenta executar `GET`, `PUT` ou `DELETE` no `investment_id` do usuário B utilizando o token do usuário A.
- Validar status HTTP esperado (`404` ou `403`) e comprovar via consulta subsequente do usuário B que o ativo permaneceu íntegro e inalterado.

### Rationale
- Cumpre integralmente os Princípios I (Test Independence) e VII (DRY Helpers) da Constituição.
- Não há colisão nem dependência de ordem: ambos os usuários são provisionados e limpos dinamicamente.

### Alternativas Consideradas
- **Reutilizar um usuário pré-existente fixo**: Rejeitado por violar o Princípio I e causar race conditions em execuções com 3 threads paralelas.

---

## 4. Helper Reutilizável de Custódia (`investment-helper.feature`)

### Contexto
Cenários de teste para `GET /{investment_id}`, `PUT /{investment_id}`, `DELETE /{investment_id}` e recálculo dinâmico de `GET /summary` necessitam de um ativo previamente existente.

### Decisão
Criar o helper reutilizável `src/test/java/features/helpers/investment-helper.feature` marcado com `@ignore`:
- Parâmetros de entrada: `authHeader`, `ticker`, `nome`, `classe`, `quantidade`, `preco_medio`, `cotacao_atual` (com fallbacks padrão caso não sejam especificados).
- Executa `POST /api/v1/investments/`.
- Exporta: `investmentId`, `investmentResponse`, `createdTicker`, `totalInvestido`, `patrimonioAtual`.

### Rationale
- Elimina duplicação massiva de chamadas POST de setup em múltiplos arquivos `.feature`.
- Mantém o foco dos cenários de teste na operação sob validação (`PUT`, `DELETE`, `GET by ID`).

### Alternativas Consideradas
- **Executar POST inline em cada cenário**: Gera centenas de linhas de código duplicadas, violando o Princípio VII da Constituição.

---

## 5. Estratégia de Tagging e Execução Paralela

### Decisão
Adotar tags hierárquicas e descritivas:
- `@investments`: Tag de suite mestre.
- Sub-tags funcionais: `@create`, `@summary`, `@list`, `@detail`, `@update`, `@delete`.
- Tags de qualidade: `@smoke`, `@regression`, `@idor`, `@boundary`, `@security`, `@negative`.
- Tag de isolamento para helpers: `@ignore`.

### Rationale
Permite execução granular no CI/CD via `-Dkarate.tags="@investments and @smoke"` ou `-Dkarate.tags="@idor"`.
