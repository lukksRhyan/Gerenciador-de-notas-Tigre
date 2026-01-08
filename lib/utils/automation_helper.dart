import 'dart:io';
import 'package:notas_tigre/models/nota.dart';
import 'package:notas_tigre/utils/icms_calculator.dart';

class AutomacaoSistema {
  static Future<void> executarLancamento(Produto produto) async {
    final icms = IcmsCalculator.calculateBaseICMS(produto.quantidade * produto.valorUnitario);
    
    final codigo = produto.codigo.replaceAll(RegExp(r'^0+'), '');
    final qtd = produto.quantidade.toString();
    final vlrUnit = produto.valorUnitario.toStringAsFixed(4);
    final baseCalc = icms['base'].toStringAsFixed(2);
    final valorIcms = icms['ICMS'].toStringAsFixed(2);

    try {
      // 1. Obtém o caminho absoluto da pasta do projeto para encontrar o script
      // Em desenvolvimento, o script está em lib/utils/
      final scriptPath = '${Directory.current.path}/lib/utils/automacao.py';
      
      print("Tentando executar: $scriptPath");

      // 2. Tenta rodar usando 'python' ou 'python3' caso um falhe
      final result = await Process.run('python', [
        scriptPath,
        codigo,
        qtd,
        vlrUnit,
        baseCalc,
        valorIcms
      ]);

      // 3. Log de depuração para ver o que o Python respondeu
      if (result.stdout.toString().isNotEmpty) print("Saída Python: ${result.stdout}");
      if (result.stderr.toString().isNotEmpty) {
        print("Erro Python: ${result.stderr}");
      }
      
    } catch (e) {
      print("Erro crítico ao chamar o processo: $e");
    }
  }
}