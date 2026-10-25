import 'package:flutter/material.dart';

void main() {
  runApp(const FaykoApp());
}

class FaykoApp extends StatelessWidget {
  const FaykoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF000000);
    const panel = Color(0xFF151515);
    const accent = Color(0xFFE85D75);

    return MaterialApp(
      title: 'فايكو | Fayko',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
        scaffoldBackgroundColor: const Color(0xFFF7F7F8),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: panel,
        ),
        scaffoldBackgroundColor: ink,
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: panel,
          indicatorColor: Color(0x33E85D75),
        ),
      ),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: FaykoHomePage(),
      ),
    );
  }
}

class FaykoHomePage extends StatefulWidget {
  const FaykoHomePage({super.key});

  @override
  State<FaykoHomePage> createState() => _FaykoHomePageState();
}

class _FaykoHomePageState extends State<FaykoHomePage> {
  int _selectedIndex = 0;

  static const _sections = [
    _HomeFeed(),
    _ComingSoon(icon: Icons.video_library_outlined, title: 'فايكو ريلز',
        description: 'مقاطع قصيرة — قريباً'),
    _ComingSoon(icon: Icons.chat_bubble_outline, title: 'المحادثات',
        description: 'رسائلك ومكالماتك — قريباً'),
    _ComingSoon(icon: Icons.person_outline, title: 'الملف الشخصي',
        description: 'ملفك وإعداداتك — قريباً'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فايكو', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'البحث',
            onPressed: () => _showNotice('البحث سيُضاف في مرحلة لاحقة'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () => _showNotice('الإشعارات ستُضاف لاحقاً'),
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _sections),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showNotice('إنشاء المنشورات سيُفعّل ضمن مرحلة الخلاصة'),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: 'ريلز'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'الدردشة'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HomeFeed extends StatelessWidget {
  const _HomeFeed();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('أهلاً بك في فايكو 👋', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('مساحة تواصل عربية، نبنيها خطوة بخطوة.'),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('النسخة الأولية — واجهة تجريبية بدون خادم أو حسابات بعد')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('الخلاصة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const _EmptyFeedCard(),
      ],
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.dynamic_feed_outlined, size: 42),
          SizedBox(height: 12),
          Text('ماكو منشورات لحد الآن', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('لما نضيف نظام الحسابات والمنشورات راح تظهر هنا.',
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
