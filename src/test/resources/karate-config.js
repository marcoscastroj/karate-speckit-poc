function fn() {
  var env = karate.env || 'dev';
  karate.log('Iniciando execucao no ambiente:', env);

  // 1. Carrega configuracoes de URLs e timeouts por ambiente
  var envs = karate.read('classpath:config/environments.json');
  var envConfig = envs[env] || envs['dev'];

  // 2. Leitor utilitario de credenciais (le variaveis de ambiente / system properties)
  var credentials = karate.call('classpath:utils/credentials-reader.js');

  // 3. Helpers Java para geracao de dados dinâmicos (Datafaker) e utilitarios
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

  // 4. Configuracoes globais do Karate (timeouts, ssl, retry, etc.)
  karate.configure('connectTimeout', config.timeout);
  karate.configure('readTimeout', config.timeout);
  karate.configure('retry', { count: 12, interval: 10000 });

  return config;
}
