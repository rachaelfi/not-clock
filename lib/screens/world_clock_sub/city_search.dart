import 'package:flutter/material.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/models/world_clock_city.dart';
import 'package:not_clock/services/time_now_service.dart';

class CitySearchScreen extends StatefulWidget {
  final List<WorldClockCity> alreadyAdded;
  final AppSettings settings;

  const CitySearchScreen({
    super.key,
    required this.alreadyAdded,
    required this.settings,
  });

  @override
  State<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends State<CitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<WorldClockCity> _filteredCities = [];
  bool _isFetchingCity = false;

  @override
  void initState() {
    super.initState();
    _filteredCities = _getAvailable();
  }

  List<WorldClockCity> _getAvailable() {
    return availableCities
        .where((c) => !widget.alreadyAdded.any(
            (added) => added.name == c.name && added.timezone == c.timezone))
        .toList();
  }

  void _filter(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredCities = _getAvailable();
      } else {
        _filteredCities = _getAvailable()
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.country.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _selectCity(WorldClockCity city) async {
    setState(() => _isFetchingCity = true);

    // Always return a COPY so we don't mutate the global availableCities list
    final cityCopy = city.copy();

    try {
      final response = await TimeNowService.fetchTimezone(city.timezone);
      if (response != null) {
        cityCopy.updateFromApi(response);
      }
    } catch (_) {
      // Falls back to default offset — still works
    }

    if (mounted) {
      Navigator.pop(context, cityCopy);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios, color: Color(0xFFA29BFE), size: 20),
          ),
        ),
        title: const Text('Choose a City',
            style: TextStyle(color: Colors.white, fontSize: 17,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: const Color(0xFF6C5CE7),
                    decoration: InputDecoration(
                      hintText: 'Search cities...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.white.withValues(alpha: 0.3), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _filteredCities.isEmpty
                    ? Center(
                        child: Text('No cities found',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 16)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredCities.length,
                        separatorBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Divider(color: Color(0xFF1E1E2E), height: 1),
                        ),
                        itemBuilder: (context, index) {
                          final city = _filteredCities[index];
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _isFetchingCity
                                ? null
                                : () => _selectCity(city),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(city.name,
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 16)),
                                        const SizedBox(height: 2),
                                        Text(city.country,
                                            style: const TextStyle(
                                                color: Color(0xFF6A6A7A),
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Text(city.formattedTime(widget.settings),
                                      style: const TextStyle(
                                          color: Color(0xFF6A6A7A), fontSize: 14)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_isFetchingCity)
            Container(
              color: const Color(0xFF0A0A0F).withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 28, height: 28,
                        child: CircularProgressIndicator(
                            color: Color(0xFF6C5CE7), strokeWidth: 2)),
                    SizedBox(height: 12),
                    Text('Fetching time...',
                        style: TextStyle(color: Color(0xFF8A85A0), fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}