# Praat scripts for data collection and manipulation

### tabulate_vowel_data.praat

**Purpose:** Extract and tabulate segment data from an interval tier.

**Input:**
- `sound_file` - Sound file (.wav)
- `vowel_tier` - Interval tier containing annotated vowels - or other segments
- `context_tier` - Interval tier containing annotated context, such as syllables, moras, words or sentences (leave at 0 to ignore; if a positive value is assigned, the final output will include context data and relative vowel duration)
-	`padding` - padding (%) to the first and last data points (if padding = 0, first and last points will be exactly at segment start and end; if say padding = 5, first point will be at 5% and last at 95%)
-	`f0_max` - Maximum fundamental frequency
-	`f0_min` - Minimum fundamental frequency
-	`formants` - Number of formants
-	`formant_ceiling` - Formant ceiling (Hz)
-	`preprocessing` - If true, applies preprocessing steps

> Requires an input **sound** file. The script looks for a TextGrid with the same name as the Sound file and located in the same folder.

**Data collection and preprocessing:**

For each non-empty interval in `vowel_tier`, extracts duration and intensity, formants and pitch (fundamental frequency) from five data points (segment start, 25%, middle, 75%, end). The five pitch values are combined with the maximum pitch value in a list ordered by time, and written as a pipe-separated string in a single column labeled `pitch_contour`.  

Unless `preprocessing` is unchecked, tags outlier formant values using interquartile range (undefined values are set to -1) and calculates normal averages for F1, F2 and F3. Optionally, formats data to [NORM](https://lingtools.uoregon.edu/norm/index.php) standards using these averages.

**Output:**
- Tab-separated text file (.txt) containing the following data: vowel label, vowel duration (ms), intensity (dB), formants (Hz) and pitch/F0 (Hz) at each point
- (OPTIONAL) Tab-separated text file (.txt) formatted to NORM standards

---

### move_boundaries.praat

**Purpose:** Adjust interval boundaries in a TextGrid. It moves all boundaries on specified tier(s) to the nearest zero crossing.

**Input:**
- `sound_file` - Sound file (.wav)
- `interval_tier` - Interval tier to be processed (0 = all tiers)
- `replace_tier` - If false, the original tier(s) will be preserved in the output file; otherwise, tiers are replaced 

> Requires an input **sound** file. The script looks for a TextGrid with the same name as the Sound file and located in the same folder.

**Output:**
- TextGrid file with processed tiers. This script does not overwrite the original TextGrid. 


