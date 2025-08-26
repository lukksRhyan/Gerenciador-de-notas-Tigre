class MyAppConfigs{
  static final MyAppConfigs _instance = MyAppConfigs._internal();

  factory MyAppConfigs() {
    return _instance;
  }

  MyAppConfigs._internal();

  // Adicione suas configurações abaixo
  String notesFolderPath = '';
  String xmlFolderPath = ''; // NOVO: pasta padrão dos XMLs
  bool isDebugMode = true;
}