# Conciser

**Turn recorded conversations into clear decisions — without handing your recording to a transcription service.**

Conciser is a native macOS app for turning a video or audio recording into a speaker-labeled transcript, then into a useful meeting verdict: a concise summary, the points that mattered, the overall sentiment, and a quick assessment of what happened.

Drag in a recording. Get back to the conversation.

## Why Conciser?

- **Privacy first.** Transcription and speaker identification stay entirely on your Mac.
- **Know who said what.** Conciser aligns timestamps with speaker diarization to label the conversation by speaker.
- **Keep the useful part.** Generate an on-demand verdict with a summary, key points, sentiment, and assessment.
- **Built for real recordings.** Drop in meeting videos, voice notes, interviews, and more — no re-encoding ceremony.

> Only the optional verdict step uses Google Gemini. Your transcript is sent to Google only after you explicitly click **Generate Verdict**.

## How it works

```text
video or audio
  → extract 16 kHz mono audio
  → WhisperKit transcription (word timestamps)
  → FluidAudio speaker diarization
  → align words and speakers by time overlap
  → speaker-labeled transcript
  → optional Gemini verdict
```

## What you get

1. A searchable, speaker-labeled transcript of your recording.
2. An optional AI verdict with:
   - a concise meeting summary;
   - the key points raised;
   - overall sentiment; and
   - an assessment of decisions, follow-ups, and risks.

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon Mac
- Xcode 26.6 or later

## Build and run

```bash
open Conciser.xcodeproj
```

Then press `⌘R` in Xcode. Or build from the command line:

```bash
xcodebuild -project Conciser.xcodeproj -scheme Conciser -configuration Debug build
```

## First-run setup

1. Open Settings with `⌘,` and add a [Gemini API key](https://ai.google.dev) to enable the optional verdict.
2. Choose Indonesian, English, or automatic language detection.
3. On the first transcription, Conciser downloads the WhisperKit and FluidAudio models. Later transcription and speaker identification run offline.

## Use it

1. Drag a video or audio file onto the drop zone, or choose one from Finder.
2. Wait while Conciser extracts audio, transcribes it, and identifies speakers.
3. Review the labeled transcript.
4. Click **Generate Verdict** when you want a concise meeting readout.

Common formats such as `.mp4`, `.mov`, `.m4a`, `.wav`, and `.mp3` are supported.

## Privacy

Conciser uses on-device [WhisperKit](https://github.com/argmaxinc/WhisperKit) for transcription and [FluidAudio](https://github.com/FluidInference/FluidAudio) for speaker diarization. Those steps do not leave your Mac.

The optional verdict is generated through the Google Gemini API. Conciser sends the transcript only when you ask it to generate one.

## Project layout

```text
Conciser/
  Models/      Transcript, speaker, verdict, and processing-state models
  Services/    Audio extraction, transcription, diarization, merging, and verdict generation
  ViewModels/  App pipeline state
  Views/       Native SwiftUI interface
```

## A note on accuracy

Model quality depends on recording clarity, overlapping speakers, accents, and background noise. Speaker diarization can occasionally split or merge speakers incorrectly, especially in noisy recordings. Treat the AI verdict as a helpful first pass and review it for important decisions.
