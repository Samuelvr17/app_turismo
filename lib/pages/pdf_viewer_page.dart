import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../services/pdf_service.dart';

class PdfViewerPage extends StatefulWidget {
  final String pdfUrl;
  final String id;
  final String title;

  const PdfViewerPage({
    super.key,
    required this.pdfUrl,
    required this.id,
    required this.title,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  double _downloadProgress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String localPath = await PdfService.instance.getPdfFile(
        widget.pdfUrl,
        widget.id,
        onProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (!mounted) return;

      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(localPath),
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().contains('Exception:') 
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Error al cargar el PDF: $e';
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 16),
            Text(
              _downloadProgress > 0 && _downloadProgress < 1
                  ? 'Descargando guía... ${(_downloadProgress * 100).toInt()}%'
                  : 'Cargando guía...',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeController,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
       return const Center(child: Text('Error al inicializar el visor de PDF'));
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onDocumentError: (error) {
        setState(() {
          _errorMessage = 'Error al mostrar el PDF: ${error.toString()}';
        });
      },
    );
  }
}
