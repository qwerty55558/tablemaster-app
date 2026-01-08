# shadcn_flutter API Guide

## App Setup

```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'My App',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorSchemes.darkZinc(),  // or LegacyColorSchemes.darkZinc()
        radius: 0.5,  // 0.5 ~ 0.7 recommended
      ),
      home: const HomePage(),
    );
  }
}
```

## Scaffold & AppBar

```dart
Scaffold(
  headers: [
    AppBar(
      title: const Text('Title'),
      subtitle: const Text('Subtitle'),  // optional
      leading: [
        GhostButton(
          onPressed: () {},
          density: ButtonDensity.icon,
          child: const Icon(Icons.menu),
        ),
      ],
      trailing: [
        GhostButton(
          density: ButtonDensity.icon,
          onPressed: () {},
          child: const Icon(Icons.search),
        ),
      ],
    ),
    const Divider(),
  ],
  footers: [
    const Divider(),
    NavigationBar(...),
  ],
  child: YourContent(),  // NOT body:
)
```

## Buttons

```dart
// Primary Button
PrimaryButton(
  onPressed: () {},
  child: const Text('Click me'),
)

// Primary Button - Icon only
PrimaryButton(
  onPressed: () {},
  density: ButtonDensity.icon,
  child: const Icon(Icons.add),
)

// Ghost Button (like IconButton)
GhostButton(
  onPressed: () {},
  density: ButtonDensity.icon,
  child: const Icon(Icons.menu),
)

// Outline Button
OutlineButton(
  onPressed: () {},
  child: const Text('Cancel'),
)

// Button Sizes
PrimaryButton(
  onPressed: () {},
  size: ButtonSize.large,  // or ButtonSize.small, ButtonSize.normal
  child: const Text('Large Button'),
)
```

## TextField

```dart
// With placeholder widget
TextField(
  controller: _controller,
  placeholder: const Text('Enter text here'),  // Widget
  onSubmitted: (value) {},
)

// With hintText string
TextField(
  controller: _controller,
  hintText: 'Enter text here',  // String
)

// Password field
TextField(
  controller: _controller,
  obscureText: true,
  placeholder: const Text('Password'),
)
```

## Card

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [...],
    ),
  ),
)

// Surface Card (for Toast, etc.)
SurfaceCard(
  child: Basic(
    title: const Text('Title'),
    subtitle: const Text('Subtitle'),
    leading: const Icon(Icons.check),
  ),
)
```

## Badge

```dart
Badge(
  backgroundColor: const Color(0xFF22C55E).withOpacity(0.15),
  child: Text(
    'Active',
    style: TextStyle(color: const Color(0xFF22C55E)),
  ),
)
```

## Dialog

```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Dialog Title'),
    content: const Text('Dialog content here'),
    actions: [
      OutlineButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      PrimaryButton(
        onPressed: () {
          Navigator.pop(context);
          // do something
        },
        child: const Text('Confirm'),
      ),
    ],
  ),
);
```

## Toast

```dart
showToast(
  context: context,
  builder: (context, overlay) => SurfaceCard(
    child: Basic(
      title: const Text('Success'),
      subtitle: const Text('Operation completed'),
      leading: const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
    ),
  ),
);
```

## Drawer & Sheet

```dart
// Drawer (from left)
openDrawer(
  context: context,
  builder: (context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: const Text('Drawer content'),
    );
  },
  position: OverlayPosition.left,
);

// Sheet (from right)
openSheet(
  context: context,
  builder: (context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: const Text('Sheet content'),
    );
  },
  position: OverlayPosition.right,
);
```

## Typography Extensions

```dart
// Use extension methods on Text widgets
const Text('Heading 1').h1()
const Text('Heading 2').h2()
const Text('Paragraph').p()
const Text('Small text').small()
const Text('Muted text').muted()
```

## Progress Indicators

```dart
// Circular
CircularProgressIndicator(
  strokeWidth: 2,
)

// Linear (Progress Bar)
Progress(value: 0.5)
```

## Colors from Theme

```dart
final theme = Theme.of(context);

// Common colors
theme.colorScheme.primary
theme.colorScheme.foreground
theme.colorScheme.background
theme.colorScheme.muted
theme.colorScheme.mutedForeground
theme.colorScheme.border
theme.colorScheme.input

// Scaling
theme.scaling  // for responsive sizing
theme.radiusMd  // border radius
```

## Icon Themes

```dart
// Small icons
theme.iconTheme.small

// With color
theme.iconTheme.small.copyWith(
  color: theme.colorScheme.mutedForeground,
)
```

## Common Patterns

### Page with AppBar
```dart
Scaffold(
  headers: [
    AppBar(
      title: const Text('Page Title'),
      leading: [
        GhostButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          density: ButtonDensity.icon,
        ),
      ],
    ),
  ],
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...],
    ),
  ),
)
```

### Form Card
```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Label').small(),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          placeholder: const Text('Placeholder'),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    ),
  ),
)
```

## Notes

- Use `child:` not `body:` for Scaffold content
- `leading:` and `trailing:` in AppBar are Lists, not single widgets
- TextField `placeholder:` accepts Widget, `hintText:` accepts String
- Use `GhostButton` with `density: ButtonDensity.icon` instead of IconButton
- Typography extensions: `.h1()`, `.p()`, `.small()`, `.muted()` etc.
