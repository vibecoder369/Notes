import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const bg = Color(0xFF050505);
const panel = Color(0xFF111111);
const panel2 = Color(0xFF191919);
const ink = Color(0xFFF2F2F2);
const muted = Color(0xFF8A8A8A);
const accent = Color(0xFFC9D1D9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  }
  runApp(NotepadApp(backendConfigured: configured));
}

class NotepadApp extends StatelessWidget {
  const NotepadApp({super.key, required this.backendConfigured});
  final bool backendConfigured;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Notepad',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: panel,
          onSurface: ink,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel2,
          hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: NotesHome(backendConfigured: backendConfigured),
    );
  }
}

class NotesHome extends StatefulWidget {
  const NotesHome({super.key, required this.backendConfigured});
  final bool backendConfigured;

  @override
  State<NotesHome> createState() => _NotesHomeState();
}

class _NotesHomeState extends State<NotesHome> {
  final TextEditingController search = TextEditingController();
  String secret = 'bluebird';

  @override
  void initState() {
    super.initState();
    _loadSecret();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _loadSecret() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('secret_word');
    if (mounted && saved != null && saved.trim().isNotEmpty) {
      setState(() => secret = saved.trim().toLowerCase());
    }
  }

  Future<void> _saveSecret(String value) async {
    final clean = value.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('secret_word', clean);
    if (mounted) setState(() => secret = clean);
  }

  void _checkSecret(String value) {
    if (secret.isNotEmpty && value.trim().toLowerCase() == secret) {
      search.clear();
      FocusScope.of(context).unfocus();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(backendConfigured: widget.backendConfigured),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text(
          'Notepad',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600, letterSpacing: -.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _changeSecret,
            icon: const Icon(Icons.more_vert_rounded, color: muted),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: search,
              onChanged: _checkSecret,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'Search notes',
                prefixIcon: Icon(Icons.search_rounded, color: muted),
                contentPadding: EdgeInsets.symmetric(vertical: 17),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'RECENT NOTES',
              style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
            ),
            const SizedBox(height: 13),
            const NoteTile(
              icon: Icons.checklist_rounded,
              title: 'Things to remember',
              preview: 'Small tasks for this week',
              time: 'Today',
            ),
            const NoteTile(
              icon: Icons.school_outlined,
              title: 'College',
              preview: 'Assignments and upcoming work',
              time: 'Yesterday',
            ),
            const NoteTile(
              icon: Icons.edit_note_rounded,
              title: 'Quick notes',
              preview: 'Ideas worth coming back to',
              time: 'Mon',
            ),
            const Spacer(),
            Center(
              child: Text(
                'All notes are up to date',
                style: TextStyle(color: muted.withValues(alpha: 0.7), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeSecret() async {
    final controller = TextEditingController(text: secret);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Search shortcut'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Secret word (min 4 chars)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result.trim().length >= 4) {
      await _saveSecret(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search shortcut updated')),
        );
      }
    } else if (result != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secret word must be at least 4 characters')),
        );
      }
    }
  }
}

class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.icon,
    required this.title,
    required this.preview,
    required this.time,
  });

  final IconData icon;
  final String title, preview, time;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17)),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: panel2, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(preview, style: const TextStyle(fontSize: 12, color: muted)),
                ],
              ),
            ),
            Text(time, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.backendConfigured});
  final bool backendConfigured;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController message = TextEditingController();
  final TextEditingController invite = TextEditingController();
  final ScrollController scrollController = ScrollController();

  String? roomId;
  String? inviteCode;
  String? error;
  String? myUserId;
  bool busy = false;
  int _lastMessageCount = 0;

  SupabaseClient get db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (widget.backendConfigured) _restoreSession();
  }

  @override
  void dispose() {
    message.dispose();
    invite.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureSignedIn() async {
    if (db.auth.currentUser == null) {
      await db.auth.signInAnonymously();
    }
    myUserId = db.auth.currentUser?.id;
  }

  Future<void> _restoreSession() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await _ensureSignedIn();
      final prefs = await SharedPreferences.getInstance();
      final savedRoom = prefs.getString('room_id');
      if (savedRoom != null && savedRoom.isNotEmpty && mounted) {
        setState(() => roomId = savedRoom);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '
