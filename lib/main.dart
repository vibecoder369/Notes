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

typedef ChatRows = List>;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
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
        setState(() => error = 'Could not connect. Check your internet and Supabase setup.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _createRoom() async {
    await _run(() async {
      await _ensureSignedIn();
      final result = await db.rpc('create_room');
      final data = Map<String, dynamic>.from(result as Map);
      await _saveRoom(data['room_id'].toString());
      if (mounted) {
        setState(() => inviteCode = data['invite_code'].toString());
      }
    });
  }

  Future<void> _joinRoom() async {
    final code = invite.text.trim().toLowerCase();
    if (code.isEmpty) {
      setState(() => error = 'Please enter an invite code.');
      return;
    }

    await _run(() async {
      await _ensureSignedIn();
      final result = await db.rpc('join_room', params: {'p_code': code});
      final data = Map<String, dynamic>.from(result as Map);
      invite.clear();
      await _saveRoom(data['room_id'].toString());
    });
  }

  Future<void> _leaveRoom() async {
    final currentRoom = roomId;
    if (currentRoom == null) return;

    await _run(() async {
      await _ensureSignedIn();
      if (myUserId != null) {
        await db
            .from('room_members')
            .delete()
            .eq('room_id', currentRoom)
            .eq('user_id', myUserId!);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('room_id');
      _lastMessageCount = 0;
      if (mounted) {
        setState(() {
          roomId = null;
          inviteCode = null;
        });
      }
    });
  }

  Future<void> _saveRoom(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('room_id', id);
    if (mounted) {
      setState(() {
        roomId = id;
        error = null;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      final raw = e.toString();
      String msg = 'Could not complete that action. Check the invite code and backend setup.';
      if (raw.contains('Invalid or already used invite code') || raw.contains('Invalid invite code')) {
        msg = 'Invalid or already used invite code.';
      } else if (raw.contains('Room is already full')) {
        msg = 'This private room already has 2 members.';
      }
      if (mounted) setState(() => error = msg);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _send() async {
    final text = message.text.trim();
    if (text.isEmpty || roomId == null) return;

    try {
      await _ensureSignedIn();
      final uid = myUserId;
      if (uid == null) throw Exception('Missing user id');

      message.clear();
      await db.from('messages').insert({
        'room_id': roomId,
        'author_id': uid,
        'body': text,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message not sent. Try again.')),
        );
      }
    }
  }

  void _scrollToBottomIfNeeded(int count) {
    if (count != _lastMessageCount) {
      _lastMessageCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Private chat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            Text(
              roomId == null ? 'Not connected' : 'Connected',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (roomId != null)
            IconButton(
              tooltip: 'Leave room',
              onPressed: busy ? null : _leaveRoom,
              icon: const Icon(Icons.logout_rounded, color: muted),
            ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: muted),
          ),
        ],
      ),
      body: !widget.backendConfigured
          ? _setupRequired()
          : roomId == null
              ? _pairingView()
              : _chatView(),
    );
  }

  Widget _setupRequired() => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Messaging setup is not finished yet. Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define when building the APK.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.5),
          ),
        ),
      );

  Widget _pairingView() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text('Connect your two phones', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'One person creates a private room and shares its invite code with the other person.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : _createRoom,
              icon: const Icon(Icons.add_link),
              label: const Text('Create private chat'),
            ),
            if (inviteCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    const Text('Share this one-time pairing code', style: TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    SelectableText(
                      inviteCode!,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy code'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'OR JOIN WITH A CODE',
              style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: invite,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'Enter invite code'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: busy ? null : _joinRoom,
              child: const Text('Join private chat'),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 24),
            const Text(
              'Pairing is required once on each phone. Keep the invite code private.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _chatView() {
    final stream = db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId!)
        .order('created_at', ascending: true);

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<ChatRows>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Unable to load messages', style: TextStyle(color: muted)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) {
                return const Center(child: Text('Say hello 👋', style: TextStyle(color: muted)));
              }

              _scrollToBottomIfNeeded(rows.length);

              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  final mine = row['author_id'] == (myUserId ?? db.auth.currentUser?.id);
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                      decoration: BoxDecoration(
                        color: mine ? const Color(0xFF28313A) : panel2,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(
                        row['body']?.toString() ?? '',
                        style: const TextStyle(color: ink, fontSize: 15, height: 1.35),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: message,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
