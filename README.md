# Praat scripts for data collection and manipulation.

### tabulate_vowel_data.praat

- Extracts and tabulates segment data (duration, formants, intensity) from an interval tier.

> Requires an input **sound** file. A TextGrid with the annotated segments must be named after the input Sound file and located in the same folder (Praat standard). Originally meant for vowels but it can be used to get these basic data from any segments.

A tier containing timing units such as syllables or morae can be inserted to calculate relative duration of vowels (or simply for context visualization).

Uses interquartile range (IQR) to identify outliers in the lists of formant values (usually mistakes in annotation or Praat errors) and calculates normal averages. With these averages, formats data to [NORM](https://lingtools.uoregon.edu/norm/index.php) standards.
