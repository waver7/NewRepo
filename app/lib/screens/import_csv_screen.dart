import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/csv_importer.dart';
import '../state/app_state.dart';
import '../ui/format.dart';

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  CsvTable? _table;
  ColumnMapping? _mapping;
  List<ImportPreviewRow> _preview = [];
  String? _accountId;
  String? _fileName;
  bool _importing = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'tsv'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final text = await File(path).readAsString();
    final table = CsvImporter.parse(text);
    final mapping = CsvImporter.inferMapping(table);
    setState(() {
      _fileName = result!.files.single.name;
      _table = table;
      _mapping = mapping;
      _preview = CsvImporter.buildRows(table, mapping);
    });
  }

  void _remap() {
    if (_table == null || _mapping == null) return;
    setState(
        () => _preview = CsvImporter.buildRows(_table!, _mapping!));
  }

  Future<void> _import() async {
    final app = context.read<AppState>();
    if (_accountId == null || _preview.isEmpty) return;
    setState(() => _importing = true);
    final txns =
        CsvImporter.toTransactions(_preview, _accountId!, app.categorizer);
    final result = await app.importTxns(txns);
    if (!mounted) return;
    setState(() => _importing = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import complete'),
        content: Text(
            '${result.imported} new transactions imported.\n'
            '${result.duplicates} duplicates skipped.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    _accountId ??= app.accounts.isNotEmpty ? app.accounts.first.id : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(_fileName ?? 'Choose a CSV file'),
              subtitle: Text(_table == null
                  ? 'Exports from any bank work — Lumen maps the columns'
                  : '${_table!.rows.length} data rows · '
                      '${_preview.length} parsed'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickFile,
            ),
          ),
          if (_table != null && _mapping != null) ...[
            const SizedBox(height: 16),
            Text('Column mapping',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Detected automatically — adjust if a column looks wrong.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            _mappingDropdown('Date column', _mapping!.dateCol,
                (v) => setState(() {
                      _mapping!.dateCol = v;
                      _remap();
                    })),
            _mappingDropdown('Amount column', _mapping!.amountCol,
                (v) => setState(() {
                      _mapping!.amountCol = v;
                      _mapping!.debitCol = null;
                      _mapping!.creditCol = null;
                      _remap();
                    })),
            _mappingDropdown('Description column', _mapping!.descCol,
                (v) => setState(() {
                      _mapping!.descCol = v;
                      _remap();
                    })),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Flip amount sign'),
              subtitle:
                  const Text('Use if expenses show as income after parsing'),
              value: _mapping!.flipSign,
              onChanged: (v) => setState(() {
                _mapping!.flipSign = v;
                _remap();
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration:
                  const InputDecoration(labelText: 'Import into account'),
              items: [
                for (final a in app.accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            Text('Preview (first 10)',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final r in _preview.take(10))
                    ListTile(
                      dense: true,
                      title: Text(r.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(r.date),
                      trailing: Text(
                        Fmt.signedMoney(r.amountCents, app.currency),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: r.amountCents > 0 ? scheme.primary : null,
                        ),
                      ),
                    ),
                  if (_preview.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'Nothing parsed — check the column mapping above.'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed:
                  _preview.isEmpty || _importing || _accountId == null
                      ? null
                      : _import,
              child: Text(_importing
                  ? 'Importing…'
                  : 'Import ${_preview.length} transactions'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mappingDropdown(
      String label, int? value, ValueChanged<int?> onChanged) {
    final header = _table!.header;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<int>(
        initialValue: value != null && value < header.length ? value : null,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var i = 0; i < header.length; i++)
            DropdownMenuItem(
                value: i,
                child: Text(header[i].isEmpty ? 'Column ${i + 1}' : header[i])),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
