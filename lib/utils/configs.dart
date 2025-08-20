class MyAppConfigs{
  static final MyAppConfigs _instance = MyAppConfigs._internal();

  factory MyAppConfigs() {
    return _instance;
  }

  MyAppConfigs._internal();

  // Adicione suas configurações abaixo
  String notesFolderPath = '';
  bool isDebugMode = true;
}