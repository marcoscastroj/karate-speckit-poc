function fn() {
  var System = Java.type('java.lang.System');

  // Helper para buscar de variavel de ambiente do SO ou de system property (-Dkey=value)
  var getEnvOrProp = function(key, defaultValue) {
    var val = System.getenv(key);
    if (!val || val.trim().length === 0) {
      val = System.getProperty(key);
    }
    return val && val.trim().length > 0 ? val : defaultValue;
  };

  return {
    apiKey: getEnvOrProp('API_KEY', 'default-dev-key'),
    authToken: getEnvOrProp('AUTH_TOKEN', 'default-dev-token'),
    username: getEnvOrProp('API_USERNAME', 'dev-user'),
    password: getEnvOrProp('API_PASSWORD', 'dev-secret')
  };
}
