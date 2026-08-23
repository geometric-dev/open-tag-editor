# Bugfix Requirements Document

## Introduction

Two related bugs affect the core file loading workflow in Open Tag Editor:

1. **FLAC tags not loading correctly** — When opening FLAC files, tag values containing non-ASCII characters (e.g., CJK, accented Latin, Cyrillic) are garbled or empty because the tag reading layer does not properly handle UTF-8 encoding.
2. **Previously loaded files not clearing when switching folders** — When the user opens a new folder via the toolbar's "Open Folder" button, the file list from the previous folder remains and new files are appended rather than replacing the old list.

Both bugs degrade the primary user workflow of loading audio files and viewing/editing their tags.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN an audio file (including FLAC) is located at a path containing non-ASCII characters (e.g., emoji ⭐️, CJK, accented Latin) AND the native TagLib library is available THEN the system fails to read tags because `taglib_set_strings_unicode(1)` is never called, causing TagLib to interpret the UTF-8 path bytes as locale-encoded on Windows

1.2 WHEN a FLAC file with non-ASCII tag values is opened using the fallback Id3ReaderService (when native library is unavailable) THEN the system displays garbled/corrupted tag values because Vorbis Comment bytes are decoded as Latin-1 instead of UTF-8

1.3 WHEN the user clicks "Open Folder" in the toolbar and selects a new folder THEN the system appends the new folder's files to the existing file list instead of replacing it, showing files from both the old and new folders

1.4 WHEN the user clicks "Open Files" in the toolbar and selects new files THEN the system appends the selected files to the existing file list instead of replacing it

### Expected Behavior (Correct)

2.1 WHEN an audio file (including FLAC) is located at a path containing non-ASCII characters AND the native TagLib library is available THEN the system SHALL successfully open and read tags from the file by ensuring TagLib is configured for Unicode string handling via `taglib_set_strings_unicode(1)`

2.2 WHEN a FLAC file with non-ASCII tag values is opened using the fallback Id3ReaderService THEN the system SHALL correctly decode Vorbis Comment values as UTF-8 and display them without corruption

2.3 WHEN the user clicks "Open Folder" in the toolbar and selects a new folder THEN the system SHALL clear the existing file list, selection state, and error log before loading and displaying only the new folder's files

2.4 WHEN the user clicks "Open Files" in the toolbar and selects new files THEN the system SHALL clear the existing file list, selection state, and error log before loading and displaying only the selected files

### Unchanged Behavior (Regression Prevention)

3.1 WHEN an MP3 file with ID3v2 tags is opened THEN the system SHALL CONTINUE TO read and display all tag fields correctly

3.2 WHEN a FLAC file with ASCII-only tag values is opened THEN the system SHALL CONTINUE TO read and display all tag fields correctly

3.3 WHEN files are loaded via drag-and-drop THEN the system SHALL CONTINUE TO clear previous files and load the dropped files correctly (this path already works via FolderLoadingService.loadFromDrop)

3.4 WHEN a folder is loaded via the address bar THEN the system SHALL CONTINUE TO clear previous files and load the new folder correctly (this path already works via FolderLoadingService.loadFolder)

3.5 WHEN the app reopens the last folder on startup THEN the system SHALL CONTINUE TO load files correctly without duplicating entries

3.6 WHEN the TagLib native library is available THEN the system SHALL CONTINUE TO read MP3, M4A, OGG, and other format tags correctly via the Properties API
