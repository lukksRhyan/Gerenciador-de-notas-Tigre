; -- Configurações da Instalação --
[Setup]
; Use o nome do seu executável gerado pelo Flutter
AppName=Gerenciador de Notas Tigre
AppVersion=1.0
; AppVerName é exibido no Painel de Controle
AppPublisher=Lucas Rhyan
AppPublisherURL=
AppSupportURL=
AppUpdatesURL=
DefaultDirName={autopf}\Gerenciador de Notas Tigre
DefaultGroupName=Notas Tigre
OutputBaseFilename=NotasTigre_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; -- Arquivos a Serem Incluídos --
[Files]
; Fonte: Diretório do Release do Flutter
; Destino: Pasta de Instalação (caminho padrão)

; 1. Inclui o executável principal (runner.exe) e renomeia para o nome do app
Source: "D:\rhyan\notas_tigre\build\windows\x64\runner\Release\notas_tigre.exe"; DestDir: "{app}\NotasTigre.exe"; Flags: ignoreversion

; 2. Inclui o arquivo de DLL principal do Flutter
Source: "D:\rhyan\notas_tigre\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion

; 3. Inclui a pasta 'data' completa (contém assets, plugins, etc.)
Source: "D:\rhyan\notas_tigre\build\windows\x64\runner\Release\data*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; 4. Inclui os arquivos necessários de licença e outros binários da Microsoft
Source: "D:\rhyan\notas_tigre\build\windows\x64\runner\Release\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\rhyan\notas_tigre\build\windows\x64\runner\Release\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion

; -- Atalhos (Ícones) --
[Icons]
; Cria um atalho no Menu Iniciar
Name: "{group}\Gerenciador de Notas Tigre"; Filename: "{app}\NotasTigre.exe"
; Cria um atalho na Área de Trabalho (Desktop)
Name: "{autodesktop}\Gerenciador de Notas Tigre"; Filename: "{app}\NotasTigre.exe"; Tasks: desktopicon

; -- Tarefas Opcionais --
[Tasks]
Name: desktopicon; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}";