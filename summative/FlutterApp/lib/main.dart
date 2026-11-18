import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Address of the deployed API.
/// Default = your Render URL (edit the text below).
/// For a local API on the Android emulator run:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://er-visit-time-api.onrender.com',
);

void main() => runApp(const VisitTimeApp());

class VisitTimeApp extends StatelessWidget {
  const VisitTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ER Visit Time',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        scaffoldBackgroundColor: const Color(0xFFF2F7F6),
      ),
      home: const PredictPage(),
    );
  }
}

/// One model input: its JSON key (must match the API), the label the user sees,
/// and, for choice fields, the allowed values with a short explanation.
class FieldSpec {
  final String key;
  final String label;
  final IconData icon;
  final Map<String, String>? choices; // null = the user types a number
  final String? hint;
  const FieldSpec(this.key, this.label, this.icon, {this.choices, this.hint});
}

const List<FieldSpec> fieldSpecs = [
  FieldSpec('age', 'Age (years)', Icons.cake_outlined, hint: '0 - 120'),
  FieldSpec('arrival_hour', 'Arrival hour (0-23)', Icons.schedule, hint: 'e.g. 14 = 2 pm'),
  FieldSpec('sex', 'Sex', Icons.person_outline,
      choices: {'Female': '', 'Male': ''}),
  FieldSpec('day_of_week', 'Day of arrival', Icons.calendar_today_outlined, choices: {
    'Monday': '', 'Tuesday': '', 'Wednesday': '', 'Thursday': '',
    'Friday': '', 'Saturday': '', 'Sunday': '',
  }),
  FieldSpec('arrived_by_ambulance', 'Arriving by ambulance?', Icons.local_hospital_outlined,
      choices: {'Yes': '', 'No': ''}),
  FieldSpec('urgency', 'Urgency (set by the triage nurse)', Icons.priority_high, choices: {
    'Immediate': 'Life-threatening, seen right away',
    'Emergent': 'Very urgent, seen within minutes',
    'Urgent': 'Needs prompt care',
    'Semi-urgent': 'Can wait a little',
    'Non-urgent': 'Minor problem',
  }),
  FieldSpec('injury_related', 'Injury-related visit?', Icons.healing_outlined,
      choices: {'Yes': '', 'No': ''}),
  FieldSpec('insurance', 'Insurance', Icons.badge_outlined, choices: {
    'Private': '', 'Medicare': '', 'Medicaid': '', 'Self-pay': '', 'Other': '',
  }),
];

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  final Map<String, TextEditingController> _controllers = {
    for (final f in fieldSpecs) f.key: TextEditingController(),
  };

  bool _loading = false;
  String? _resultTitle; // e.g. "about 4 h 39 min"
  String? _resultDetail; // e.g. "279.3 minutes in total"
  String? _errorText; // shown in the same display area as the result

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Builds the JSON body. Empty fields are left out so the API reports "Field required";
  /// text that is not a whole number is sent as-is so the API reports the type error.
  Map<String, dynamic> _buildBody() {
    final body = <String, dynamic>{};
    for (final f in fieldSpecs) {
      final text = _controllers[f.key]!.text.trim();
      if (text.isEmpty) continue;
      body[f.key] = f.choices == null ? (int.tryParse(text) ?? text) : text;
    }
    return body;
  }

  String _labelFor(String key) =>
      fieldSpecs.firstWhere((f) => f.key == key, orElse: () => fieldSpecs.first).label;

  /// Turns the API's validation error into short readable lines.
  String _readableError(dynamic decoded) {
    if (decoded is Map && decoded['detail'] is List) {
      final lines = <String>[];
      for (final item in decoded['detail']) {
        if (item is Map) {
          final loc = item['loc'];
          final key = (loc is List && loc.isNotEmpty) ? loc.last.toString() : '';
          final name = fieldSpecs.any((f) => f.key == key) ? _labelFor(key) : key;
          lines.add('• $name: ${item['msg']}');
        }
      }
      if (lines.isNotEmpty) return lines.join('\n');
    }
    if (decoded is Map && decoded['detail'] != null) return decoded['detail'].toString();
    return 'The server could not process this request.';
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _resultTitle = null;
      _resultDetail = null;
      _errorText = null;
    });
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(_buildBody()),
          )
          .timeout(const Duration(seconds: 75)); // a sleeping free Render service needs up to a minute
      final decoded = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final minutes = (decoded['predicted_visit_minutes'] as num).toDouble();
        setState(() {
          _resultTitle = decoded['predicted_visit_text'].toString();
          _resultDetail = '${minutes.toStringAsFixed(0)} minutes in total';
        });
      } else {
        setState(() => _errorText = _readableError(decoded));
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _errorText =
            'The server took too long to answer. A free server may be waking up, so try again in a minute.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = 'Could not reach the server. Check your internet connection and the API address.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(FieldSpec spec) async {
    final choices = spec.choices!;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(spec.label, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final entry in choices.entries)
              ListTile(
                title: Text(entry.key),
                subtitle: entry.value.isEmpty ? null : Text(entry.value),
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _controllers[spec.key]!.text = chosen);
  }

  Widget _field(FieldSpec spec) {
    final isChoice = spec.choices != null;
    return TextField(
      controller: _controllers[spec.key],
      readOnly: isChoice,
      keyboardType: isChoice
          ? TextInputType.none
          : const TextInputType.numberWithOptions(signed: true, decimal: true),
      textInputAction: TextInputAction.next,
      onTap: isChoice ? () => _pick(spec) : null,
      decoration: InputDecoration(
        labelText: spec.label,
        hintText: spec.hint,
        prefixIcon: Icon(spec.icon),
        suffixIcon: isChoice ? const Icon(Icons.arrow_drop_down) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _resultArea(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget child;
    Color background;
    if (_loading) {
      background = Colors.white;
      child = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(width: 14),
          Flexible(child: Text('Predicting... the first call can take up to a minute.')),
        ],
      );
    } else if (_errorText != null) {
      background = const Color(0xFFFDECEA);
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 8),
            Text('Please check your input',
                style: TextStyle(fontWeight: FontWeight.bold, color: scheme.error)),
          ]),
          const SizedBox(height: 8),
          Text(_errorText!),
        ],
      );
    } else if (_resultTitle != null) {
      background = const Color(0xFFE0F2F1);
      child = Column(
        children: [
          const Text('Expected time at the hospital'),
          const SizedBox(height: 6),
          Text(_resultTitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
          const SizedBox(height: 4),
          Text(_resultDetail ?? ''),
        ],
      );
    } else {
      background = Colors.white;
      child = const Text('Fill in the details above and tap Predict.', textAlign: TextAlign.center);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB2DFDB)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ER Visit Time'),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How long will my emergency visit take?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Enter what is known when the patient arrives.'),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _field(fieldSpecs[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _field(fieldSpecs[1])),
                ],
              ),
              for (final spec in fieldSpecs.skip(2)) ...[
                const SizedBox(height: 12),
                _field(spec),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _predict,
                  child: const Text('Predict', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 20),
              _resultArea(context),
              const SizedBox(height: 8),
              const Text(
                'A rough estimate from US hospital data. It is not medical advice.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
