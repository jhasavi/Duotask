import 'package:flutter/material.dart';
import '../utils/timezone_options.dart';

/// Opens a searchable list of timezones and returns the chosen IANA name, or
/// null if dismissed.
Future<String?> showTimezonePicker(
  BuildContext context, {
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TimezonePickerSheet(current: current),
  );
}

class _TimezonePickerSheet extends StatefulWidget {
  final String current;

  const _TimezonePickerSheet({required this.current});

  @override
  State<_TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<_TimezonePickerSheet> {
  final List<TimezoneOption> _all = loadTimezoneOptions();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = filterTimezones(_all, _query);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Digest timezone',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                key: const Key('tz-search'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search city or UTC offset',
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No matching timezones'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final option = results[index];
                        final selected = option.name == widget.current;
                        return ListTile(
                          key: Key('tz-${option.name}'),
                          title: Text(option.name.replaceAll('_', ' ')),
                          subtitle: Text(option.offsetLabel),
                          trailing: selected ? const Icon(Icons.check) : null,
                          selected: selected,
                          onTap: () => Navigator.pop(context, option.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
