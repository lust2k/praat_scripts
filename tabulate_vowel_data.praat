# Extract and tabulate vowel data from an interval tier
# For this script to work as intended, the TextGrid with the annotated segments must be named after the input Sound file and located in the same folder
#
# Input:
# 	sound_file - Sound file (.wav)
# 	vowel_tier - Interval tier containing annotated vowels - or other segments
#	context_tier - Interval tier containing annotated context, such as syllables, moras, words or sentences (leave at 0 to ignore; if a positive value is assigned, the final output will include context data and relative vowel duration)
#	offset - Offset (%) to the first and last data points (if offset = 0, first and last points will be exactly at segment start and end; if say offset = 5, first point will be at 5% and last at 95%)
#	formants - Number of formants
#	formant_ceiling - Formant ceiling (Hz)
# Output:
#	outfile - Tab-separated text file (.txt) containing the following data: vowel label, vowel duration (ms), intensity (dB), formants (Hz) and pitch/F0 (Hz) at each point
#	(OPTIONAL) norm_outfile - Tab-separated text file (.txt) formatted to NORM standards
#
# Luis Stemmer (FONAPLI/UFSC), 2026

# Prompt for Sound file and parameters
form: "Extract and tabulate vowel data from an interval tier"
	infile: "Sound file", ""
	natural: "Vowel tier", ""
	comment: "Context is used as reference to calculate vowel relative duration"
	integer: "Context tier", "0"
	comment: "Offset (%) to the first and last data points (i.e. vowel start and end)"
	integer: "Offset", "0"
	comment: "Pitch settings"
	natural: "F0 min", "50"
	natural: "F0 max", "800"
	comment: "Formant settings"
	natural: "Formants", "5"
	positive: "Formant ceiling", "5500"
	comment: "Formant data preprocessing. Identify outliers and calculate averages."
	boolean: "Preprocessing", 1
endform

points = 5
points# = zero#(points)

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
# Get number of segments in vowel tier
vowel_segments = Get number of intervals: vowel_tier

# Extract pitch, formants and intensity
selectObject: soundID
pitchID = To Pitch (filtered autocorrelation): 0, f0_min, f0_max, 15, "no", 0.03, 0.09, 0.5, 0.055, 0.35, 0.14
selectObject: soundID
formantID = To Formant (burg): 0.0, formants, formant_ceiling, 0.025, 50
selectObject: soundID
intensityID = To Intensity: 100, 0.0, 1

# Write table header according to input parameters
table_header$ = "Vowel" + tab$ + "Duration(ms)"
if context_tier > 0
	table_header$ = "Context" + tab$ + "Context duration(ms)" + tab$ + table_header$ + tab$ + "Duration(%)"
endif
for point from 1 to points
	table_header$ = table_header$ + tab$ + "Timestamp_p" + string$(point) + tab$ + "Intensity_p" + string$(point)
	for formant from 1 to 3 ; not interested in F4 and F5
		table_header$ = table_header$ + tab$ + "F" + string$(formant) + "_p" + string$(point)
	endfor
endfor
table_header$ = table_header$ + tab$ + "Pitch_contour"

# Data processing starts here!
final_data$ = ""
for segment from 1 to vowel_segments
	selectObject: textgridID
	segment_label$ = Get label of interval: vowel_tier, segment
	vowel_data$ = ""

	##### Get data of every vowel (skip empty segments)
	if segment_label$ <> ""
		### Get data points (timestamps)
		vowel_start = Get start time of interval: vowel_tier, segment
		vowel_end = Get end time of interval: vowel_tier, segment
		vowel_mid = (vowel_start + vowel_end) / 2
		vowel_q1 = (vowel_start + vowel_mid) / 2
		vowel_q3 = (vowel_mid + vowel_end) / 2
		vowel_duration = vowel_end - vowel_start
		vowel_data$ = segment_label$ + tab$ + string$(vowel_duration * 1000)

		vowel_start = vowel_start + (vowel_duration * offset / 100)
		vowel_end = vowel_end - (vowel_duration * offset / 100)
		
		points# = {vowel_start, vowel_q1, vowel_mid, vowel_q3, vowel_end}

		### Get context data and relative duration of vowels
		if context_tier > 0
			context = Get interval at time: context_tier, vowel_start
			context_label$ = Get label of interval: context_tier, context
			context_start = Get start time of interval: context_tier, context
			context_end = Get end time of interval: context_tier, context
			context_duration = context_end - context_start
			vowel_relative_duration = (vowel_duration / context_duration) * 100
			context_data$ = context_label$ + tab$ + string$(context_duration * 1000)
			vowel_data$ = context_data$ + tab$ + vowel_data$ + tab$ + string$(vowel_relative_duration) + "%"
		endif

		### Get pitch, intensity and formants at each point
		# Pitch values are temporarily stored in a list
		for point from 1 to points
			selectObject: pitchID
			pitch_val[point] = Get value at time: points#[point], "Hertz", "linear"
			if pitch_val[point] == undefined
				pitch_val[point] = -1
			endif
			selectObject: intensityID
			intensity_at_point = Get value at time: points#[point], "cubic"
			vowel_data$ = vowel_data$ + tab$ + string$(points#[point]) + tab$ + string$(intensity_at_point)
			for formant from 1 to 3	
				selectObject: formantID
				formant_at_point = Get value at time: formant, points#[point], "hertz", "linear"
				vowel_data$ = vowel_data$ + tab$ + string$(formant_at_point)
			endfor
		endfor

		### Add maximum pitch to the list of values (ordered by time)
		# This ensures we don't make mistakes in identifying the peak and its alignment
		selectObject: pitchID
		pitch_max = Get maximum: points#[1], points#[points], "Hertz", "parabolic"
		pitch_max_t = Get time of maximum: points#[1], points#[points], "Hertz", "parabolic"
		# Get index where maximum pitch value will be inserted
		pitch_max_index = 1 ; insert max pitch at the start if for some obscure reason the following loop fails
		for point from 1 to (points - 1)
			if pitch_max_t >= points#[point] and pitch_max_t < points#[point + 1]
				pitch_max_index = point + 1
			endif
		endfor

		# Shift right all elements after the insertion point to make space
		index = points + 1
		while index > pitch_max_index
			pitch_val[index] = pitch_val[index - 1]
			index = index - 1
		endwhile
		pitch_val[pitch_max_index] = pitch_max

		# Write pitch values as a set separated by "|" in a single column to show pitch contour
		pitch_contour$ = "("
		for point from 1 to points
			pitch_contour$ = pitch_contour$ + fixed$(pitch_val[point], 2) + " | "
		endfor
		pitch_contour$ = pitch_contour$ + fixed$(pitch_val[points+1], 2) + ")"
		vowel_data$ = vowel_data$ + tab$ + pitch_contour$

		# Replace periods by commas and append vowel data to final data
		vowel_data$ = replace$(vowel_data$, ".", ",", 0)
		final_data$ = final_data$ + vowel_data$ + newline$
	endif
endfor

final_output$ = table_header$ + newline$ + final_data$

# Write final output (a tab-separated text file)
beginPause: "Confirm path to output file"
	outfile: "Outfile", folder$ + sound_name$ + ".txt"
endPause: "Continue", 1
writeFile: outfile$, final_output$

##### Preprocessing #####
# Identify outliers in formant values and get averages
# Format data to NORM standards (using average formant values)
to_NORM = 0
norm_outfile$ = folder$ + sound_name$ + "_NORM.txt"
if preprocessing
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
		# If quartile positions are not integers (i.e. it falls between two points), apply linear interpolation
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

		# Identify outliers (values above or below a factor of the interquartile range)
		factor = 0.5 ; the more usual value of 1.5 is too strict and wont correctly identify what we're calling outliers
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
	selectObject: vowel_table
	Save as tab-separated file: outfile$

	beginPause: "NORM format"
		comment: "Format the data to NORM standards?"
		boolean: "To NORM", 1
		word: "Speaker name", ""
	endPause: "Continue", 1
	if to_NORM
		norm_table = Create Table with column names: sound_name$ + "_NORM", vowels, "Speaker Vowel Context F1 F2 F3 F1g F2g F3g"
	
		selectObject: vowel_table
		rows = Get number of rows
		for row from 1 to rows
			selectObject: vowel_table
			vowel$ = Get value: row, "Vowel"
			if context_tier > 0
				context$ = Get value: row, "Context"
			else
				context$ = ""
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
removeObject: pitchID
removeObject: formantID
removeObject: intensityID
