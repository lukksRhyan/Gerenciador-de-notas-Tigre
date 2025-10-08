class MyAppConfigs{
  static final MyAppConfigs _instance = MyAppConfigs._internal();

  factory MyAppConfigs() {
    return _instance;
  }

  MyAppConfigs._internal();

  String notesFolderPath = '';
  String xmlFolderPath = '';
  bool isDebugMode = true;
}