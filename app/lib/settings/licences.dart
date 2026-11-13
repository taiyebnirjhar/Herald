import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Licence texts shipped in the app (WBS 5.6): Herald's own licence, and the
/// proot and libtalloc licences the runtime needs (CLAUDE.md, hard rules).
/// Copies of the files in the repo's LICENSE and runtime/proot/licenses/.
const heraldLicenceFiles = <(String package, String asset)>[
  ('Herald', 'assets/licenses/herald-LICENSE.txt'),
  ('proot (GPL-2.0-or-later)', 'assets/licenses/GPL-2.0.txt'),
  ('proot (GPL-3.0)', 'assets/licenses/GPL-3.0.txt'),
  ('libtalloc (LGPL-3.0)', 'assets/licenses/LGPL-3.0.txt'),
];

bool _registered = false;

/// Adds the licence texts to Flutter's LicenseRegistry, once. The texts are
/// read only when the licences page opens.
void registerHeraldLicences({AssetBundle? bundle}) {
  if (_registered) return;
  _registered = true;
  final source = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    for (final (package, asset) in heraldLicenceFiles) {
      final text = await source.loadString(asset);
      yield LicenseEntryWithLineBreaks([package], text);
    }
  });
}
