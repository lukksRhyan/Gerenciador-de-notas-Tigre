import 'package:flutter/material.dart';
import 'package:notas_tigre/models/nota.dart';
import 'package:notas_tigre/widgets/icms_calculator_dialog.dart';
import 'package:notas_tigre/widgets/note_detail_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'dart:convert';
import 'package:notas_tigre/utils/xml_parser.dart';
import 'package:notas_tigre/utils/excel_generator.dart';
import 'package:notas_tigre/utils/icms_calculator.dart';
import 'package:notas_tigre/widgets/product_value_input_dialog.dart'; // NOVO IMPORT

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerenciador de Notas Tigre',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const GerenciadorNotasPage(),
    );
  }
}

class GerenciadorNotasPage extends StatefulWidget {
  const GerenciadorNotasPage({super.key});

  @override
  State<GerenciadorNotasPage> createState() => _GerenciadorNotasPageState();
}

class _GerenciadorNotasPageState extends State<GerenciadorNotasPage> {
  final TextEditingController _noteNumberController = TextEditingController();
  List<Nota> _notes = [];
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    // Em uma aplicação sem backend e sem persistência local (e.g., Hive),
    // a lista de notas é mantida em memória e será esvaziada ao fechar o app.
    // Para iniciar, pode-se considerar carregar de um arquivo local se persistência for necessária.
    // Por enquanto, a lista inicia vazia.
  }

  Future<void> _listNotes() async {
    setState(() {
      _isLoading = true;
      _message = 'Listando notas carregadas...';
    });
    if (_notes.isEmpty) {
      _message = 'Nenhuma nota carregada ainda. Adicione uma nota.';
    } else {
      _message = '';
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _addNote() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      setState(() {
        _isLoading = true;
        _message = 'Lendo arquivo XML...';
      });

      try {
        final xmlContent = await file.readAsString();
        // Extrai os dados brutos da nota do XML
        final Map<String, dynamic> rawNoteData = XmlParser.extractNoteData(xmlContent);

        final String cfop = rawNoteData['CFOP'] as String;

        // SE FOR NOTA MÃE (CFOP 5922), PERGUNTA SOBRE VALORES UNITÁRIOS
        List<Produto> productsWithValues = (rawNoteData['Produtos'] as List)
            .map((p) => Produto.fromJson(p)).toList(); // Converte para lista de Produtos

        if (cfop == "5922") {
          final bool? manualInput = await showDialog<bool>(
            context: context,
            barrierDismissible: false, // Força o usuário a escolher uma opção
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Valores Unitários dos Produtos"),
                content: const Text("Deseja inserir os valores unitários dos produtos manualmente?"),
                actions: <Widget>[
                  TextButton(
                    child: const Text("Deixar Zerado"),
                    onPressed: () {
                      Navigator.of(context).pop(false); // Retorna false para zerado
                    },
                  ),
                  TextButton(
                    child: const Text("Inserir Manualmente"),
                    onPressed: () {
                      Navigator.of(context).pop(true); // Retorna true para manual
                    },
                  ),
                ],
              );
            },
          );

          if (manualInput == true) {
            // Se o usuário escolheu inserir manualmente, itera sobre os produtos
            for (int i = 0; i < productsWithValues.length; i++) {
              Produto product = productsWithValues[i];
              setState(() {
                _message = 'Inserindo valor para: ${product.descricao} (${product.codigo})...';
              });
              final double? value = await showDialog<double>(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return ProductValueInputDialog(
                    productCode: product.codigo,
                    productDescription: product.descricao,
                  );
                },
              );

              if (value != null) {
                productsWithValues[i] = product.copyWith(valorUnitario: value);
              } else {
                // Se o usuário cancelar, pode-se optar por manter o valor 0 ou parar
                productsWithValues[i] = product.copyWith(valorUnitario: 0.0);
              }
            }
          }
          // Se manualInput for false ou null, os valores de productsWithValues (valorUnitario) já são 0.0 por padrão.
        }

        // Agora, use XmlParser para processar e adicionar a nota à lista em memória,
        // passando os produtos já com os valores unitários definidos.
        final processedNota = XmlParser.addNotaToNotesList(rawNoteData, productsWithValues, _notes);

        setState(() {
          _message = 'Nota ${processedNota.numeroNota} processada e adicionada com sucesso!';
        });
        _listNotes();
      } catch (e) {
        setState(() {
          _message = 'Erro ao processar o arquivo XML: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _message = 'Nenhum arquivo XML selecionado.';
      });
    }
  }

  Future<void> _consultNote() async {
    final String numeroNota = _noteNumberController.text.trim();
    if (numeroNota.isEmpty) {
      setState(() {
        _message = 'Por favor, digite um número de nota válido.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Consultando nota $numeroNota...';
    });
    try {
      final Nota? nota = _notes.firstWhere(
        (n) => n.numeroNota == numeroNota,
        orElse: () => throw Exception('Nota $numeroNota não encontrada.'),
      );

      setState(() {
        _message = '';
      });
      _showNoteDetailsDialog(nota!);
    } catch (e) {
      setState(() {
        _message = 'Erro ao consultar nota $numeroNota: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNoteDetailsDialog(Nota nota) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return NoteDetailDialog(
          nota: nota,
          onExport: (String noteNumber) async {
            await _exportExcel(noteNumber);
          },
        );
      },
    );
  }

  Future<void> _exportExcel(String numeroNota) async {
    setState(() {
      _isLoading = true;
      _message = 'Exportando Excel para nota $numeroNota...';
    });
    try {
      final Nota notaToExport = _notes.firstWhere(
        (n) => n.numeroNota == numeroNota,
        orElse: () => throw Exception('Nota $numeroNota não encontrada para exportação.'),
      );

      final excelBytes = await ExcelGenerator.generateExcelData(notaToExport);

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception("Não foi possível acessar o diretório de downloads.");
      }
      final filePath = '${directory.path}/nota_${numeroNota}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excelBytes);

      setState(() {
        _message = 'Arquivo Excel salvo em: $filePath';
      });
      await OpenFilex.open(filePath);
    } catch (e) {
      setState(() {
        _message = 'Erro ao exportar Excel: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showIcmsCalculatorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return IcmsCalculatorDialog(
          onCalculate: (double value) async {
            setState(() {
              _isLoading = true;
              _message = 'Calculando ICMS...';
            });
            try {
              final results = IcmsCalculator.calculateBaseICMS(value);

              setState(() {
                _message = 'Base de cálculo: R\$ ${results['base'].toStringAsFixed(2)} \nICMS Calculado: R\$ ${results['ICMS'].toStringAsFixed(2)}';
              });
            } catch (e) {
              setState(() {
                _message = 'Erro ao calcular ICMS: $e';
              });
            } finally {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📜 Gerenciador de Notas Tigre"),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: ElevatedButton.icon(
                  onPressed: _listNotes,
                  icon: const Icon(Icons.folder_open),
                  label: const Text("Listar Notas Carregadas"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 250,
                child: ElevatedButton.icon(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add_circle),
                  label: const Text("Adicionar Nota (XML)"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Digite o número da nota:"),
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _noteNumberController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    hintText: 'Número da Nota',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 250,
                child: ElevatedButton.icon(
                  onPressed: _consultNote,
                  icon: const Icon(Icons.search),
                  label: const Text("Consultar Nota"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 250,
                child: ElevatedButton.icon(
                  onPressed: _showIcmsCalculatorDialog,
                  icon: const Icon(Icons.calculate),
                  label: const Text("Calcular ICMS"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : _message.isNotEmpty
                      ? Text(
                          _message,
                          style: TextStyle(
                            color: _message.contains('Erro') ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : Container(),
              const SizedBox(height: 10),
              Expanded(
                child: _notes.isEmpty && !_isLoading && _message.isEmpty
                    ? const Text("Adicione um arquivo XML para começar a gerenciar notas localmente.")
                    : ListView.builder(
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          final note = _notes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: const Icon(Icons.description, color: Colors.blue),
                              title: Text('Nota: ${note.numeroNota}'),
                              subtitle: Text('CFOP: ${note.cfop} | Total: R\$${note.total.toStringAsFixed(2)}'),
                              onTap: () {
                                _showNoteDetailsDialog(note);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
