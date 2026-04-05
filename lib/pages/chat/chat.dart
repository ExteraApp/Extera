import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat_view.dart';
import 'package:extera_next/pages/chat/event_info_dialog.dart';
import 'package:extera_next/pages/chat/message_context_menu.dart';
import 'package:extera_next/pages/chat/message_edits_dialog.dart';
import 'package:extera_next/pages/chat/recovered_event_dialog.dart';
import 'package:extera_next/pages/chat/seen_by_row.dart';
import 'package:extera_next/pages/chat/send_poll_dialog.dart';
import 'package:extera_next/pages/chat/translated_event_dialog.dart';
import 'package:extera_next/pages/chat/vote_results_dialog.dart';
import 'package:extera_next/pages/chat_details/chat_details.dart';
import 'package:extera_next/utils/adaptive_bottom_sheet.dart';
import 'package:extera_next/utils/clipboard_utils.dart';
import 'package:extera_next/utils/error_reporter.dart';
import 'package:extera_next/utils/file_selector.dart';
import 'package:extera_next/utils/loading_snackbar_extension.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/filtered_timeline_extension.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/synapse_admin_extension.dart';
import 'package:extera_next/utils/other_party_can_receive.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/privacy_options.dart';
import 'package:extera_next/utils/room_status_extension.dart';
import 'package:extera_next/utils/show_scaffold_dialog.dart';
import 'package:extera_next/utils/translator.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:extera_next/widgets/emoji_picker.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import 'package:extera_next/widgets/future_loading_snackbar.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/share_scaffold_dialog.dart';
import '../../utils/account_bundles.dart';
import '../../utils/localized_exception_extension.dart';
import '../../utils/resize_video.dart';
import 'send_file_dialog.dart';
import 'send_location_dialog.dart';

class ChatPage extends StatelessWidget {
  final String roomId;
  final List<ShareItem>? shareItems;
  final String? eventId;
  final bool? showThreadRoots;

  const ChatPage({
    super.key,
    required this.roomId,
    this.eventId,
    this.shareItems,
    this.showThreadRoots,
  });

  @override
  Widget build(BuildContext context) {
    final room = Matrix.of(context).client.getRoomById(roomId);
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(L10n.of(context).oopsSomethingWentWrong)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(L10n.of(context).youAreNoLongerParticipatingInThisChat),
          ),
        ),
      );
    }

    return ChatPageWithRoom(
      key: Key('chat_page_${roomId}_$eventId'),
      room: room,
      shareItems: shareItems,
      eventId: eventId,
      showThreadRoots: showThreadRoots,
    );
  }
}

class ChatPageWithRoom extends StatefulWidget {
  final Room room;
  final Thread? thread;
  final List<ShareItem>? shareItems;
  final String? eventId;
  final bool? showThreadRoots;

  const ChatPageWithRoom({
    super.key,
    required this.room,
    this.thread,
    this.shareItems,
    this.eventId,
    this.showThreadRoots,
  });

  @override
  ChatController createState() => ChatController();
}

class ChatController extends State<ChatPageWithRoom>
    with WidgetsBindingObserver {
  Room get room => sendingClient.getRoomById(roomId) ?? widget.room;
  bool get showThreadRoots => (widget.showThreadRoots ?? false);
  Thread? get thread =>
      sendingClient.getRoomById(roomId)?.threads[threadRootEventId] ??
      widget.room.threads[threadRootEventId];

  late Client sendingClient;

  Timeline? timeline;

  late final String readMarkerEventId;

  String get roomId => widget.room.id;
  String? get threadRootEventId => widget.thread?.rootEvent.eventId;

  final AutoScrollController scrollController = AutoScrollController();

  late final FocusNode inputFocus;

  Timer? typingCoolDown;
  Timer? typingTimeout;
  bool currentlyTyping = false;
  bool dragging = false;

  void onDragEntered(_) => setState(() => dragging = true);

  void onDragExited(_) => setState(() => dragging = false);

  void onDragDone(DropDoneDetails details) async {
    setState(() => dragging = false);
    if (details.files.isEmpty) return;

    await showAdaptiveDialog(
      context: context,
      useRootNavigator: false,
      builder: (c) => SendFileDialog(
        files: details.files,
        room: room,
        thread: thread,
        replyEvent: replyEvent,
        outerContext: context,
      ),
    );
  }

  bool get canSaveSelectedEvent =>
      selectedEvents.length == 1 &&
      {
        MessageTypes.Video,
        MessageTypes.Image,
        MessageTypes.Sticker,
        MessageTypes.Audio,
        MessageTypes.File,
      }.contains(selectedEvents.single.messageType);

  void saveSelectedEvent(context) => selectedEvents.single.saveFile(context);

  List<Event> selectedEvents = [];

  final Set<String> unfolded = {};

  Event? replyEvent;
  bool replyMention = true;

  Event? editEvent;

  bool _scrolledUp = false;

  bool get showScrollDownButton =>
      _scrolledUp || timeline?.allowNewEvent == false;

  bool get selectMode => selectedEvents.isNotEmpty;

  final int _loadHistoryCount = 100;

  String pendingText = '';

  bool showEmojiPicker = false;

  void acceptInvite() async {
    final result = await showFutureLoadingDialog(
      context: context,
      future: () async {
        final waitForRoom = room.client.waitForRoomInSync(room.id, join: true);
        await room.join();
        await waitForRoom;
      },
      exceptionContext: ExceptionContext.joinRoom,
    );
    if (result.error != null) return;
  }

  void declineInvite() async {
    await showFutureLoadingDialog(context: context, future: room.leave);
    if (!mounted) return;
    context.go('/rooms');
  }

  void ignoreInvite() async {
    final userId = room
        .getState(EventTypes.RoomMember, room.client.userID!)
        ?.senderId;
    if (!mounted) return;
    context.go('/rooms/settings/security/ignorelist', extra: userId);
  }

  void recreateChat() async {
    final room = this.room;
    final userId = room.directChatMatrixID;
    if (userId == null) {
      throw Exception(
        'Try to recreate a room with is not a DM room. This should not be possible from the UI!',
      );
    }
    await showFutureLoadingDialog(
      context: context,
      future: () => room.invite(userId),
    );
  }

  void leaveChat() async {
    final success = await showFutureLoadingDialog(
      context: context,
      future: room.leave,
    );
    if (success.error != null) return;
    context.go('/rooms');
  }

  EmojiPickerType emojiPickerType = EmojiPickerType.keyboard;

  void requestHistory([_]) async {
    if (scrollController.hasClients &&
        scrollController.position.isScrollingNotifier.value) {
      return;
    }
    Logs().v('Requesting history...');
    await timeline?.requestHistory(historyCount: _loadHistoryCount);
  }

  bool _requestingFuture = false;

  void requestFuture() async {
    final timeline = this.timeline;
    if (timeline == null) return;
    if (_requestingFuture) return;
    _requestingFuture = true;
    Logs().v('Requesting future...');
    final visibleEvents = timeline.events.filterByVisibleInGui();
    final mostRecentEvent = visibleEvents.firstOrNull;

    final anchorEventId = mostRecentEvent?.eventId;

    await timeline.requestFuture(historyCount: _loadHistoryCount);

    if (!mounted) {
      _requestingFuture = false;
      return;
    }

    if (anchorEventId != null && scrollController.hasClients) {
      final newVisibleEvents = timeline.events.filterByVisibleInGui();
      final anchorIndex = newVisibleEvents.indexWhere(
        (e) => e.eventId == anchorEventId,
      );
      if (anchorIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !scrollController.hasClients) return;
          scrollController.scrollToIndex(
            anchorIndex + 1, // index 0 is the typing indicator
            preferPosition: AutoScrollPosition.begin,
            duration: Duration.zero,
          );
        });
      }
    }

    if (mostRecentEvent != null) {
      setReadMarker(eventId: mostRecentEvent.eventId);
    }
    _requestingFuture = false;
  }

  void _updateScrollController() {
    if (!mounted) {
      return;
    }
    if (!scrollController.hasClients) return;
    if (timeline?.allowNewEvent == false ||
        scrollController.position.pixels > 0 && _scrolledUp == false) {
      setState(() => _scrolledUp = true);
    } else if (scrollController.position.pixels <= 0 && _scrolledUp == true) {
      setState(() => _scrolledUp = false);
      setReadMarker();
    }
  }

  void _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('draft_$roomId');
    if (draft != null && draft.isNotEmpty) {
      sendController.text = draft;
    }
  }

  void _shareItems([_]) {
    final shareItems = widget.shareItems;
    if (shareItems == null || shareItems.isEmpty) return;
    if (!room.otherPartyCanReceiveMessages) {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: theme.colorScheme.errorContainer,
          closeIconColor: theme.colorScheme.onErrorContainer,
          content: Text(
            L10n.of(context).otherPartyNotLoggedIn,
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
          showCloseIcon: true,
        ),
      );
      return;
    }
    for (final item in shareItems) {
      if (item is FileShareItem) continue;
      if (item is TextShareItem) room.sendTextEvent(item.value);
      if (item is ContentShareItem) room.sendEvent(item.value);
    }
    final files = shareItems
        .whereType<FileShareItem>()
        .map((item) => item.value)
        .toList();
    if (files.isEmpty) return;
    showAdaptiveDialog(
      context: context,
      builder: (c) => SendFileDialog(
        files: files,
        room: room,
        thread: thread,
        outerContext: context,
        replyEvent: replyEvent,
      ),
    );
  }

  KeyEventResult _shiftEnterKeyHandling(FocusNode node, KeyEvent evt) {
    if (!HardwareKeyboard.instance.isShiftPressed &&
        evt.logicalKey.keyLabel == 'Enter') {
      if (evt is KeyDownEvent) {
        send();
      }
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
  }

  @override
  void initState() {
    inputFocus = FocusNode(
      onKeyEvent: AppSettings.sendOnEnter.value ? _shiftEnterKeyHandling : null,
    );

    scrollController.addListener(_updateScrollController);
    inputFocus.addListener(_inputFocusListener);

    _loadDraft();
    WidgetsBinding.instance.addPostFrameCallback(_shareItems);
    super.initState();
    _displayChatDetailsColumn = ValueNotifier(
      AppSettings.displayChatDetailsColumn.value,
    );

    sendingClient = Matrix.of(context).client;
    readMarkerEventId = room.hasNewMessages ? room.fullyRead : '';
    WidgetsBinding.instance.addObserver(this);
    _tryLoadTimeline();

    _getThreads();
  }

  void _tryLoadTimeline() async {
    final initialEventId = widget.eventId;
    loadTimelineFuture = _getTimeline();
    Logs().v("Trying to load timeline...");
    try {
      await loadTimelineFuture;
      if (initialEventId != null) scrollToEventId(initialEventId);

      var readMarkerEventIndex = readMarkerEventId.isEmpty
          ? -1
          : timeline!.events
                .filterByVisibleInGui(exceptionEventId: readMarkerEventId)
                .indexWhere((e) => e.eventId == readMarkerEventId);

      if (readMarkerEventId.isNotEmpty && readMarkerEventIndex == -1) {
        await timeline?.requestHistory(historyCount: _loadHistoryCount);
        readMarkerEventIndex = timeline!.events
            .filterByVisibleInGui(exceptionEventId: readMarkerEventId)
            .indexWhere((e) => e.eventId == readMarkerEventId);
      }

      if (readMarkerEventIndex > 1) {
        Logs().v('Scroll up to visible event', readMarkerEventId);
        scrollToEventId(readMarkerEventId, highlightEvent: false);
        return;
      } else if (readMarkerEventId.isNotEmpty && readMarkerEventIndex == -1) {
        _showScrollUpMaterialBanner(readMarkerEventId);
      }

      setReadMarker();

      if (!mounted) return;
    } catch (e, s) {
      ErrorReporter(context, 'Unable to load timeline').onErrorCallback(e, s);
      rethrow;
    }
  }

  String? scrollUpBannerEventId;

  void discardScrollUpBannerEventId() => setState(() {
    scrollUpBannerEventId = null;
  });

  void _showScrollUpMaterialBanner(String eventId) => setState(() {
    scrollUpBannerEventId = eventId;
  });

  bool firstUpdateReceived = false;

  Future<void> updateView() async {
    if (!mounted) return;
    setReadMarker();
    updateThreads();
    setState(() {
      firstUpdateReceived = true;
    });
  }

  Future<void> updateThreads() async {
    if (timeline?.events == null) return;
    final lastEvent = timeline?.events[timeline!.events.length - 1];

    if (lastEvent == null) return;
    if (lastEvent.relationshipType == RelationshipTypes.thread &&
        lastEvent.relationshipEventId != null) {
      final thread = await room.client.database.getThread(
        room.id,
        lastEvent.relationshipEventId!,
        room.client,
      );
      if (thread != null) {
        setState(() {
          threads?[lastEvent.eventId] = thread;
        });
      }
    }
  }

  Future<void>? loadTimelineFuture;
  Map<String, Thread>? threads = {};

  Future<void> _loadRoomTimeline({String? eventContextId}) async {
    try {
      timeline?.cancelSubscriptions();
      timeline = await room.getTimeline(
        onUpdate: updateView,
        eventContextId: eventContextId,
      );
    } catch (e, s) {
      Logs().w('Unable to load timeline on event ID $eventContextId', e, s);
      if (!mounted) return;
      timeline = await room.getTimeline(onUpdate: updateView);
      if (!mounted) return;
      if (e is TimeoutException || e is IOException) {
        _showScrollUpMaterialBanner(eventContextId!);
      }
    }
  }

  Future<void> _loadThreadTimeline({String? eventContextId}) async {
    if (thread == null) {
      throw Exception(
        "_loadThreadTimeline should not be called, thread == null",
      );
    }
    try {
      timeline?.cancelSubscriptions();
      timeline = await thread!.getTimeline(
        onUpdate: updateView,
        eventContextId: eventContextId,
      );
      Logs().v("Thread timeline loaded");
    } catch (e, s) {
      Logs().w(
        'Unable to load timeline on event ID $eventContextId (in thread)',
        e,
        s,
      );
      if (!mounted) return;
      timeline = await thread!.getTimeline(onUpdate: updateView);
      if (!mounted) return;
      if (e is TimeoutException || e is IOException) {
        _showScrollUpMaterialBanner(eventContextId!);
      }
    }
    if (timeline is ThreadTimeline) {
      (timeline as ThreadTimeline).getThreadEvents();
    }
  }

  Future<void> _getTimeline({String? eventContextId}) async {
    await Matrix.of(context).client.roomsLoading;
    await Matrix.of(context).client.accountDataLoading;
    if (eventContextId != null &&
        (!eventContextId.isValidMatrixId || eventContextId.sigil != '\$')) {
      eventContextId = null;
    }
    if (thread == null) {
      await _loadRoomTimeline(eventContextId: eventContextId);
    } else {
      await _loadThreadTimeline(eventContextId: eventContextId);
    }
    timeline!.requestKeys(onlineKeyBackupOnly: false);
    if (room.markedUnread) room.markUnread(false);

    return;
  }

  Future<void> _getThreads() async {
    try {
      threads = await room.getThreads();
      Logs().w('Thread amount: ${threads?.length}');
    } catch (e, s) {
      Logs().w('Unable to load threads in $roomId', e, s);
    }
  }

  Future<void> showPollResults(Event event) async {
    await showFutureLoadingSnackbar(
      context: context,
      future: () => showPollResultsDialog(context, event),
    );
  }

  String? scrollToEventIdMarker;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    setReadMarker();
  }

  Future<void>? _setReadMarkerFuture;

  void setReadMarker({String? eventId}) {
    if (_setReadMarkerFuture != null) return;
    if (_scrolledUp) return;
    if (scrollUpBannerEventId != null) return;

    if (eventId == null &&
        !room.hasNewMessages &&
        room.notificationCount == 0) {
      return;
    }

    // Do not send read markers when app is not in foreground
    if (kIsWeb && !Matrix.of(context).webHasFocus) return;
    if (!kIsWeb &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final timeline = this.timeline;
    if (timeline == null || timeline.events.isEmpty) return;

    Logs().d('Set read marker...', eventId);
    // ignore: unawaited_futures
    _setReadMarkerFuture = timeline
        .setReadMarker(
          eventId: eventId,
          public: shouldSendPublicReadReceipts(room.client, roomId),
        )
        .then((_) {
          _setReadMarkerFuture = null;
        });

    if (timeline is RoomTimeline) {
      if (eventId == null || eventId == timeline.room.lastEvent?.eventId) {
        Matrix.of(
          context,
        ).backgroundPush?.cancelNotification(room.client, roomId);
      }
    }
    // TODO same for Threads
  }

  @override
  void dispose() {
    timeline?.cancelSubscriptions();
    timeline = null;
    inputFocus.removeListener(_inputFocusListener);
    if (currentlyTyping) room.setTyping(false);
    super.dispose();
  }

  TextEditingController sendController = TextEditingController();

  void setSendingClient(Client c) {
    // first cancel typing with the old sending client
    if (currentlyTyping) {
      // no need to have the setting typing to false be blocking
      typingCoolDown?.cancel();
      typingCoolDown = null;
      room.setTyping(false);
      currentlyTyping = false;
    }
    // then cancel the old timeline
    // fixes bug with read reciepts and quick switching
    loadTimelineFuture = _getTimeline(eventContextId: room.fullyRead).onError(
      ErrorReporter(
        context,
        'Unable to load timeline after changing sending Client',
      ).onErrorCallback,
    );

    // then set the new sending client
    setState(() => sendingClient = c);
  }

  void setActiveClient(Client c) => setState(() {
    Matrix.of(context).setActiveClient(c);
  });

  Future<void> send() async {
    if (sendController.text.trim().isEmpty) return;
    if (inputFocus.hasFocus) {
      inputFocus.unfocus();
    }
    FocusScope.of(context).requestFocus(inputFocus);
    _storeInputTimeoutTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('draft_$roomId');
    var parseCommands = true;

    final commandMatch = RegExp(r'^\/(\w+)').firstMatch(sendController.text);
    if (commandMatch != null &&
        !sendingClient.commands.keys.contains(commandMatch[1]!.toLowerCase())) {
      final l10n = L10n.of(context);
      final dialogResult = await showOkCancelAlertDialog(
        context: context,
        title: l10n.commandInvalid,
        message: l10n.commandMissing(commandMatch[0]!),
        okLabel: l10n.sendAsText,
        cancelLabel: l10n.cancel,
      );
      if (dialogResult == OkCancelResult.cancel) return;
      parseCommands = false;
    }

    // ignore: unawaited_futures
    room.sendTextEvent(
      sendController.text,
      inReplyTo: replyEvent,
      replyMention: replyMention,
      editEventId: editEvent?.eventId,
      parseCommands: parseCommands,
      threadRootEventId: thread?.rootEvent.eventId,
      threadLastEventId:
          thread?.lastEvent?.eventId ?? thread?.rootEvent.eventId,
    );
    sendController.value = TextEditingValue(
      text: pendingText,
      selection: const TextSelection.collapsed(offset: 0),
    );

    setState(() {
      sendController.text = pendingText;
      _inputTextIsEmpty = pendingText.isEmpty;
      replyEvent = null;
      editEvent = null;
      pendingText = '';
    });
  }

  void sendPollAction() async {
    await showAdaptiveDialog(
      context: context,
      useRootNavigator: false,
      builder: (c) =>
          SendPollDialog(room: room, thread: thread, outerContext: context),
    );
    replyEvent = null;
  }

  void sendFileAction({FileType type = .any}) async {
    final files = await selectFiles(context, allowMultiple: true, type: type);
    if (files.isEmpty) {
      Logs().v("Returning in sendFileAction, bc files.isEmpty==true");
      return;
    }
    await showAdaptiveDialog(
      context: context,
      useRootNavigator: false,
      builder: (c) => SendFileDialog(
        files: files,
        room: room,
        thread: thread,
        outerContext: context,
        replyEvent: replyEvent,
        onClearReply: () {
          replyEvent = null;
        },
      ),
    );
    // replyEvent = null;
  }

  void sendImageFromClipBoard(Uint8List? image) async {
    if (PlatformInfos.isLinux) {
      final pastedImage = await getImageFromClipboardLinux();
      if (pastedImage == null) return;
      await showAdaptiveDialog(
        context: context,
        builder: (c) => SendFileDialog(
          files: [
            XFile.fromData(
              pastedImage,
              mimeType: 'image/png',
              // name: 'clipboard_image.png',
            ),
          ],
          room: room,
          thread: thread,
          outerContext: context,
          replyEvent: replyEvent,
          onClearReply: () {
            replyEvent = null;
          },
        ),
      );
      return;
    }
    if (image == null) return;
    await showAdaptiveDialog(
      context: context,
      useRootNavigator: false,
      builder: (c) => SendFileDialog(
        files: [XFile.fromData(image)],
        room: room,
        thread: thread,
        outerContext: context,
        replyEvent: replyEvent,
        onClearReply: () {
          replyEvent = null;
        },
      ),
    );
  }

  void openCameraAction() async {
    // Make sure the textfield is unfocused before opening the camera
    FocusScope.of(context).requestFocus(FocusNode());
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file == null) return;

    await showAdaptiveDialog(
      context: context,
      useRootNavigator: false,
      builder: (c) => SendFileDialog(
        files: [file],
        room: room,
        thread: thread,
        outerContext: context,
      ),
    );
  }

  void openVideoCameraAction() async {
    // Make sure the textfield is unfocused before opening the camera
    FocusScope.of(context).requestFocus(FocusNode());
    final file = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 1),
    );
    if (file == null) return;

    await showAdaptiveDialog(
      context: context,
      useRootNavigator: false,
      builder: (c) => SendFileDialog(
        files: [file],
        room: room,
        thread: thread,
        outerContext: context,
      ),
    );
  }

  Future<void> onVoiceMessageSend(
    String path,
    int duration,
    List<int> waveform,
    String fileName,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final audioFile = XFile(path);

    final bytesResult = await showFutureLoadingDialog(
      context: context,
      future: audioFile.readAsBytes,
    );
    final bytes = bytesResult.result;
    if (bytes == null) return;

    final mimeType = lookupMimeType(fileName, headerBytes: bytes);
    final ext = mimeType == null ? null : extensionFromMime(mimeType);
    if (ext != null) {
      fileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.$ext';
    }

    final file = MatrixAudioFile(bytes: bytes, name: fileName);

    await room
        .sendFileEvent(
          file,
          inReplyTo: replyEvent,
          extraContent: {
            'info': {...file.info, 'duration': duration},
            'org.matrix.msc3245.voice': {},
            'org.matrix.msc1767.audio': {
              'duration': duration,
              'waveform': waveform,
            },
          },
          threadLastEventId: thread?.lastEvent?.eventId,
          threadRootEventId: thread?.rootEvent.eventId,
        )
        .catchError((e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text((e as Object).toLocalizedString(context))),
          );
          return null;
        });
    setState(() {
      replyEvent = null;
    });
  }

  Future<void> onVideoNoteSend(
    String path,
    int duration,
    String fileName,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final videoFile = XFile(path);

    final bytesResult = await showFutureLoadingDialog(
      context: context,
      future: videoFile.readAsBytes,
    );
    final bytes = bytesResult.result;
    if (bytes == null) return;

    final mimeType = lookupMimeType(fileName, headerBytes: bytes);
    final ext = mimeType == null ? null : extensionFromMime(mimeType);
    if (ext != null) {
      fileName = 'video_note_${DateTime.now().millisecondsSinceEpoch}.$ext';
    }

    final file = await videoFile.resizeVideo();

    MatrixImageFile? thumbnail;
    try {
      thumbnail = await videoFile.getVideoThumbnail();
    } catch (e, s) {
      Logs().w('Failed to generate video note thumbnail', e, s);
    }

    file.info['duration'] = duration;

    await room
        .sendFileEvent(
          file,
          thumbnail: thumbnail,
          inReplyTo: replyEvent,
          extraContent: {'xyz.extera.video_note': {}},
          threadLastEventId: thread?.lastEvent?.eventId,
          threadRootEventId: thread?.rootEvent.eventId,
        )
        .catchError((e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text((e as Object).toLocalizedString(context))),
          );
          return null;
        });
    setState(() {
      replyEvent = null;
    });
  }

  void hideEmojiPicker() {
    setState(() => showEmojiPicker = false);
  }

  void emojiPickerAction() {
    if (showEmojiPicker) {
      inputFocus.requestFocus();
    } else {
      inputFocus.unfocus();
    }
    emojiPickerType = EmojiPickerType.keyboard;
    setState(() => showEmojiPicker = !showEmojiPicker);
  }

  void _inputFocusListener() {
    if (showEmojiPicker && inputFocus.hasFocus) {
      emojiPickerType = EmojiPickerType.keyboard;
      setState(() => showEmojiPicker = false);
    }
  }

  void sendLocationAction() async {
    await showAdaptiveDialog(
      context: context,
      useRootNavigator: false,
      builder: (c) => SendLocationDialog(room: room, thread: thread),
    );
  }

  String _getSelectedEventString() {
    var copyString = '';
    if (selectedEvents.length == 1) {
      return selectedEvents.first
          .getDisplayEvent(timeline!)
          .calcLocalizedBodyFallback(MatrixLocals(L10n.of(context)));
    }
    for (final event in selectedEvents) {
      if (copyString.isNotEmpty) copyString += '\n\n';
      copyString += event
          .getDisplayEvent(timeline!)
          .calcLocalizedBodyFallback(
            MatrixLocals(L10n.of(context)),
            withSenderNamePrefix: true,
          );
    }
    return copyString;
  }

  void copyEventsAction() {
    Clipboard.setData(ClipboardData(text: _getSelectedEventString()));
    setState(() {
      showEmojiPicker = false;
      selectedEvents.clear();
    });
  }

  void copyLinkAction({Event? event}) {
    Clipboard.setData(
      ClipboardData(
        text: event != null
            ? event.getLink()
            : selectedEvents.map((event) => event.getLink()).join('\n'),
      ),
    );
    setState(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).copiedToClipboard)),
      );
      showEmojiPicker = false;
      selectedEvents.clear();
    });
  }

  void recoverEventAction({Event? event}) async {
    final mx = Matrix.of(context);
    if (!await mx.client.isSynapseAdministrator()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).errorRecoveringMessageNoAdmin)),
      );
      return;
    }
    event ??= selectedEvents.single;
    await mx.client.reportEvent(
      roomId,
      event.eventId,
      reason: "Extera (Next) Redacted Event Recover",
    );

    final reports = await mx.client.getEventReports();
    final report = reports.firstWhere(
      (rep) => rep['room_id'] == roomId && rep['event_id'] == event!.eventId,
    );
    final recoveredEvent = await mx.client.getReportedEvent(report['id']);

    if (recoveredEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).errorRecoveringMessage)),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext ctx) {
          return RecoveredEventDialog(
            event: recoveredEvent,
            timeline: timeline!,
          );
        },
        fullscreenDialog: true,
      ),
    );
  }

  void translateEventAction({Event? event}) async {
    if (!AppSettings.messageTranslation.value) {
      return;
    }
    event ??= selectedEvents.single;
    ScaffoldMessenger.of(
      context,
    ).showLoadingSnackBar(L10n.of(context).translating);
    var text = event.isRichMessage ? event.formattedText : event.text;
    final content = {...event.content};
    try {
      text = await Translator.translate(
        text,
        AppSettings.translationTargetLanguage.value.isEmpty
            ? PlatformDispatcher.instance.locale.languageCode
            : AppSettings.translationTargetLanguage.value,
        AppSettings.exteraServiceUrl.value,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).errorTranslatingMessage)),
      );
      return;
    }
    if (event.isRichMessage) {
      content['formatted_body'] = text;
    } else {
      content['body'] = text;
    }
    content['xyz.extera.translated'] = true;
    ScaffoldMessenger.of(context).clearSnackBars();
    await showAdaptiveBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return TranslatedEventDialog(
          event: Event(
            content: content,
            type: 'm.room.message',
            eventId: event!.eventId,
            senderId: event.senderId,
            originServerTs: event.originServerTs,
            room: room,
          ),
          timeline: timeline!,
        );
      },
    );
  }

  void reportEventAction({Event? event}) async {
    event ??= selectedEvents.single;
    final score = await showModalActionPopup<int>(
      context: context,
      title: L10n.of(context).reportMessage,
      message: L10n.of(context).howOffensiveIsThisContent,
      cancelLabel: L10n.of(context).cancel,
      actions: [
        AdaptiveModalAction(
          value: -100,
          label: L10n.of(context).extremeOffensive,
        ),
        AdaptiveModalAction(value: -50, label: L10n.of(context).offensive),
        AdaptiveModalAction(value: 0, label: L10n.of(context).inoffensive),
      ],
    );
    if (score == null) return;
    final reason = await showTextInputDialog(
      context: context,
      title: L10n.of(context).whyDoYouWantToReportThis,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      hintText: L10n.of(context).reason,
    );
    if (reason == null || reason.isEmpty) return;
    final result = await showFutureLoadingDialog(
      context: context,
      future: () => Matrix.of(context).client.reportEvent(
        event!.roomId!,
        event.eventId,
        reason: reason,
        score: score,
      ),
    );
    if (result.error != null) return;
    setState(() {
      showEmojiPicker = false;
      selectedEvents.clear();
    });
  }

  void deleteErrorEventsAction() async {
    try {
      if (selectedEvents.any((event) => event.status != EventStatus.error)) {
        throw Exception(
          'Tried to delete failed to send events but one event is not failed to sent',
        );
      }
      for (final event in selectedEvents) {
        await event.cancelSend();
      }
      setState(selectedEvents.clear);
    } catch (e, s) {
      ErrorReporter(
        context,
        'Error while delete error events action',
      ).onErrorCallback(e, s);
    }
  }

  void discussAction({Event? threadRootEvent}) async {
    final event = threadRootEvent ?? selectedEvents.first;
    if (!room.threads.containsKey(event.eventId)) {
      room.threads[event.eventId] = Thread(
        room: room,
        rootEvent: event,
        client: room.client,
        currentUserParticipated: false,
        count: 0,
        highlightCount: 0,
        notificationCount: 0,
      );
    }

    context.go('/rooms/$roomId/threads/${event.eventId}');
    selectedEvents.clear();
  }

  void endPollAction({Event? event}) async {
    event ??= selectedEvents.first;
    final client = currentRoomBundle.firstWhere(
      (cl) => event!.senderId == cl!.userID,
      orElse: () => null,
    );
    if (client == null) return;
    if (event.senderId != client.userID) return;
    await room.sendEvent({
      'org.matrix.msc1767.text': 'Ended poll',
      'm.relates_to': {'rel_type': 'm.reference', 'event_id': event.eventId},
      'body': 'Ended poll',
    }, type: 'org.matrix.msc3381.poll.end');
  }

  void redactEventsAction({Event? event}) async {
    final events = event != null ? [event] : selectedEvents;
    final reasonInput = events.any((event) => event.status.isSent)
        ? await showTextInputDialog(
            context: context,
            title: L10n.of(context).redactMessage,
            message: L10n.of(context).redactMessageDescription,
            isDestructive: true,
            hintText: L10n.of(context).optionalRedactReason,
            okLabel: L10n.of(context).remove,
            cancelLabel: L10n.of(context).cancel,
          )
        : null;
    if (reasonInput == null) return;
    final reason = reasonInput.isEmpty ? null : reasonInput;
    for (final event in events) {
      await showFutureLoadingDialog(
        context: context,
        future: () async {
          if (event.status.isSent) {
            if (event.canRedact) {
              await event.redactEvent(reason: reason);
            } else {
              final client = currentRoomBundle.firstWhere(
                (cl) => events.first.senderId == cl!.userID,
                orElse: () => null,
              );
              if (client == null) {
                return;
              }
              final room = client.getRoomById(roomId)!;
              await Event.fromJson(
                event.toJson(),
                room,
              ).redactEvent(reason: reason);
            }
          } else {
            await event.cancelSend();
          }
        },
      );
    }
    setState(() {
      showEmojiPicker = false;
      selectedEvents.clear();
    });
  }

  List<Client?> get currentRoomBundle {
    final clients = Matrix.of(context).currentBundle!;
    clients.removeWhere((c) => c!.getRoomById(roomId) == null);
    return clients;
  }

  bool get canRedactSelectedEvents {
    if (isArchived) return false;
    final clients = Matrix.of(context).currentBundle;
    for (final event in selectedEvents) {
      if (!event.status.isSent) return false;
      if (event.canRedact == false &&
          !(clients!.any((cl) => event.senderId == cl!.userID))) {
        return false;
      }
    }
    return true;
  }

  bool get canPinSelectedEvents {
    if (isArchived ||
        !room.canChangeStateEvent(EventTypes.RoomPinnedEvents) ||
        selectedEvents.length != 1 ||
        !selectedEvents.single.status.isSent) {
      return false;
    }
    return true;
  }

  bool get canEditSelectedEvents {
    if (isArchived ||
        selectedEvents.length != 1 ||
        !selectedEvents.first.status.isSent) {
      return false;
    }
    return currentRoomBundle.any(
      (cl) => selectedEvents.first.senderId == cl!.userID,
    );
  }

  void forwardEventsAction({Event? event}) async {
    await showScaffoldDialog(
      context: context,
      builder: (context) => ShareScaffoldDialog(
        items: selectedEvents.isEmpty
            ? [ContentShareItem(event!.content)]
            : selectedEvents
                  .map((event) => ContentShareItem(event.content))
                  .toList(),
      ),
    );
    if (!mounted) return;
    setState(() => selectedEvents.clear());
  }

  void sendAgainAction({Event? event}) {
    event ??= selectedEvents.first;
    if (event.status.isError) {
      event.sendAgain();
    }
    final allEditEvents = event
        .aggregatedEvents(timeline!, RelationshipTypes.edit)
        .where((e) => e.status.isError);
    for (final e in allEditEvents) {
      e.sendAgain();
    }
    setState(() => selectedEvents.clear());
  }

  void replyAction({Event? replyTo}) {
    setState(() {
      replyEvent = replyTo ?? selectedEvents.first;
      selectedEvents.clear();
    });
    inputFocus.requestFocus();
  }

  void setReplyMention(bool b) {
    setState(() {
      replyMention = b;
    });
  }

  void scrollToEventId(String eventId, {bool highlightEvent = true}) async {
    final foundEvent = timeline!.events.firstWhereOrNull(
      (event) => event.eventId == eventId,
    );

    final eventIndex = foundEvent == null
        ? -1
        : timeline!.events
              .filterByVisibleInGui(exceptionEventId: eventId)
              .indexOf(foundEvent);

    if (eventIndex == -1) {
      setState(() {
        timeline = null;
        _scrolledUp = false;
        loadTimelineFuture = _getTimeline(eventContextId: eventId).onError(
          ErrorReporter(
            context,
            'Unable to load timeline after scroll to ID',
          ).onErrorCallback,
        );
      });
      await loadTimelineFuture;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        scrollToEventId(eventId);
      });
      return;
    }
    if (highlightEvent) {
      setState(() {
        scrollToEventIdMarker = eventId;
      });
    }
    await scrollController.scrollToIndex(
      eventIndex + 1,
      duration: FluffyThemes.animationDuration,
      preferPosition: AutoScrollPosition.middle,
    );
    _updateScrollController();
  }

  void scrollDown() async {
    if (!timeline!.allowNewEvent) {
      setState(() {
        timeline = null;
        _scrolledUp = false;
        loadTimelineFuture = _getTimeline().onError(
          ErrorReporter(
            context,
            'Unable to load timeline after scroll down',
          ).onErrorCallback,
        );
      });
      await loadTimelineFuture;
    }
    scrollController.jumpTo(0);
  }

  void onEmojiSelected(Category? _, PickerEmoji emoji) {
    room.client.addRecentEmoji(emoji.customData ?? emoji.standardEmoji!.char);
    // print('selected emoji ${emoji.customData ?? emoji.standardEmoji!.char}');
    switch (emojiPickerType) {
      case EmojiPickerType.reaction:
        senEmojiReaction(emoji);
        break;
      case EmojiPickerType.keyboard:
        typeEmoji(emoji);
        onInputBarChanged(sendController.text);
        break;
    }
  }

  void senEmojiReaction(PickerEmoji? emoji) {
    setState(() => showEmojiPicker = false);
    if (emoji == null) return;
    // make sure we don't send the same emoji twice
    if (_allReactionEvents.any(
      (e) =>
          e.content.tryGetMap('m.relates_to')?['key'] ==
          (emoji.standardEmoji?.char ?? emoji.customData),
    )) {
      return;
    }
    return sendEmojiAction(emoji.standardEmoji?.char ?? emoji.customData);
  }

  void typeEmoji(PickerEmoji? emoji) {
    if (emoji == null) return;
    if (emoji.type == .custom) {
      typeCustomEmoji(emoji);
      return;
    }
    final text = sendController.text;
    final selection = sendController.selection;
    final char = emoji.standardEmoji!.char;
    final newText = sendController.text.isEmpty
        ? char
        : text.replaceRange(selection.start, selection.end, char);
    sendController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        // don't forget an UTF-8 combined emoji might have a length > 1
        offset: selection.baseOffset + char.length,
      ),
    );
  }

  void typeCustomEmoji(PickerEmoji emoji) {
    final text = sendController.text;
    final selection = sendController.selection;

    final customId = emoji.customId ?? emoji.customData ?? '';
    final insertPack = emoji.categoryId;

    var isUnique = true;
    if (customId.isNotEmpty && insertPack != null) {
      final emotePacks = room.getImagePacks(ImagePackUsage.emoticon);
      for (final pack in emotePacks.entries) {
        if (pack.key == insertPack) continue;
        for (final emote in pack.value.images.entries) {
          if (emote.key == customId) {
            isUnique = false;
            break;
          }
        }
        if (!isUnique) break;
      }
    }

    final packPrefix = (!isUnique && insertPack != null) ? '$insertPack~' : '';
    final insertText = ':$packPrefix$customId: ';

    final start = (selection.isValid ? selection.start : text.length).clamp(
      0,
      text.length,
    );
    final end = (selection.isValid ? selection.end : text.length).clamp(
      0,
      text.length,
    );

    final newText = text.isEmpty
        ? insertText
        : text.replaceRange(start, end, insertText);
    final cursorOffset = (start + insertText.length).clamp(0, newText.length);

    sendController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  late Iterable<Event> _allReactionEvents;

  void emojiPickerBackspace() {
    switch (emojiPickerType) {
      case EmojiPickerType.reaction:
        setState(() => showEmojiPicker = false);
        break;
      case EmojiPickerType.keyboard:
        sendController
          ..text = sendController.text.characters.skipLast(1).toString()
          ..selection = TextSelection.fromPosition(
            TextPosition(offset: sendController.text.length),
          );
        break;
    }
  }

  void pickEmojiReactionAction(Iterable<Event> allReactionEvents) async {
    _allReactionEvents = allReactionEvents;
    emojiPickerType = EmojiPickerType.reaction;
    setState(() => showEmojiPicker = true);
  }

  void sendEmojiAction(String? emoji) async {
    final events = List<Event>.from(selectedEvents);
    setState(() => selectedEvents.clear());
    for (final event in events) {
      await room.sendReaction(event.eventId, emoji!);
    }
  }

  void clearSelectedEvents() => setState(() {
    selectedEvents.clear();
    showEmojiPicker = false;
  });

  void clearSingleSelectedEvent() {
    if (selectedEvents.length <= 1) {
      clearSelectedEvents();
    }
  }

  void editSelectedEventAction({Event? event}) {
    event ??= selectedEvents.first;
    final client = currentRoomBundle.firstWhere(
      (cl) => event!.senderId == cl!.userID,
      orElse: () => null,
    );
    if (client == null) {
      return;
    }
    setSendingClient(client);
    setState(() {
      pendingText = sendController.text;
      editEvent = event;
      sendController.text = editEvent!
          .getDisplayEvent(timeline!)
          .calcLocalizedBodyFallback(
            MatrixLocals(L10n.of(context)),
            withSenderNamePrefix: false,
            hideReply: true,
          );
      selectedEvents.clear();
    });
    inputFocus.requestFocus();
  }

  void goToNewRoomAction() async {
    final result = await showFutureLoadingDialog(
      context: context,
      future: () async {
        final users = await room.requestParticipants(
          [Membership.join, Membership.leave],
          true,
          false,
        );
        users.sort((a, b) => a.powerLevel.compareTo(b.powerLevel));
        final via = users
            .map((user) => user.id.domain)
            .whereType<String>()
            .toSet()
            .take(10)
            .toList();
        return room.client.joinRoom(
          room
              .getState(EventTypes.RoomTombstone)!
              .parsedTombstoneContent
              .replacementRoom,
          via: via,
        );
      },
    );
    if (result.error != null) return;
    if (!mounted) return;
    context.go('/rooms/${result.result!}');

    await showFutureLoadingDialog(context: context, future: room.leave);
  }

  ContextMenuController? _contextMenuController;

  void closeMessageMenu() {
    if (PlatformInfos.isMobile) {
      Navigator.of(context).pop(); // in 2
    } else {
      _contextMenuController?.remove();
    }
  }

  void _openMenu(Event event, Offset? tapPosition) {
    if (PlatformInfos.isMobile) {
      showAdaptiveBottomSheet(
        context: context,
        builder: (context) {
          return MessageContextMenu(controller: this, event: event);
        },
        useRootNavigator: false,
      );
    } else {
      _contextMenuController?.remove();
      _contextMenuController = ContextMenuController();

      _contextMenuController!.show(
        context: context,
        contextMenuBuilder: (context) {
          return _ContextMenuOverlay(
            tapPosition: tapPosition ?? Offset.zero,
            onDismiss: () => _contextMenuController?.remove(),
            child: MessageContextMenu(controller: this, event: event),
          );
        },
      );
    }
  }

  void onSelectMessage(Event event, Offset? tapPosition) {
    if (selectedEvents.isEmpty) {
      _openMenu(event, tapPosition);
    } else {
      onMultiSelect(event);
    }
  }

  void onMultiSelect(Event event) {
    if (selectedEvents.contains(event)) {
      setState(() => selectedEvents.remove(event));
    } else {
      setState(() => selectedEvents.add(event));
    }
    selectedEvents.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
  }

  void showReadReceipts({Event? event}) {
    event ??= selectedEvents.first;
    final receipts = room.getReceipts(timeline!, eventId: event.eventId);
    SeenByDialog(receipts).show(context);
  }

  void showEdits({Event? event}) {
    event ??= selectedEvents.first;
    final events = event.aggregatedEvents(timeline!, RelationshipTypes.edit);
    events.add(event);
    showAdaptiveBottomSheet(
      context: context,
      builder: (context) {
        return MessageEditsDialog(
          event: event!,
          events: events.sortedBy((element) => element.originServerTs).toSet(),
          controller: this,
        );
      },
    );
  }

  int? findChildIndexCallback(Key key, Map<String, int> thisEventsKeyMap) {
    // this method is called very often. As such, it has to be optimized for speed.
    if (key is! ValueKey) {
      return null;
    }
    final eventId = key.value;
    if (eventId is! String) {
      return null;
    }
    // first fetch the last index the event was at
    final index = thisEventsKeyMap[eventId];
    if (index == null) {
      return null;
    }
    // we need to +1 as 0 is the typing thing at the bottom
    return index + 1;
  }

  void onInputBarSubmitted(_) {
    send();
  }

  void onAddPopupMenuButtonSelected(String choice) {
    if (choice == 'file') {
      sendFileAction();
    }
    if (choice == 'image') {
      sendFileAction(type: FileType.image);
    }
    if (choice == 'video') {
      sendFileAction(type: FileType.video);
    }
    if (choice == 'poll') {
      sendPollAction();
    }
    if (choice == 'camera') {
      openCameraAction();
    }
    if (choice == 'camera-video') {
      openVideoCameraAction();
    }
    if (choice == 'location') {
      sendLocationAction();
    }
  }

  unpinEvent(String eventId) async {
    final response = await showOkCancelAlertDialog(
      context: context,
      title: L10n.of(context).unpin,
      message: L10n.of(context).confirmEventUnpin,
      okLabel: L10n.of(context).unpin,
      cancelLabel: L10n.of(context).cancel,
    );
    if (response == OkCancelResult.ok) {
      final events = room.pinnedEventIds
        ..removeWhere((oldEvent) => oldEvent == eventId);
      showFutureLoadingDialog(
        context: context,
        future: () => room.setPinnedEvents(events),
      );
    }
  }

  void pinEvent({Event? event}) {
    final pinnedEventIds = room.pinnedEventIds;
    final selectedEventIds = event != null
        ? [event.eventId]
        : selectedEvents.map((e) => e.eventId).toSet();
    final unpin =
        selectedEventIds.length == 1 &&
        pinnedEventIds.contains(selectedEventIds.single);
    if (unpin) {
      pinnedEventIds.removeWhere(selectedEventIds.contains);
    } else {
      pinnedEventIds.addAll(selectedEventIds);
    }
    showFutureLoadingDialog(
      context: context,
      future: () => room.setPinnedEvents(pinnedEventIds),
    );
  }

  Timer? _storeInputTimeoutTimer;
  static const Duration _storeInputTimeout = Duration(milliseconds: 500);

  void onInputBarChanged(String text) {
    if (_inputTextIsEmpty != text.isEmpty) {
      setState(() {
        _inputTextIsEmpty = text.isEmpty;
      });
    }

    _storeInputTimeoutTimer?.cancel();
    _storeInputTimeoutTimer = Timer(_storeInputTimeout, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_$roomId', text);
    });
    if (text.endsWith(' ') && Matrix.of(context).hasComplexBundles) {
      final clients = currentRoomBundle;
      for (final client in clients) {
        final prefix = client!.sendPrefix;
        if ((prefix.isNotEmpty) &&
            text.toLowerCase() == '${prefix.toLowerCase()} ') {
          setSendingClient(client);
          setState(() {
            sendController.clear();
          });
          return;
        }
      }
    }
    if (shouldSendTypingNotifications(room.client, roomId)) {
      typingCoolDown?.cancel();
      typingCoolDown = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        typingCoolDown = null;
        currentlyTyping = false;
        room.setTyping(false);
      });
      typingTimeout ??= Timer(const Duration(seconds: 30), () {
        typingTimeout = null;
        currentlyTyping = false;
      });
      if (!currentlyTyping) {
        currentlyTyping = true;
        room.setTyping(
          true,
          timeout: const Duration(seconds: 30).inMilliseconds,
        );
      }
    }
  }

  bool _inputTextIsEmpty = true;

  bool get isArchived =>
      {Membership.leave, Membership.ban}.contains(room.membership);

  void showEventInfo([Event? event]) =>
      (event ?? selectedEvents.single).showInfoDialog(context);

  void onPhoneButtonTap() async {
    // VoIP required Android SDK 21
    if (PlatformInfos.isAndroid) {
      DeviceInfoPlugin().androidInfo.then((value) {
        if (value.version.sdkInt < 21) {
          Navigator.pop(context);
          showOkAlertDialog(
            context: context,
            title: L10n.of(context).unsupportedAndroidVersion,
            message: L10n.of(context).unsupportedAndroidVersionLong,
            okLabel: L10n.of(context).close,
          );
        }
      });
    }
    final callType = await showModalActionPopup<CallType>(
      context: context,
      title: L10n.of(context).warning,
      message: L10n.of(context).videoCallsBetaWarning,
      cancelLabel: L10n.of(context).cancel,
      actions: [
        AdaptiveModalAction(
          label: L10n.of(context).voiceCall,
          icon: const Icon(Icons.phone_outlined),
          value: CallType.kVoice,
        ),
        AdaptiveModalAction(
          label: L10n.of(context).videoCall,
          icon: const Icon(Icons.video_call_outlined),
          value: CallType.kVideo,
        ),
      ],
    );
    if (callType == null) return;

    final voipPlugin = Matrix.of(context).voipPlugin;
    try {
      final session = await voipPlugin!.voip.inviteToCall(room, callType);
      voipPlugin.addCallingOverlay(session.callId, session);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
      Logs().e("onPhoneButtonTap", e);
    }
  }

  void cancelReplyEventAction() => setState(() {
    if (editEvent != null) {
      sendController.text = pendingText;
      pendingText = '';
    }
    replyEvent = null;
    editEvent = null;
  });

  late final ValueNotifier<bool> _displayChatDetailsColumn;

  void toggleDisplayChatDetailsColumn() async {
    await AppSettings.displayChatDetailsColumn.setItem(
      !_displayChatDetailsColumn.value,
    );
    _displayChatDetailsColumn.value = !_displayChatDetailsColumn.value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: ChatView(this)),
        AnimatedSize(
          duration: FluffyThemes.animationDuration,
          curve: FluffyThemes.animationCurve,
          child: ValueListenableBuilder(
            valueListenable: _displayChatDetailsColumn,
            builder: (context, displayChatDetailsColumn, _) {
              if (!FluffyThemes.isThreeColumnMode(context) ||
                  room.membership != Membership.join ||
                  !displayChatDetailsColumn) {
                return const SizedBox(height: double.infinity, width: 0);
              }
              return Container(
                width: FluffyThemes.columnWidth,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(width: 1, color: theme.dividerColor),
                  ),
                ),
                child: ChatDetails(
                  roomId: roomId,
                  embeddedCloseButton: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: toggleDisplayChatDetailsColumn,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum EmojiPickerType { reaction, keyboard }

class _ContextMenuOverlay extends StatelessWidget {
  final Offset tapPosition;
  final VoidCallback onDismiss;
  final Widget child;

  const _ContextMenuOverlay({
    required this.tapPosition,
    required this.onDismiss,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.translucent,
          child: Container(color: Colors.transparent),
        ),
        CustomSingleChildLayout(
          delegate: _ContextMenuLayoutDelegate(tapPosition: tapPosition),
          child: child,
        ),
      ],
    );
  }
}

class _ContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset tapPosition;

  _ContextMenuLayoutDelegate({required this.tapPosition});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const margin = 10.0;

    var left = tapPosition.dx;
    var top = tapPosition.dy;

    // If menu would overflow right edge, shift left
    if (left + childSize.width > size.width - margin) {
      left = size.width - childSize.width - margin;
    }
    // If menu would overflow left edge, clamp
    if (left < margin) left = margin;

    // If menu would overflow bottom edge, show above tap position
    if (top + childSize.height > size.height - margin) {
      top = tapPosition.dy - childSize.height;
    }
    // If menu would overflow top edge, clamp
    if (top < margin) top = margin;

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_ContextMenuLayoutDelegate oldDelegate) {
    return tapPosition != oldDelegate.tapPosition;
  }
}
