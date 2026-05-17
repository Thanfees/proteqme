# Overwatch ↔ Home screen integration

Drop the `OverwatchCard()` widget between the SOS button block and the bottom
Contacts/Features row in `lib/features/listener/presentation/home_screen.dart`.

Wrap it in `Padding(padding: EdgeInsets.only(top: 14))`:

```dart
import 'package:proteqme/features/overwatch/presentation/overwatch_card.dart';

// …inside the home column, between the SOS button and Contacts/Features row:
const Padding(
  padding: EdgeInsets.only(top: 14),
  child: OverwatchCard(),
),
```

The card is fully self-contained — it owns its own Riverpod state, talks to the
`com.proteqme/overwatch` MethodChannel directly, and renders idle / active /
expiringSoon / completed inside a single `BrandCard`. No additional providers,
imports, or wiring are required in `home_screen.dart`.
