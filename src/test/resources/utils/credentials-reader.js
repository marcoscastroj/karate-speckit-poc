function fn() {
  var CredentialUtils = Java.type('utils.CredentialUtils');

  var getEnvOrProp = function(key, defaultValue) {
    return CredentialUtils.getEnv(key, defaultValue);
  };

  return {
    apiKey: getEnvOrProp('API_KEY', 'default-dev-key'),
    authToken: getEnvOrProp('AUTH_TOKEN', 'default-dev-token'),
    username: getEnvOrProp('API_USERNAME', 'dev-user'),
    password: getEnvOrProp('API_PASSWORD', 'dev-secret')
  };
}
