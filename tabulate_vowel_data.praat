# Extract and tabulate vowel data from an interval tier
# For this script to work as intended, the TextGrid with the annotated segments must be named after the input Sound file and located in the same folder
#
# Input:
# 	file sound_file - Sound file (.wav)
# 	integer vowel_tier - Interval tier containing annotated vowels
#	integer points - Number of points (currently supports 3 or 5 points)
#	integer padding - Padding (%) to the first and last data points (if padding = 0, first and last points will be exactly at segment start and end; if say padding = 5, first point will be at 5% and last at 95%)
#	integer formants - Number of formants
#	integer formant_ceiling - Formant ceiling (Hz)
#	(OPTIONAL) integer syllable_tier - Interval tier containing annotated syllables (if a positive value is assigned, the final output will include syllable data and vowel relative duration)
# Output:
#	file - Tab-separated text file (.txt) containing the following data: vowel label, vowel duration (ms), intensity (dB) and formants (Hz) at each point
#	(OPTIONAL) file - Tab-separated text file (.txt) formatted to NORM standards
#
# Luis Stemmer (FONAPLI/UFSC), 2026 - based on an older script made by Fernando S. Pacheco @ LINSE/UFSC

# Prompt for Sound file and parameters
form: "Extract and tabulate vowel data from an interval tier"
	infile: "Sound file", ""
	integer: "Vowel tier", ""
	optionmenu: "Points", 2
		option: "3"
		option: "5"
	comment: "Padding (%) to the first and last data points (i.e. vowel start and end)"
	positive: "Padding", "0"
	comment: "---------------------------------------------| Formant settings |---------------------------------------------"
	positive: "Formants", "5"
	positive: "Formant ceiling", "5500"
	comment: "--------------------------------------------------------------------------------------------------------------------------"
	comment: "Identify outliers and calculate F1, F2 and F3 averages?"
	boolean: "Identify outliers", 0
	comment: "To calculate relative duration of vowels, insert tier with annotated syllables (or morae)"
	integer: "Syllable tier", "-1"
	comment: "Leave at -1 to skip."
endform

points = number(points$)

# Get folder path
last_slash = rindex(sound_file$, "/")
if last_slash == 0
    last_slash = rindex(sound_file$, "\")
endif
folder$ = left$(sound_file$, last_slash)

# Open input Sound file and corresponding TextGrid
soundID = Read from file: sound_file$
sound_name$ = selected$("Sound")
textgrid$ = folder$ + sound_name$ + ".TextGrid"
textgridID = Read from file: textgrid$
# Get number of segments in vowels tier
vowel_segments = Get number of intervals: vowel_tier

# Extract formants and intensity
selectObject: soundID
formantID = To Formant (burg): 0.0, formants, formant_ceiling, 0.025, 50
selectObject: soundID
intensityID = To Intensity: 100, 0.0, "no"

# Write table header according to input parameters
table_header$ = "Vowel" + tab$ + "Duration(ms)"
if syllable_tier > 0
	table_header$ = "Syllable" + tab$ + "Syllable duration(ms)" + tab$ + table_header$ + tab$ + "Duration(%)"
endif
for point from 1 to points
	table_header$ = table_header$ + tab$ + "Timestamp_p" + string$(point) + tab$ + "Intensity_p" + string$(point)
	for formant from 1 to formants
		table_header$ = table_header$ + tab$ + "F" + string$(formant) + "_p" + string$(point)
	endfor
endfor

# Data processing starts here!
final_data$ = ""
for segment from 1 to vowel_segments
	selectObject: textgridID
	segment_label$ = Get label of interval: vowel_tier, segment
	vowel_data$ = ""

	# Get data of every vowel (non-empty segments)
	if segment_label$ <> ""
		# Get data points (timestamps)
		vowel_start = Get start time of interval: vowel_tier, segment
		vowel_end = Get end time of interval: vowel_tier, segment
		vowel_mid = (vowel_start + vowel_end) / 2
		vowel_duration = vowel_end - vowel_start
		vowel_data$ = segment_label$ + tab$ + string$(vowel_duration * 1000)

		vowel_start = vowel_start + (vowel_duration * padding / 100)
		vowel_end = vowel_end - (vowel_duration * padding / 100)
		
		if points == 3
			points# = {vowel_start, vowel_mid, vowel_end}
		elif points == 5
			vowel_q1 = (vowel_start + vowel_mid) / 2
			vowel_q3 = (vowel_mid + vowel_end) / 2
			points# = {vowel_start, vowel_q1, vowel_mid, vowel_q3, vowel_end}
		endif

		# Get syllable data and relative duration of vowels
		if syllable_tier > 0
			syllable = Get interval at time: syllable_tier, vowel_start
			syllable_label$ = Get label of interval: syllable_tier, syllable
			syllable_start = Get start time of interval: syllable_tier, syllable
			syllable_end = Get end time of interval: syllable_tier, syllable
			syllable_duration = syllable_end - syllable_start
			vowel_relative_duration = (vowel_duration / syllable_duration) * 100
			syllable_data$ = syllable_label$ + tab$ + string$(syllable_duration * 1000)
			vowel_data$ = syllable_data$ + tab$ + vowel_data$ + tab$ + string$(vowel_relative_duration) + "%"
		endif

		# Get intensity and formants at each point
		for point from 1 to points
			selectObject: intensityID
			intensity_at_point = Get value at time: points#[point], "cubic"
			vowel_data$ = vowel_data$ + tab$ + string$(points#[point]) + tab$ + string$(intensity_at_point)
			for formant from 1 to formants
				selectObject: formantID
				formant_at_point = Get value at time: formant, points#[point], "hertz", "linear"
				vowel_data$ = vowel_data$ + tab$ + string$(formant_at_point)
			endfor
		endfor
	vowel_data$ = replace$(vowel_data$, ".", ",", 0)
	final_data$ = final_data$ + vowel_data$ + newline$
	endif
endfor

final_output$ = table_header$ + newline$ + final_data$

# Write data spreadsheet as a tab-separated file
beginPause: "Confirm path to output file"
	outfile: "Outfile", folder$ + sound_name$ + ".txt"
endPause: "Continue", 1

writeFile: outfile$, final_output$

### MORE OPTIONS ###
# Identify outliers and get average formant values
# Format data to NORM standards (using average formant values)
to_NORM = 0
norm_outfile$ = folder$ + sound_name$ + "_NORM.txt"
if identify_outliers
	vowel_table = Read Table from tab-separated file: outfile$

	column_exists = Get column index: "F1_avg"
	if column_exists == 0
		Append column: "F1_avg"
	endif
	column_exists = Get column index: "F2_avg"
	if column_exists == 0
		Append column: "F2_avg"
	endif
	column_exists = Get column index: "F3_avg"
	if column_exists == 0
		Append column: "F3_avg"
	endif

	vowels = Get number of rows
	for vowel from 1 to vowels
		# Read F1, F2 and F3 values at each point
		f1# = zero#(points) 
		f2# = zero#(points)
		f3# = zero#(points)
		for point from 1 to points
			f1#[point] = Get value: vowel, "F1_p" + string$(point)
			if f1#[point] == undefined
				f1#[point] = -1
			endif
			f2#[point] = Get value: vowel, "F2_p" + string$(point)
			if f3#[point] == undefined
				f3#[point] = -1
			endif
			f3#[point] = Get value: vowel, "F3_p" + string$(point)
			if f3#[point] == undefined
				f3#[point] = -1
			endif
		endfor

		# Get interquartile range of F1, F2 and F3 vectors
		sorted_f1# = sort#(f1#)
		sorted_f2# = sort#(f2#)
		sorted_f3# = sort#(f3#)
		q1_index = (points + 1) * 0.25
		q3_index = (points + 1) * 0.75
		# If quartile positions are not integers, apply linear interpolation
		if q1_index == ceiling(q1_index)
			f1q1 = sorted_f1#[q1_index]
			f1q3 = sorted_f1#[q3_index]
			f2q1 = sorted_f2#[q1_index]
			f2q3 = sorted_f2#[q3_index]
			f3q1 = sorted_f3#[q1_index]
			f3q3 = sorted_f3#[q3_index]
		else
			q1_fraction = q1_index - floor(q1_index)
			q3_fraction = q3_index - floor(q3_index)
			f1q1 = sorted_f1#[floor(q1_index)] + q1_fraction * (sorted_f1#[ceiling(q1_index)] - sorted_f1#[floor(q1_index)])
			f1q3 = sorted_f1#[floor(q3_index)] + q3_fraction * (sorted_f1#[ceiling(q3_index)] - sorted_f1#[floor(q3_index)])
			f2q1 = sorted_f2#[floor(q1_index)] + q1_fraction * (sorted_f2#[ceiling(q1_index)] - sorted_f2#[floor(q1_index)])
			f2q3 = sorted_f2#[floor(q3_index)] + q3_fraction * (sorted_f2#[ceiling(q3_index)] - sorted_f2#[floor(q3_index)])
			f3q1 = sorted_f3#[floor(q1_index)] + q1_fraction * (sorted_f3#[ceiling(q1_index)] - sorted_f3#[floor(q1_index)])
			f3q3 = sorted_f3#[floor(q3_index)] + q3_fraction * (sorted_f3#[ceiling(q3_index)] - sorted_f3#[floor(q3_index)])
		endif
		f1_IQR = f1q3 - f1q1
		f2_IQR = f2q3 - f2q1
		f3_IQR = f3q3 - f3q1

		# Identify and highlight outliers (values above or below a factor of the interquartile range)
		factor = 0.5 ; the more usual value of 1.5 is too restrictive and wont find outliers
		# Get average of F1, F2 and F3 without outliers
		f1_sum = sum(f1#)
		f1_size = size(f1#)
		f2_sum = sum(f2#)
		f2_size = size(f2#)
		f3_sum = sum(f3#)
		f3_size = size(f3#)
		for point from 1 to points
			if f1#[point] < f1q1 - (factor * f1_IQR) | f1#[point] > f1q3 + (factor * f1_IQR)
				f1_sum = f1_sum - f1#[point]
				f1_size = f1_size - 1
				Set string value: vowel, "F1_p" + string$(point), "outlier=" + string$(f1#[point])
			endif
			if f2#[point] < f2q1 - (factor * f2_IQR) | f2#[point] > f2q3 + (factor * f2_IQR)
				f2_sum = f2_sum - f2#[point]
				f2_size = f2_size - 1
				Set string value: vowel, "F2_p" + string$(point), "outlier=" + string$(f2#[point])			
			endif
			if f3#[point] < f3q1 - (factor * f3_IQR) | f3#[point] > f3q3 + (factor * f3_IQR)
				f3_sum = f3_sum - f3#[point]
				f3_size = f3_size - 1
				Set string value: vowel, "F3_p" + string$(point), "outlier=" + string$(f3#[point]) 
			endif
		endfor
		f1_avg = f1_sum / f1_size
		f2_avg = f2_sum / f2_size
		f3_avg = f3_sum / f3_size
		Set string value: vowel, "F1_avg", replace$(string$(f1_avg), ".", ",", 0)
		Set string value: vowel, "F2_avg", replace$(string$(f2_avg), ".", ",", 0)
		Set string value: vowel, "F3_avg", replace$(string$(f3_avg), ".", ",", 0)
	endfor

	# Save changes
	Save as tab-separated file: outfile$

	beginPause: "NORM format"
		comment: "Format the data to NORM standards?"
		boolean: "To NORM", 0
		word: "Speaker name", ""
	endPause: "Continue", 1
	if to_NORM
		norm_table = Create Table with column names: sound_name$ + "_NORM", vowels, "Speaker Vowel Context F1 F2 F3 F1g F2g F3g"
	
		selectObject: vowel_table
		rows = Get number of rows
		for row from 1 to rows
			selectObject: vowel_table
			vowel$ = Get value: row, "Vowel"
			if syllable_tier > 0
				context$ = Get value: row, "Syllable"
			endif
			f1_avg$ = Get value: row, "F1_avg"
			f2_avg$ = Get value: row, "F2_avg"
			f3_avg$ = Get value: row, "F3_avg"
		
			selectObject: norm_table
			Set string value: row, "Speaker", speaker_name$
			Set string value: row, "Vowel", vowel$
			Set string value: row, "Context", context$
			Set numeric value: row, "F1", number(f1_avg$)
			Set numeric value: row, "F2", number(f2_avg$)
			Set numeric value: row, "F3", number(f3_avg$)
		endfor
		selectObject: norm_table
		Save as tab-separated file: norm_outfile$

		# Remove the question marks added by Praat to empty table cells
		fix_empty$ = readFile$(norm_outfile$)
		fix_empty$ = replace$(fix_empty$, "?", "", 0)
		writeFile: norm_outfile$, fix_empty$

		# Remove objects opened by these subroutines
		removeObject: norm_table
	endif
	removeObject: vowel_table
endif

writeInfoLine: "Successfully created or modified file(s): ", newline$, outfile$
if to_NORM
	appendInfoLine: norm_outfile$
	
	### NORM requires files ending in a line break, yet for some reason Praat's newline$ character doesn't work
	### I tried adding a newline$ using both writeFileLine and appendFile and, although it looks right, NORM fails to process it
	### Somehow, manually adding a line break works - i.e. open the _NORM.txt file and press "ENTER" --- who knows, there may be an issue with how Praat's newline$ is being converted to my OS standard
	appendInfoLine: "(!) Before uploading the _NORM.txt file to the NORM website, you may need to add a line break at the end of the file (!)"
endif

# Remove objects opened by this script
removeObject: soundID
removeObject: textgridID
removeObject: formantID
removeObject: intensityID
