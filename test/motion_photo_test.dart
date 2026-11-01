import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souq_akimi/core/l10n.dart';
import 'package:souq_akimi/core/motion.dart';
import 'package:souq_akimi/core/theme.dart';
import 'package:souq_akimi/models/product.dart';
import 'package:souq_akimi/providers/images.dart';
import 'package:souq_akimi/providers/sellers.dart';
import 'package:souq_akimi/widgets/listing_gallery.dart';
import 'package:souq_akimi/widgets/photo_strip.dart';
import 'package:souq_akimi/widgets/photo_viewer.dart';
import 'package:souq_akimi/widgets/product_card.dart';

final _bytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
final _images = List.generate(6, (i) => 'img:photo-$i');

Widget _host(Widget child, {bool arabic = false, bool reduced = false}) {
  AppLocale.current = arabic ? AppLanguage.arabic : AppLanguage.english;
  return ProviderScope(
    overrides: [
      for (final image in _images)
        listingImageBytesProvider(image).overrideWith((ref) async => _bytes),
      visibleSellerSalesProvider.overrideWithValue({}),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: Locale(arabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

double _scale(WidgetTester tester, Finder root) => tester
    .widget<Transform>(
      find.descendant(of: root, matching: find.byType(Transform)).first,
    )
    .transform
    .entry(0, 0);

void main() {
  tearDown(() => AppLocale.current = AppLanguage.english);

  testWidgets(
    'press squishes, rebounds slightly and settles without relayout',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Center(
            child: PressableScale(
              child: SizedBox(
                width: 100,
                height: 60,
                child: FilledButton(onPressed: () {}, child: const Text('Tap')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final feedback = find.byType(PressableScale);
      final bounds = tester.getRect(feedback);
      final gesture = await tester.startGesture(bounds.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_scale(tester, feedback), lessThan(1));
      expect(tester.getRect(feedback), bounds);
      await gesture.up();
      var maximum = 0.0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        final scale = _scale(tester, feedback);
        if (scale > maximum) maximum = scale;
      }
      expect(maximum, greaterThan(1));
      expect(maximum, lessThan(1.04));
      await tester.pumpAndSettle();
      expect(_scale(tester, feedback), closeTo(1, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scrolling cancels the squish while the finger is still down', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Center(
          child: PressableScale(child: SizedBox(width: 150, height: 150)),
        ),
      ),
    );
    final root = find.byType(PressableScale);
    final gesture = await tester.startGesture(tester.getCenter(root));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(_scale(tester, root), closeTo(1, 0.001));
    await gesture.up();
  });

  testWidgets('Material button invokes its callback exactly once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Center(
          child: FilledButton(
            onPressed: () => taps++,
            child: const Text('Tap'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FilledButton)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scale(tester, find.byType(SpringScale)), lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('disabled buttons have neither bounce nor actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Center(
          child: FilledButton(onPressed: null, child: Text('Disabled')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(_scale(tester, find.byType(SpringScale)), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion skips spring presses and delayed entrances', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Center(
          child: FadeSlideIn(
            index: 8,
            child: PressableScale(child: SizedBox(width: 100, height: 100)),
          ),
        ),
        reduced: true,
      ),
    );
    final root = find.byType(PressableScale);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    final gesture = await tester.startGesture(tester.getCenter(root));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scale(tester, root), 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  for (final rtl in [false, true]) {
    testWidgets('page entry follows reading direction, RTL=$rtl', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) =>
                const FluidPageTransitionsBuilder().buildTransitions<void>(
                  MaterialPageRoute(builder: (_) => const SizedBox()),
                  context,
                  const AlwaysStoppedAnimation(0.15),
                  const AlwaysStoppedAnimation(0),
                  const Text('Destination'),
                ),
          ),
          arabic: rtl,
        ),
      );
      final slide = tester.widget<SlideTransition>(
        find.byType(SlideTransition).last,
      );
      expect(slide.position.value.dx, rtl ? lessThan(0) : greaterThan(0));
    });
  }

  testWidgets('reduced-motion page entry does not transform the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) =>
              const FluidPageTransitionsBuilder().buildTransitions<void>(
                MaterialPageRoute(builder: (_) => const SizedBox()),
                context,
                const AlwaysStoppedAnimation(0.15),
                const AlwaysStoppedAnimation(0),
                const Text('Destination'),
              ),
        ),
        reduced: true,
      ),
    );
    expect(find.byType(SlideTransition), findsNothing);
    expect(find.text('Destination'), findsOneWidget);
  });

  testWidgets('gallery opens full screen, zooms, pages and restores its page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ListView(
          children: [
            ListingGallery(images: _images, label: 'Photos', seed: 'test'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.open_in_full_rounded),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(find.text('1 / 6'), findsOneWidget);
    expect(tester.getRect(find.byType(PhotoViewer)).size, const Size(800, 600));
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    var viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer).first,
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(3, 0.01),
    );
    final beforePan = viewer.transformationController!.value.entry(0, 3);
    await tester.drag(
      find.byType(InteractiveViewer).first,
      const Offset(70, 0),
    );
    await tester.pumpAndSettle();
    expect(
      viewer.transformationController!.value.entry(0, 3),
      isNot(closeTo(beforePan, 0.01)),
    );
    expect(find.text('1 / 6'), findsOneWidget);
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await tester.tap(find.byTooltip('Reset zoom'));
    await tester.pumpAndSettle();
    viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer).first,
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(1, 0.01),
    );
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 6'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap toggles enlargement and keyboard escape closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Center(
          child: PhotoPreview(
            images: [_images.first],
            label: 'Photo',
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PhotoPreview));
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Reset zoom'), findsOneWidget);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets('two-finger pinch enlarges the photo rather than paging', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(PhotoViewer(images: _images, label: 'Pinch')),
    );
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byType(InteractiveViewer).first);
    final first = await tester.startGesture(
      center - const Offset(45, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(45, 0),
      pointer: 2,
    );
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      await first.moveTo(center - Offset(45 + i * 15, 0));
      await second.moveTo(center + Offset(45 + i * 15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    final image = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer).first,
    );
    expect(
      image.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1.2),
    );
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.byTooltip('Reset zoom'), findsOneWidget);
  });

  testWidgets('photo card opens viewer but its title still opens the listing', (
    tester,
  ) async {
    var listingTaps = 0;
    final product = Product.fromMap('p', {
      'name': 'Headphones',
      'price': 100,
      'stock': 1,
      'images': [_images.first],
    });
    await tester.pumpWidget(
      _host(
        Center(
          child: SizedBox(
            width: 220,
            height: 390,
            child: ProductCard(product: product, onTap: () => listingTaps++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PhotoPreview));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(listingTaps, 0);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Headphones'));
    await tester.pumpAndSettle();
    expect(listingTaps, 1);
  });

  testWidgets('remove-photo action stays separate from image preview', (
    tester,
  ) async {
    var removed = -1;
    await tester.pumpWidget(
      _host(
        PhotoStrip(
          images: [_images.first],
          busy: false,
          onAdd: () {},
          onRemove: (index) => removed = index,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();
    expect(removed, 0);
    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets('empty gallery has no zoom action or fake photo viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ListingGallery(images: [], label: 'Missing', seed: 'empty')),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('View full-screen'), findsNothing);
    await tester.tap(find.byType(ListingGallery));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });

  for (final arabic in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets(
        'six-photo viewer fits a phone, Arabic=$arabic, reduced=$reduced',
        (tester) async {
          tester.view.physicalSize = const Size(360, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _host(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => showPhotoViewer(
                    context,
                    images: _images,
                    label: 'A long listing title for a student photo gallery',
                    initialIndex: 4,
                  ),
                  child: const Text('Open'),
                ),
              ),
              arabic: arabic,
              reduced: reduced,
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text('5 / 6'), findsOneWidget);
          await tester.tap(find.byTooltip(translate('Next photo')));
          await tester.pumpAndSettle();
          expect(find.text('6 / 6'), findsOneWidget);
          final next = tester.widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_forward_rounded),
          );
          expect(next.onPressed, isNull);
          await tester.tap(find.byTooltip(translate('Previous photo')));
          await tester.pumpAndSettle();
          expect(find.text('5 / 6'), findsOneWidget);
          await tester.tap(find.byTooltip(translate('Zoom in')));
          await tester.pumpAndSettle();
          expect(find.byTooltip(translate('Reset zoom')), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(PhotoViewer), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
