/// One attribution line in the About screen.
class Credit {
  /// What's being credited — a sound's name, a font, a palette.
  final String title;

  /// Who made it.
  final String author;

  /// License short name, e.g. 'CC BY 4.0' or 'MIT'. Optional.
  final String? license;

  /// Where the original lives. Makes the row tappable. Optional.
  final String? url;

  const Credit({
    required this.title,
    required this.author,
    this.license,
    this.url,
  });
}

/// Audio attributions. Add one entry per sound whose license asks for credit —
/// most Creative Commons "BY" licenses do.
///
/// The Sounds section in About stays hidden while this list is empty, and
/// appears on its own as soon as you add the first entry.
const List<Credit> soundCredits = [
  // Credit(
  //   title: 'Morning Birds',
  //   author: 'Jane Doe',
  //   license: 'CC BY 4.0',
  //   url: 'https://freesound.org/s/12345/',
  // ),
];

/// Design attributions.
const List<Credit> designCredits = [
  Credit(
    title: 'Catppuccin',
    author: 'Color themes by the Catppuccin community',
    license: 'MIT',
    url: 'https://catppuccin.com',
  ),
];