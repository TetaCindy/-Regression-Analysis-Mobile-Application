import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Base URL of the API (no trailing slash). Defaults to the deployed Render service.
// To test against a local API from the Android emulator, run:
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://YOUR-SERVICE.onrender.com',
);

void main() => runApp(const ProductivityApp());

class ProductivityApp extends StatelessWidget {
  const ProductivityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garment Productivity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const PredictPage(),
    );
  }
}

/// One text field per input variable the model needs (11 in total).
class InputSpec {
  final String key; // must match the field name in the API's Pydantic model
  final String label;
  final String hint;
  final bool numeric;
  const InputSpec(this.key, this.label, this.hint, {this.numeric = true});
}

const List<InputSpec> inputSpecs = [
  InputSpec('department', 'Department', 'sewing or finishing', numeric: false),
  InputSpec(
    'day',
    'Day of the week',
    'Monday ... Thursday, Saturday, Sunday',
    numeric: false,
  ),
  InputSpec('team', 'Team number', '1 to 12'),
  InputSpec(
    'targeted_productivity',
    'Targeted productivity',
    '0 to 1, e.g. 0.8',
  ),
  InputSpec('smv', 'Standard minute value (SMV)', '0 to 100, e.g. 26.16'),
  InputSpec('over_time', 'Overtime (minutes)', '0 to 30000, e.g. 7080'),
  InputSpec('incentive', 'Incentive (BDT)', '0 to 5000, e.g. 98'),
  InputSpec('idle_time', 'Idle time (minutes)', '0 to 500, e.g. 0'),
  InputSpec('idle_men', 'Idle workers', '0 to 100, e.g. 0'),
  InputSpec('no_of_style_change', 'Number of style changes', '0 to 5, e.g. 0'),
  InputSpec('no_of_workers', 'Number of workers', '1 to 100, e.g. 59'),
];

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  final Map<String, TextEditingController> _controllers = {
    for (final spec in inputSpecs) spec.key: TextEditingController(),
  };
  final ScrollController _scroll = ScrollController();

  bool _loading = false;
  bool _isError = false;
  String _message = 'Fill in all fields and press Predict.';

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  /// Builds the JSON body, sends it to POST /predict and shows the result or the error.
  Future<void> _predict() async {
    setState(() {
      _loading = true;
      _isError = false;
      _message = 'Predicting...';
    });

    // Empty fields are left out so the API answers "Field required".
    // Numeric fields that are not numbers are sent as text so the API reports the type error.
    final Map<String, dynamic> body = {};
    for (final spec in inputSpecs) {
      final text = _controllers[spec.key]!.text.trim();
      if (text.isEmpty) continue;
      body[spec.key] = spec.numeric ? (num.tryParse(text) ?? text) : text;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 60),
          ); // a sleeping Render service can take ~1 minute

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final value = (data['predicted_productivity'] as num).toDouble();
        _show(
          'Predicted productivity: ${value.toStringAsFixed(4)}\n'
          '(about ${(value * 100).toStringAsFixed(1)}% of the target output)',
          false,
        );
      } else if (response.statusCode == 422) {
        _show(_readValidationErrors(response.body), true);
      } else {
        _show('Server error (${response.statusCode}). Please try again.', true);
      }
    } catch (_) {
      _show(
        'Could not reach the API. Check your internet connection or wait a moment '
        'if the server is waking up, then try again.',
        true,
      );
    }
  }

  /// Turns FastAPI's 422 response into readable lines like "team: Field required".
  String _readValidationErrors(String responseBody) {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final details = data['detail'] as List<dynamic>;
      final lines = details.map((d) {
        final loc = (d['loc'] as List<dynamic>)
            .where((p) => p != 'body')
            .join(' > ');
        return '$loc: ${d['msg']}';
      });
      return 'Please fix these inputs:\n${lines.join('\n')}';
    } catch (_) {
      return 'Some inputs are invalid. Please check them and try again.';
    }
  }

  void _show(String message, bool isError) {
    setState(() {
      _loading = false;
      _isError = isError;
      _message = message;
    });
    // Scroll down so the result is visible under the button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Garment Productivity Predictor')),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the details of a team\'s shift to predict its actual productivity.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              for (final spec in inputSpecs) ...[
                TextField(
                  controller: _controllers[spec.key],
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: spec.label,
                    helperText: spec.hint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _predict,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Predict'),
                ),
              ),
              const SizedBox(height: 16),
              // Display area: shows the prediction, or a readable error message.
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 90),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isError
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isError
                        ? scheme.onErrorContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
