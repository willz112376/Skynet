import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skynet',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.cyanAccent,
        scaffoldBackgroundColor: Color(0xFF0B0F14),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> recentFiles = [];
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      recentFiles = prefs?.getStringList('recentFiles') ?? [];
    });
  }

  Future<void> _pickFile() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf','txt','md','png','jpg','jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      _openFile(path);
      _addToRecent(path);
    }
  }

  void _addToRecent(String path) {
    recentFiles.remove(path);
    recentFiles.insert(0, path);
    if (recentFiles.length > 50) recentFiles = recentFiles.sublist(0,50);
    prefs?.setStringList('recentFiles', recentFiles);
    setState((){});
  }

  void _openFile(String path) {
    String ext = p.extension(path).toLowerCase();
    if (ext == '.pdf') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PDFViewerPage(
          path: path,
          onBookmark: (page){ _saveBookmark(path, page); }
        )
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TextViewerPage(path: path)
      ));
    }
  }

  Future<void> _saveBookmark(String path, int page) async {
    final key = 'bookmark:$path';
    await prefs?.setInt(key, page);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bookmarked page ${page+1}'))
    );
  }

  int? _getBookmark(String path) {
    final key = 'bookmark:$path';
    return prefs?.getInt(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skynet'),
        backgroundColor: Colors.black,
        elevation: 2,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: Icon(Icons.folder_open),
                  label: Text('Open file'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                ),
                SizedBox(width: 12),
                Text('Recent files', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: recentFiles.length,
              itemBuilder: (context, idx){
                final path = recentFiles[idx];
                final name = p.basename(path);
                final bookmark = _getBookmark(path);
                return ListTile(
                  title: Text(name, style: TextStyle(color: Colors.white)),
                  subtitle: Text(path, style: TextStyle(color: Colors.white54)),
                  trailing: bookmark != null
                    ? Text('Page ${bookmark+1}', style: TextStyle(color: Colors.cyanAccent))
                    : null,
                  onTap: () => _openFile(path),
                  leading: Icon(Icons.insert_drive_file, color: Colors.cyanAccent),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class PDFViewerPage extends StatefulWidget {
  final String path;
  final void Function(int page) onBookmark;
  PDFViewerPage({required this.path, required this.onBookmark});
  @override
  _PDFViewerPageState createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  int _pages = 0;
  int _currentPage = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${p.basename(widget.path)}'),
        actions: [
          IconButton(
            icon: Icon(Icons.bookmark_add),
            onPressed: () {
              widget.onBookmark(_currentPage);
            },
          )
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            onRender: (_pages) {
              setState(() {
                this._pages = _pages!;
                isReady = true;
              });
            },
            onViewCreated: (PDFViewController pdfViewController) {},
            onPageChanged: (int? page, int? total) {
              setState(() {
                _currentPage = page ?? 0;
              });
            },
            onError: (error) {
              setState(() {
                errorMessage = error.toString();
              });
            },
            onPageError: (page, error) {
              setState(() {
                errorMessage = '$page: ${error.toString()}';
              });
            },
          ),
          if (!isReady)
            Center(child: CircularProgressIndicator()),
          if (errorMessage.isNotEmpty)
            Center(child: Text(errorMessage)),
        ],
      ),
    );
  }
}

class TextViewerPage extends StatelessWidget {
  final String path;
  TextViewerPage({required this.path});
  @override
  Widget build(BuildContext context) {
    String content = '';
    try {
      content = File(path).readAsStringSync();
    } catch (e) {
      content = 'Could not read file: $e';
    }
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(path))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: SelectableText(content),
      ),
    );
  }
}
