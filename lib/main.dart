import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const PercentageCalculatorApp());
}

String fmt(double v) {
  if (v.isNaN || v.isInfinite) return '—';
  // 2 decimals, trimmed (e.g. 25 not 25.00, 12.5 not 12.50).
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return s;
}

double? parse(String s) {
  if (s.trim().isEmpty) return null;
  return double.tryParse(s.trim().replaceAll(',', ''));
}

enum CalcMode { percentOf, whatPercent, findWhole, change, discount, tipTax }

extension CalcModeInfo on CalcMode {
  String get label {
    switch (this) {
      case CalcMode.percentOf:
        return 'What is % of?';
      case CalcMode.whatPercent:
        return 'What % is it?';
      case CalcMode.findWhole:
        return 'Find the whole';
      case CalcMode.change:
        return '% increase / decrease';
      case CalcMode.discount:
        return 'Discount & sale price';
      case CalcMode.tipTax:
        return 'Tip, tax & split';
    }
  }

  String get hint {
    switch (this) {
      case CalcMode.percentOf:
        return 'Example: 20% of 150 = 30';
      case CalcMode.whatPercent:
        return 'Example: 30 is what % of 150? = 20%';
      case CalcMode.findWhole:
        return 'Example: 30 is 20% of what? = 150';
      case CalcMode.change:
        return 'Example: 80 → 100 = +25%';
      case CalcMode.discount:
        return 'Example: \$120 with 25% off = \$90, you save \$30';
      case CalcMode.tipTax:
        return 'Bill + tip + tax, split between people';
    }
  }
}

class PercentageCalculatorApp extends StatelessWidget {
  const PercentageCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Percentage Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  BannerAd? _banner;
  bool _bannerReady = false;
  InterstitialAd? _interstitial;
  int _calcCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBanner();
    _loadInterstitial();
  }

  void _loadBanner() {
    _banner = BannerAd(
      adUnitId: AdsConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerReady = true),
        onAdFailedToLoad: (_, __) => setState(() => _bannerReady = false),
      ),
    )..load();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  // Called after a calculation completes. Policy-safe: never on load/exit,
  // at most once per 5 calculations, only if already loaded.
  void _maybeShowInterstitial() {
    _calcCount++;
    if (_calcCount % AdsConfig.calculationsBeforeInterstitial != 0) return;
    final ad = _interstitial;
    if (ad == null) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
    _interstitial = null;
  }

  @override
  void dispose() {
    _banner?.dispose();
    _interstitial?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CalculatorPage(onCalculated: _maybeShowInterstitial),
      const HistoryPage(),
      const LearnPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Percentage Calculator'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(child: pages[_tab]),
          if (_bannerReady && _banner != null)
            SizedBox(
              width: _banner!.size.width.toDouble(),
              height: _banner!.size.height.toDouble(),
              child: AdWidget(ad: _banner!),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate_outlined), label: 'Calculate'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Learn'),
        ],
      ),
    );
  }
}

class CalcResult {
  final String headline;
  final List<String> lines;
  final String formula;
  const CalcResult(this.headline, this.lines, this.formula);
}

class CalculatorPage extends StatefulWidget {
  final VoidCallback onCalculated;
  const CalculatorPage({super.key, required this.onCalculated});
  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  CalcMode _mode = CalcMode.percentOf;
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();
  final _d = TextEditingController();
  CalcResult? _result;
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    _d.dispose();
    super.dispose();
  }

  List<String> get _labels {
    switch (_mode) {
      case CalcMode.percentOf:
        return ['Percentage (%)', 'Of number'];
      case CalcMode.whatPercent:
        return ['Part (X)', 'Whole (Y)'];
      case CalcMode.findWhole:
        return ['Part (X)', 'Percentage (%)'];
      case CalcMode.change:
        return ['From (old value)', 'To (new value)'];
      case CalcMode.discount:
        return ['Original price', 'Discount (%)'];
      case CalcMode.tipTax:
        return ['Bill amount', 'Tip (%)'];
    }
  }

  void _calculate() {
    final a = parse(_a.text);
    final b = parse(_b.text);
    final c = parse(_c.text);
    final d = parse(_d.text);
    setState(() {
      _error = null;
      _result = null;
      if (_mode == CalcMode.tipTax) {
        if (a == null || b == null) {
          _error = 'Enter the bill and a tip %. Tax % and people are optional.';
          return;
        }
        final taxPct = c ?? 0;
        final people = (d ?? 1).clamp(1, 1000).toInt();
        final tip = a * b / 100;
        final tax = a * taxPct / 100;
        final total = a + tip + tax;
        _result = CalcResult(
          'Total: ${fmt(total)}  •  Each: ${fmt(total / people)}',
          [
            'Tip (${fmt(b)}%): ${fmt(tip)}',
            'Tax (${fmt(taxPct)}%): ${fmt(tax)}',
            'Bill: ${fmt(a)}  •  Split between $people',
          ],
          'Tip = bill × tip% ÷ 100  •  Total = bill + tip + tax',
        );
      } else if (a == null || b == null) {
        _error = 'Please enter both numbers.';
        return;
      } else if (_mode == CalcMode.percentOf) {
        final r = a * b / 100;
        _result = CalcResult('${fmt(a)}% of ${fmt(b)} = ${fmt(r)}',
            ['Answer: $r'], '${fmt(a)} × ${fmt(b)} ÷ 100 = ${fmt(r)}');
      } else if (_mode == CalcMode.whatPercent) {
        if (b == 0) {
          _error = 'The whole cannot be 0.';
          return;
        }
        final r = a / b * 100;
        _result = CalcResult('${fmt(a)} is ${fmt(r)}% of ${fmt(b)}',
            ['Answer: ${fmt(r)}%'], '${fmt(a)} ÷ ${fmt(b)} × 100 = ${fmt(r)}%');
      } else if (_mode == CalcMode.findWhole) {
        if (b == 0) {
          _error = 'The percentage cannot be 0.';
          return;
        }
        final r = a / b * 100;
        _result = CalcResult('${fmt(a)} is ${fmt(b)}% of ${fmt(r)}',
            ['Whole number: ${fmt(r)}'], '${fmt(a)} ÷ ${fmt(b)} × 100 = ${fmt(r)}');
      } else if (_mode == CalcMode.change) {
        if (a == 0) {
          _error = 'The old value cannot be 0.';
          return;
        }
        final diff = b - a;
        final r = diff / a * 100;
        final word = r >= 0 ? 'increase' : 'decrease';
        _result = CalcResult('${fmt(r.abs())}% $word',
            ['Change: ${fmt(diff)}  (${fmt(a)} → ${fmt(b)})'],
            '(${fmt(b)} − ${fmt(a)}) ÷ ${fmt(a)} × 100 = ${fmt(r)}%');
      } else if (_mode == CalcMode.discount) {
        final saved = a * b / 100;
        final finalPrice = a - saved;
        _result = CalcResult('You pay ${fmt(finalPrice)}  •  You save ${fmt(saved)}',
            ['Original: ${fmt(a)}  •  Discount: ${fmt(b)}%'],
            'Save = ${fmt(a)} × ${fmt(b)}%  •  Pay = original − save');
      }
    });
    if (_result != null) {
      widget.onCalculated();
      _saveToHistory();
    }
  }

  Future<void> _saveToHistory() async {
    if (_result == null) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('history') ?? [];
    list.insert(0, '${_mode.label}: ${_result!.headline}');
    await prefs.setStringList('history', list.take(100).toList());
  }

  void _clear() {
    setState(() {
      _a.clear();
      _b.clear();
      _c.clear();
      _d.clear();
      _result = null;
      _error = null;
    });
  }

  Widget _field(TextEditingController c, String label, {String? suffix}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _calculate(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CalcMode.values.map((m) {
              final sel = m == _mode;
              return ChoiceChip(
                label: Text(m.label),
                selected: sel,
                onSelected: (_) => setState(() {
                      _mode = m;
                      _result = null;
                      _error = null;
                    }),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(_mode.hint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          _field(_a, labels[0], suffix: _mode == CalcMode.percentOf ? '%' : null),
          const SizedBox(height: 12),
          _field(_b, labels[1], suffix: _mode == CalcMode.discount ? '%' : null),
          if (_mode == CalcMode.tipTax) ...[
            const SizedBox(height: 12),
            _field(_c, 'Tax (%) — optional', suffix: '%'),
            const SizedBox(height: 12),
            _field(_d, 'Split between (people) — optional'),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _calculate,
                  child: const Text('Calculate'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: _clear, child: const Text('Clear')),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_result!.headline,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ..._result!.lines.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(l),
                        )),
                    const Divider(),
                    Text(_result!.formula,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _result!.headline));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Result copied')));
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy result'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Works offline. No account needed. Results stay on your device.'),
        ],
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _items = prefs.getStringList('history') ?? []);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No calculations yet.\nYour recent results will appear here.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              title: Text(_items[i]),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => Clipboard.setData(ClipboardData(text: _items[i])),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('history');
              _load();
            },
            child: const Text('Clear history'),
          ),
        ),
      ],
    );
  }
}

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    const cards = [
      (
        'What is a percentage?',
        'A percentage is a number out of 100. 25% means 25 out of every 100. '
            'If 25 of 100 cars are white, 25% of the cars are white.'
      ),
      (
        'How do you work it out?',
        'Divide the part by the whole, then multiply by 100. '
            '20 red apples out of 50: 20 ÷ 50 × 100 = 40%.'
      ),
      (
        'Discounts',
        'A 25% discount on \$120 saves \$30, so you pay \$90. '
            'Save = price × discount% ÷ 100.'
      ),
      (
        'Increase and decrease',
        'From 80 to 100 is a rise of 20. 20 ÷ 80 × 100 = 25% increase. '
            'The same maths works for price rises, salary hikes and test scores.'
      ),
      (
        'Tips and tax',
        'Add tip and tax to the bill separately, then split the total. '
            'A \$50 bill with 10% tip and 5% tax is \$57.50 in total.'
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Learn percentages',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Short explanations with everyday examples.'),
        const SizedBox(height: 16),
        ...cards.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.$1, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(c.$2),
                  ],
                ),
              ),
            )),
        // Keep the JSON decode import used (history entries are stored as strings).
        const SizedBox(height: 8),
        Text('Tip: results are saved automatically — see the History tab.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
