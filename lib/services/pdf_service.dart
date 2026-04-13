import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PdfService {
  static final PdfService _instance = PdfService._internal();
  static PdfService get instance => _instance;
  PdfService._internal();

  final Dio _dio = Dio();

  /// Obtiene un archivo PDF desde la caché local o lo descarga si no existe.
  /// Retorna la ruta local del archivo.
  Future<String> getPdfFile(
    String url, 
    String id, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      
      // Sanitizar el ID para usarlo como nombre de archivo
      final String sanitizedId = id.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final String fileName = 'guide_$sanitizedId.pdf';
      final String filePath = p.join(directory.path, fileName);
      final File file = File(filePath);

      // Si el archivo ya existe, retornamos la ruta local directamente
      if (await file.exists()) {
        final int size = await file.length();
        if (size > 0) {
          debugPrint('PDF encontrado en caché: $filePath');
          // Si ya existe, llamamos al progreso al 100% para ser consistentes
          onProgress?.call(100, 100);
          return filePath;
        }
      }

      // Si no existe o está vacío, lo descargamos
      debugPrint('Descargando PDF desde: $url');
      await _dio.download(
        url, 
        filePath,
        onReceiveProgress: (received, total) {
          if (onProgress != null) {
            onProgress(received, total);
          }
          if (total != -1) {
            debugPrint('Descarga PDF: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );
      
      return filePath;
    } on DioException catch (e) {
      debugPrint('Error de red al descargar PDF: ${e.message}');
      throw Exception('No se pudo descargar el archivo. Verifica tu conexión a internet.');
    } catch (e) {
      debugPrint('Error inesperado al obtener PDF: $e');
      throw Exception('Ocurrió un error al procesar el archivo PDF.');
    }
  }

  /// Verifica si un PDF ya está en la caché local.
  Future<bool> isPdfCached(String id) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String sanitizedId = id.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final String fileName = 'guide_$sanitizedId.pdf';
    final String filePath = p.join(directory.path, fileName);
    return File(filePath).exists();
  }
}
