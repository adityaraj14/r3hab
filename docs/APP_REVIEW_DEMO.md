# App Review demo — screen recording

Recording script for Guideline 2.1 (Information Needed). Follow it on a physical iPhone. The shots below are the whole video.

**Show the time-based loop. Do not wait 24 hours to record it.**

R3hab’s value is a next-day check: log a session, come back about a day later, mark Better / Same / Worse, and let pain gate the next load. Reviewers will not wait. Record two acts, then cut them together:

1. **Act A** is a fresh install. It proves there is no account and that a session stays **24h pending**.
2. **Act B** uses a JSON backup generated the same calendar day. Prior days are already on the phone, so Progress, the overdue 24h sheet, and the stepped-back next load are on screen immediately.

The backup is sample log data (pain scores and set counts). It is not a patient record and not a claim that anyone’s tendon improved. When the app says “You’re doing well,” that sentence is its read of this window: training volume is up and morning pain is flat at 2. Say that. Do not add a healing claim.

## What this binary actually does

Verified against this repo. Use these facts in the voiceover.

| Piece | What is on screen |
| --- | --- |
| Product | Personal rehab log. First injury is jumper’s knee / patellar tendinopathy. Brand line is **R3 · Reduce · Rebuild · Return**. Phases in the app are A Flare, B Isometrics, C Heavy slow resistance. |
| Account | None. Welcome says **No account · No ads · Stored entirely on your iPhone**. |
| Storage | On-device SwiftData. No login, no cloud sync. |
| Health | Optional, read-only step count on the evening check-in. The recording never opens it. |
| Notifications | Optional local reminders. Leave them off so iOS does not show a permission prompt. |
| Day-1 loop | Morning pain → log a session (pain during required) → pain after the same day → that session stays **Pending** until a later morning. |
| Next load | `ProgressionEngine` reads completed seated-extension HSR logs. Today’s gold button shows `Today: 3×8 @ 35 lbs` when that is the target. The editor opens with those sets filled in. |
| 24h decision | An overdue Pending session puts **Needs your 24h call** / **Resolve 24h response** on Today. Choosing **Worse** selects **Soft cut** and shows: “Soft cut: stay in this phase, do less next time (−20–30% load, shorter holds, or fewer sets).” Saving shows **Take the next session easier**. |
| Charts | Progress tab, range **7**: **Training volume vs next morning**, plus the interpretation card. |

The app never prints the word “Hold” or “Drop” on Today. The back-off you show is the lower prescription (last log was **3×10 @ 35 lbs** with pain during **6**; next target is **3×8 @ 35 lbs**) and the Soft cut sentence. Pain during above 5 is the gate (`ProgressionEngine.painDuringLimit`).

## Leave these out

Do not open, scroll to, or mention:

- Account registration, login, password, or account deletion. They do not exist. The notes paragraph says so.
- In-app purchase, subscriptions, ads.
- Social features, sharing a log to a feed, or user-content reporting.
- Settings → **Debug**. **Seed sample week** exists only in Xcode Debug (`#if DEBUG` in `SettingsStubView`). It is absent from TestFlight and App Store binaries, and it only writes a week of check-ins plus one isometric session today. It does not create the HSR history, the overdue 24h row, or the 3×8 back-off. Do not use it for this video.
- **Simulate onboarding** (same Debug section). It is a temporary TestFlight control in the current source. Keep it off camera.
- The Health permission sheet, and any real step count.
- The notification permission sheet.
- A phase change. On the resolve sheet, stay on the suggested **Soft cut**. Do not switch the decision to **Hard drop** (that opens a phase step-back).
- Personal notes, names, clinic names, or a real diary. Use the generated backup.

Changing the iPhone’s date to fake “tomorrow” is out. It fights notifications and Health and still looks like a clock change. Import is the path.

## Build to record

Record the binary reviewers install: TestFlight or the App Store build of `R3hab` (`com.devrising.r3hab`), iOS 17 or later. A Debug install from Xcode is the wrong binary.

## Prep checklist

Do this before you press record.

- Physical iPhone. No Simulator.
- iOS 17 or later. Current public iOS is fine. The deployment target is 17.0.
- Delete R3hab, then install the Release/TestFlight build again so Act A starts empty. Deleting the app deletes the on-device log.
- Settings → Accessibility → Display & Text Size: Larger Text off, text size at the default. The app is dark-mode only.
- Focus or Do Not Disturb on. No banners, no calls, no personal Lock Screen notifications.
- Screen Recording will show in the Dynamic Island. Start the recording, wait until the indicator shrinks to the island, then begin the shot. Keep fingers off the top bar.
- Generate the backup **today**, on a computer in the **same time zone** as the phone. AirDrop `R3hab-review-demo-<today>.json` into Files. Import happens off camera between the two acts.
- If you slip past midnight, generate the file again and Replace again. A file from yesterday makes today’s check-in miss, and after you resolve 24h the gold button becomes **Log morning pain** instead of the load target.

## Generate the backup

On a Mac, from the repo, the same calendar day you record:

```bash
python3 scripts/app-review-demo-backup.py > ~/Desktop/R3hab-review-demo-$(date +%F).json
```

Stderr prints the strings you should see after import. If those strings are wrong on the phone, stop and re-import. Do not improvise a different history.

Between Act A and Act B, off camera:

1. Today → gear → **Import JSON backup…**
2. **Replace all data** (not Merge).
3. Pick today’s JSON in Files.
4. Dismiss **Import complete**. The message should say **Mode: Replace all data. Check-ins: 7, sessions: 3.**
5. Confirm Today’s gold button is **Resolve 24h response** and the phase chip is **C · Heavy slow resistance**.
6. Do not scroll Settings down to **Debug**.

Replace wipes the Act A log. That is the point of the cut. Act B is a different day in the story, already stored on the phone.

Your own TestFlight diary is a fallback only when it already has an overdue Pending seated-extension session whose pain during is above 5, plus several mornings of pain. The generated file is the path that matches this script. If you use a real diary, clear notes of names and places before you record.

## How to record

Two screen recordings. Edit them into one clip, about **2:30–3:30**. Silent is fine if the title cards are in the edit. A short voiceover is better. Lines below are the whole script. Read them as written.

Title cards, full screen, about 3 seconds each, added in Photos or iMovie:

1. **Day 1** — before Act A.
2. **Later. Prior days are already on this iPhone** — between the acts. This is the time jump. Say it once in the voiceover too.
3. Optional end card, 2 seconds: **Logs stay on the iPhone. No account.**

Cut pauses, the file picker, and any miss-tap. Leave the app chrome readable. Do not speed the clip up so much that the Soft cut sentence cannot be read.

## Act A — fresh install (~1:15)

Start recording on the first onboarding screen. Tabs along the bottom are **Today**, **History**, **Progress**.

| Time | Tap | Say |
| --- | --- | --- |
| 0:00 | Title card **Day 1**, then the Welcome screen. Hold on **No account · No ads · Stored entirely on your iPhone** and the three cards **Reduce**, **Rebuild**, **Return**. | “R3hab is a personal rehab log. There is no account. Data stays on the iPhone.” |
| 0:12 | **Continue**. | |
| 0:16 | Injury screen. The only card is jumper’s knee / patellar tendinopathy. **That’s my injury**. | “It starts from a patellar tendinopathy log.” |
| 0:24 | Lift screen. **Seated extension** is already selected. **That’s my lift**. | |
| 0:30 | **Where are you right now?** **Phase A · Flare** is already selected. Leave it. You can show the line “Phase A is Reduce.” **Continue**. | “Phase A is the reduce phase. I’ll log day one here.” |
| 0:38 | **Not a clinic.** Leave **Notifications** off. **Let’s load**. | “It’s a log, not a clinic and not a medical device.” |
| 0:46 | Today. **Log morning pain**. Tap **2** under **Knee resting pain**. **Save**. | “Morning pain is a 0 to 10 score.” |
| 0:56 | **Log seated extension**. The button may also say **Today: 3×8**. Ignore that line in this act. Phase A opens the isometric hold sheet (**Seated extension hold**), not the heavy-slow rep target. Tap **2** under **During (required)**. **Save**. | “Pain during the session is required. The 24-hour check is not filled in yet.” |
| 1:08 | If the gold button is **Log pain after**, open it, tap **2**, **Save**. If it says **Log evening pain**, do not open it. Evening can request Apple Health. | “Pain after is the same day. The next-morning call waits.” |
| 1:16 | **History**. Today’s row shows **24h pending** in orange. Stop. | “That session stays pending until a later morning. We don’t wait on the clock for the review.” |

Stop the recording. A small **Stable mornings: 1/3** line may sit on Today after the morning save. Let it be in frame. Do not explain it.

## Act B — prior days (~1:45)

Start this recording only after the import alert says 7 check-ins and 3 sessions, and Today shows **Resolve 24h response**.

The pending session is dated two days ago (pain during 6, 3×10 at 35 lb). Today’s morning and evening scores are already 2, so the gold button is the 24h call rather than another check-in. The streak card may say **2 sessions** and **Due today**. Leave the quote alone.

| Time | Tap | Say |
| --- | --- | --- |
| 0:00 | Title card **Later. Prior days are already on this iPhone.** Then open **Progress**. The range control stays on **7**. Hold on **You’re doing well.** and **Volume is up and pain is holding steady.** Scroll just enough to show **Training volume vs next morning**. | “These are earlier days already stored on the phone. The chart is volume against next-morning pain. In this window volume is up and morning pain is flat. That is all that sentence means.” |
| 0:18 | **Today**. Hold on **Needs your 24h call** and **Resolve 24h response**. Then the **Seated extension** row under it: warm-up, then **8 @ 35 lbs** on the working lines. | “The 24-hour call is due before the next session. The next load is already 3×8 at 35 pounds, one step under the last log, because pain during that session was 6.” |
| 0:32 | Tap the **Seated extension** row (the row, not the gold button). **Log session** opens with a warm-up at 35 and three working sets of **8** at **35**. **Cancel**. Do not save. | “The log opens on that target. Nothing is saved in this shot.” |
| 0:44 | **History** → **Workouts**. The top workout is **Seated extension**, **Pending** in orange, pain during **6**, dated two days ago. Do not tap the row. | “The older session is still pending in History. The suggestion text is on Today’s resolve sheet, so the resolve happens there.” |
| 0:52 | **Today** → **Resolve 24h response**. The sheet is **Resolve 24h**. It opens on **Same**, decision **Stay**. Tap **Worse**. Decision moves to **Soft cut**. Hold on the footnote: “Soft cut: stay in this phase, do less next time…” | “Worse suggests a soft cut: stay in the phase and do less next time. I can still change the decision. I’ll keep the suggestion.” |
| 1:08 | **Save**. Alert **Take the next session easier**. Read the body. **Got it**. | “Saving that response is the back-off. It is a logging suggestion, not a diagnosis.” |
| 1:20 | Today’s gold button is now **Log seated extension** with **Today: 3×8 @ 35 lbs**. Tap it. The sets are again 8 at 35. **Cancel**. Stop. | “The next session target stays 3×8 at 35. That’s the pain-gated step back, without waiting a day to film it.” |

Do not tap **Snooze to morning**, **Mark rest**, **Hard drop**, or **Save** on the new log.

History → tap workout → **Edit session** also has Better / Same / Worse, but it does not show the Soft cut sentence. That is why the resolve in this video is the Today sheet.

## If the phone disagrees with the script

Stop recording and fix the data. Do not narrate around a different screen.

| What you see | What to do |
| --- | --- |
| **Seed sample week** is missing | Expected on TestFlight and App Store. Use the JSON. |
| Import failed, unsupported version, or could not read | Regenerate with `scripts/app-review-demo-backup.py` from this repo. Schema is version 6. |
| Counts are not 7 and 3 | You merged, or an older file was imported. **Replace all data** with today’s file. |
| Gold button is **Log morning pain** or **Log evening pain** | The file is from another calendar day, or the phone time zone does not match the computer. Regenerate today and Replace. |
| Gold button is **Nothing to load today** | Today was treated as a rest day. The backup’s last session must be two days ago. Regenerate today and Replace. |
| Progress sentence is different | Range must stay on **7**, and the file must be from today. |
| **Today: 3×10 @ 35 lbs** after resolve | The pending session’s pain during was not 6. Replace with a freshly generated file. |
| Worse suggests **Hard drop** | A previous resolved session was also Worse. This backup’s previous one is Better, so Worse must land on Soft cut. Replace the file. |
| Less than 48 hours warning in the editor | The pending session’s timestamp is too recent. Regenerate and Replace. Cancel if you already opened the sheet. |

## Appendix — App Review Notes

Paste this into App Review Information. It matches the video.

```
R3hab is a local-only rehab logging app for patellar tendinopathy (jumper’s knee). There is no account, so there is no registration, login, or account-deletion screen. Logs are stored on the device with SwiftData. Settings includes JSON export and import as the backup. The app does not require a network connection.

Apple Health is optional and read-only (step count on the evening check-in). The demo does not grant Health access. Local notifications are optional and are left off in the video.

The video has two parts. Part 1 is a fresh install: onboarding, a morning pain check-in (0–10), logging a session with pain during, pain after, and History showing that session as 24h pending. The 24-hour response is filled in on a later morning. Part 2 does not wait on the clock. It shows the same phone after restoring a JSON backup of prior days (Settings → Import JSON backup → Replace all data). That backup is sample log data.

In part 2, Progress (7-day) charts training volume against next-morning pain. Today shows an overdue 24h item from two days earlier. Resolving it as Worse selects Soft cut (“do less next time”) and confirms with “Take the next session easier.” The next session target is 3×8 at 35 lb, one step below the last logged 3×10 at 35 lb, because pain during that session was 6 (the in-app gate is 5). The log sheet opens with those sets filled in.

R3hab does not diagnose, prescribe, or replace a clinician. Suggested decisions can be overridden.
```
