## Extera 26.4.31
- Fix message composer alignment
- Fix wrong sender name layout being used in images sent in threads
- Fix overlay sender names not being truncated correctly
- Fix user names in thread list taking too much space
- Do not show ignored users typing in chat list

## Extera 26.4.3
- Localize time in user profiles (@meoovv)
- Enable native spell check in message composer (@Quffik)
- Fix wrong extensions when downloading files
- Fix displaying filenames in audio messages
- Redesign message bubbles
- Update settings categories
- Fix variation emojis (e.g. skin tones) being displayed in emoji picker
- Remove push-to-talk in legacy calls

## Extera 26.4.2
- Show bottom navbar regardless of whether the room list is empty.
- Timezones in profiles.

## Extera 26.4.1
- Fix chat messages scrolling
- Show amount of people in a call as a filled button

## Extera 26.4.0
- Added support for LiveKit-backed calls (*Element Call*) behind a Labs feature.

## Extera 26.3.4
- Improved "About Extera" dialog.
- Minor design changes in settings.
- Added "Read only" (-1) power level template.
- Allowed "-" sign in power level input.
- Minor improvement in user profile page.
- Minor changes in message layouts: legacy bubbles, modern.
- Fixed modern message layout being aligned to the left instead of center.

## Extera 26.3.3
- Added TOFU (trust-on-first-use) support.
- Updated bootstrap process as in FluffyChat.
- Updated chat encryption page.

## Extera 26.3.2
- Improved selecting state messages
- Fix emote suggestion design flaw

## Extera 26.3.1
- Fix fonts related issues (again)
- Add message menus for state events (replying, reacting, discussing, viewing source...)
- Show reactions for state events
- Update design for message composer
- Feature: show raw profile fields
- Update navbar icons
- Feature: Option to show external bridged message
- Fix: Show all recent emojis in reaction picker
- UX: Right clicking on sticker shows sticker info.

## Extera 26.3.01
- Fix fonts related issues.

## Extera 26.3.0
- Renamed "Feature switches" to "Labs".
- Set custom fonts for UI, code blocks (monospace) and chat messages. ("Labs" option)
- Added an option to show seconds in message timestamps (@CherretGit)
- Extend frosted glass effect option to navigation bar
- Disable bubble gradient by default
- Include ISRG X2 certificate for older Android versions
- Fixed hide avatars in invites option

## Extera 26.2.9
- Redact & Reply to reactions.
- Update chat permissions settings page.
- Update read check marker in DMs.

## Extera 26.2.83
- Fix messages being not visible in threads.

## Extera 26.2.82
- Fix error dialog when rendering invalid LaTeX
- Fix error dialog sometimes appearing when following a message link
- Remove links underline (for rGoogleFeal this time)
- Make inline LaTeX syntax not appear when '$' sign is inside links

## Extera 26.2.81
- Fix new message bubbles layout issue

## Extera 26.2.8
- Add another version of bubble message layout (old one still available)
- Add status row to modern message layout
- Remove elevation for chat list appbar
- Right-click on a reaction now shows who reacted
- Remove links underline

## Extera 26.2.7
- Modern message layout
- Bugfixes

## Extera 26.2.61
- Fix inserting mentions

## Extera 26.2.6
- Message composer improvements
- Chat encryption settings page design improvements
- "New chat" FAB redesign
- Translations

## Extera 26.2.5
- Korean translations
- Locale fixes

## Extera 26.2.4
- Redesign navigation bar.
- Make legacy navigation bar more Material 3 compliant.
- Added support for stable MSC2666 (Mutual rooms).
- Added EXIF cleaning when uploading avatars and banners.
- Added file sending status icons.
- Fixed message edits sometimes being not handled.

## Extera 26.2.3
- Feature: swipeable drawer with spaces.
- Fix: when chat frosted glass effect is disabled, floating elements had extra unneccessary padding.

## Extera 26.2.21
- Fix edits.

## Extera 26.2.2
- Redesign message bottom status row.

## Extera 26.2.1
- Fix: message appear animation played twice

## Extera 26.2.0
- Scroll down button now will return to previous message (after opening a message from a reply).
- Revamped lock screen design.
- Update translations for Spanish and Japanese (these are machine translations).
- Ability to edit media captions.
- Forwarding messages now respects message edits.
- Replaced old closed-source translator backend to [Neurogate](https://codeberg.org/rustyraven/Neurogate).
- Account registration using password.
- Fix: stickers not being sent in threads.
- Fix: additional "@" sign in forward attribution.
- Fix: show spaces' rooms in global list regardless of settings, if current user does not participate in room's parent space
- Fix: space navigation rail not being updated after switching accounts
- Some optimisations

## Extera 26.1.68
- (actually) fix forward attribution.

## Extera 26.1.67
- Fixed forward attribution.

## Extera 26.1.66
- Optimisations and bugfixes.

## Extera 26.1.65
- Bugfixes.

## Extera 26.1.62
- Minor fixes and improvements.

## Extera 26.1.61
- Optimizations and fixes.

## Extera 26.1.6
- Wallpaper compression.
- Forward message attribution (toggleable).
- Design fixes.

## Extera 26.1.5
- Preview media by default
- Change font/font fallbacks through advanced config
- Various bugfixes

## Extera 26.1.4
- "People" tab (toggleable by a feature flag, enabled by default)
- Option to turn off media preview (also configurable per chat)

## Extera 26.1.33
- Remove duplicate close button in "loading" snackbars.

## Extera 26.1.32
- `EXTERA_HIDE_TITLEBAR=1` for borderless window.
- bugfixes and improvements

## Extera 26.1.31
- Fix little typo in MSC4320 Rich Presence rendering.

## Extera 26.1.3
- Option to hide "take photo/video" button in message composer.
- Update MSC4320 Rich Presence design view.
- Do not autoplay "cute events".
- Fix multiple bugs.

## Extera 26.1.2
- Translucency effect in chats behind a feature flag! (by @d2rkmean)
- Store wallpaper settings locally.
- Fix favourite stickers.
- Make sending files non-blocking.
- Improve sticker picker.
- Add explore rooms page.
- Minor design changes.
- Fix switching tabs when a space was selected.

## Extera 26.1.1
- Fix replying with pasted image (desktop).
- Add recent stickers feature.
- Add favourite stickers feature.

## Extera 26.1.0
- **UnifiedPush notifications for multiple accounts!**
- Fixed scrolling for recovered and translated message dialogs.
- Include attachment captions when using "Copy" action.
- Use dialogs when opening profiles on desktop.
- Video notes behind a feature flag (**unstable, do not use**)
- Fixed "Hide member changes in public chats" not having effect.
- Option to adjust sticker scale.

## Extera 26.0.91
- Translate hard-coded strings ("Poll details")
- Fix poll results window scrolling
- ~~Fix SSO/OIDC on mobile.~~ Click "Open in browser", this should work.
- Add Jitsi group calls behind a featire flag.
- Updated thread list view.

## Extera 26.0.9
- Profile banners
- Better UX for polls
- Predictive back gesture support for Android
- Fix link double underline
- Fix widget things
- Use system font option on android

## Extera 26.0.8
- Support for LaTeX formulas.
- Added ability to copy links by long pressing them.
- Moved legacy appbar/navbar switches to a seperate settings section.
- Added ability to toggle AI-powered message translations.
- New incoming invite UX.
- Added a background audio player.
- Partially select text in messages.
- Fixed crashing after sending a reaction (desktop).
- Render custom reactions instead of their URLs when opening list of who reacted.

## Extera 26.0.7
- Fixed message context menu.
- Added download button in message menu.
- Made navbar more responsive.

## Extera 26.0.6
- Fixed pasted images not having a name, so they weren't handled by Telegram bridge.
- Hide spaces and their rooms from global chat list.
- Fix < and > escaping in code blocks.
- Fix some styling issues.
- New invite dialog.
- New appbar and navbar design.

## Extera 26.0.5
- Fixed pasting images on Linux.
- Support viewing MSC4320 Rich Presences.
- Fix presence status related things.
- Fix reply mentions.
- Fix custom presences.

## Extera 26.0.4
- Added support for choosing Material 3 color palette.
- Fix chat switching hotkeys on Desktop. Alt+Arrow Up/Down to switch chats.
- Fixed "Auto mark as AFK" option not having effect.
- Fix room history visibility options being always enabled, regardless of power level.
- Add avatar border radius customisation.
- Rename "Chat backups" into "Key backups", because Matrix is already server-synced chat.
- Fix handling whitespaces and sequential line breaks in HTMLs.
- Fix "Space members can knock" room access option being always visible.
- Support HTTP ranges when loading videos (unencrypted rooms) and show progress bar for downloading videos (encrypted rooms).
- Allow cleartext HTTP traffic for 127.0.0.1 and localhost for use with Yggstack (on Android)
- Some optimisations and fixes.

## Extera 26.0.3
- Did some redesign to make it look like Material 3 Expressive.
- Get rid of emoji_picker_flutter, so now you can choose custom emojis from the picker.

## Extera 26.0.2
- Image editor. You can now edit images before sending them.
- Add call actions in notification on mobiles. Hang up, switch speaker, mute/unmute from notification.
- Optimised chat event list.

## Extera 26.0.1
- Fixed emoji settings lagging, when there are a lot of emojis added.
- Always show mute toggle in calls.
- Added unread badge on bottom navigation bar.
- Added QR code creation to share rooms.
- Added sound effects for microphone mute/unmute.
- Added microphone toggle global hotkey (does not work on Wayland).

## Extera 26.0.0
- Fixed Auto-update option being buggy.
- Hide Twemoji option for mobiles as a temporary solution.
- New ringtone: "Dream of light".
- Fix foreground service for calls.
- Simple widget implementation.
- Fix video thumbnails.
- Context actions for failed to send messages.
- Fixed a file trying to send again being outside of thread.

## Extera 25.1.2
- Fixed audio messages not playing.
- Fixed ringtone on Android.
- Brought back image previews before sending.
- Added a list of privacy settings set for different chats.
- Added update checking.
- Added call button in profile view.
- Twemoji font option.

## Extera 25.1.1
- Added context menu for messages. Now, when selecting a single message, a context menu will appear. Multi-selection is still available.
- Added timestamp and message status icon in message bubbles.
- Removed "seen by" row in favour of context menu and status icons.
- Always use foreground service for calls.
- Slide to answer/reject call on mobile.
- Custom privacy settings per room.
- Add ringtone "Homebase"
- Ringtone and calling sounds on Linux

## Extera 25.1.0
- Brought back calls. Just enable "Experimental video calls" and press that phone button in a chat - calls will probably work.
- Fixed screen sharing in calls. Screen sharing now works, the problem was the foreground service missing MEDIA_PROJECTION flag.
- Incoming calls will now use system ringtone.
- Added the "Seen by" dialog. Now you can see the whole exact list of users, who got the message.
- Redesigned user profile view. It is now a whole page and gives more information like mutual rooms.
- Added "About yourself" field. Tell the world about yourself, but remember to fit that only in 256 characters!
- (Probably) Fix video being stuck playing in background.
- An option to not send an image, if EXIF metadata has failed to clean. It was always on, but now an option.
- A new revamped UX for room emote settings, same as in FluffyChat.
- Optimise mxc_image. Removed AnimatedSwitcher from that file, I don't know what could happen, but it seems to reduce amount of widget updates.
- Removed some unnecessary emojis in translations (English and Russian).
- Added truncation of threads' latest message preview. No more thread previews larger than the root message itself.
- Remove CupertinoActivityIndicator from most parts. Now you won't see a loading indicator from iOS while using Android!
- Unsupported HTML tags are now rendered as plain text, instead of just being hidden!
- Bottom navigation bar instead of chat filter pills.
- Copy link action. Now, you can copy links to messages.
- Introducing background downloads on Linux! The `/sdcard/Download/Extera` directory, which is exclusive to Android, was hard-coded the whole time. Now it's picking various directories, depending on the platform. (Android and Linux supported only)
- Now you need to hit enter to start a global search - no more query leaking.
- Fixed rendering poll events, which were redacted. No more large yellow tiles.
- Fixed encryption key backup GUI: now the button has linear progress bar in it instead of circular, like in most parts of the app.
- Fixed poll events not being parsed properly on another clients. The problem was incorrect `kind` parameter.
- Update poll results when a new response was sent.
- Use download icon instead of share icon when selecting a message.
- Do not show "Block" action on group rooms.
- Hide translation button in encrypted rooms instead of displaying a long message, explaining why this feature does not work there.
- Optimise invitation selection view. It no longer requests all users' profiles.
...and some internal work :)

## Extera 2.1.0
- Introduce threads
- Add support for restricted join rule
- Improved UX for spaces
- fix: Create a subdirectory in the tmp directory