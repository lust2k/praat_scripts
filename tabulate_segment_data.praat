# Extract and tabulate segment data from an interval tier
# For this script to work as intended, the TextGrid with the annotated segments must be named after the input Sound file and located in the same folder
#
# Input:
# 	sound_file - Sound file (.wav)
# 	segment_tier - Interval tier containing annotated segments
#	context_tier - Interval tier containing annotated context, such as syllables, moras, words or sentences (leave at 0 to ignore; if a positive value is assigned, the final output will include context data and relative segment duration)
#	padding - Padding (%) to the first and last data points (if padding = 0, first and last points will be exactly at segment start and end; if padding = 5, first point will be at 5% and last at 95%)
#	formants - Number of formants
#	formant_ceiling - Formant ceiling (Hz)
# 	preprocessing - If true, applies preprocessing steps
#	spectral_moments - If true, get spectral moments (center of gravity, standard deviation, skewness and kurtosis)
# Output:
#	outfile - Tab-separated text file (.txt) containing the following data: segment label, segment duration (ms), intensity (dB), formants (Hz) and pitch/F0 (Hz) at each point
#	(OPTIONAL) norm_outfile - Tab-separated text file (.txt) formatted to NORM standards
#
# Luis Stemmer (FONAPLI/UFSC), 2026

# Prompt for Sound file and parameters

form: "Extract and tabulate segment data from an interval tier"
	infile: "Sound file", ""
	natural: "Segment tier", ""
	comment: "Context is used as reference to calculate segment relative duration."
	integer: "Context tier", "0"
	comment: "Padding (%) to the first and last data points."
	integer: "Padding", "0"
	comment: "Recording environment." ; very quiet (studio) recordings require a lower silence threshold
	boolean: "Very quiet", 0
	comment: "Formant settings."
	natural: "Formants", "5"
	positive: "Formant ceiling", "5500"
	comment: "Data preprocessing. Identify outliers and calculate averages."
	boolean: "Preprocessing", 1
	comment: "Get spectral moments and peaks (mainly for fricatives)."
	boolean: "Spectral moments", 0
endform

if praatVersion < 6435
	pauseScript: "You may need to update your Praat to run this script. Your current version is: " + praatVersion$
endif

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
# Get number of segments in segment tier
segments = Get number of intervals: segment_tier
# Get tier name
tier_name$ = Get tier name: segment_tier

### Extract pitch in two passes, optimized for speaker's natural voice pitch
pitch_floor = 50
pitch_top = 800
silence_threshold = 0.09
if very_quiet
	silence_threshold = 0.03
endif
# First pass to get median pitch
selectObject: soundID
pitchID = To Pitch (filtered autocorrelation): 0, pitch_floor, pitch_top, 15, "no", 0.03, silence_threshold, 0.5, 0.055, 0.35, 0.14
median_pitch = Get quantile: 0, 0, 0.5, "Hertz"
removeObject: pitchID
if median_pitch < 150
	info$ = "Low-pitched voice; setting pitch search range to 50-600 Hz"
	pitch_top = 600
elsif median_pitch >= 150 and median_pitch < 250
	info$ = Standard, average-pitched voice; setting pitch search range to 75-800 Hz"
	pitch_floor = 75
else
	info$ = "Very high-pitched voice; setting pitch search range to 100-1000 Hz"
	pitch_floor = 100
	pitch_top = 1000
endif
pauseScript: info$

selectObject: soundID
pitchID = To Pitch (filtered autocorrelation): 0, pitch_floor, pitch_top, 15, "no", 0.03, silence_threshold, 0.5, 0.055, 0.35, 0.14


# Extract formants and intensity
selectObject: soundID
formantID = To Formant (burg): 0.0, formants, formant_ceiling, 0.025, 50
selectObject: soundID
intensityID = To Intensity: pitch_floor, 0.0, 1

# Write table header according to input parameters
table_header$ = "Segment" + tab$ + "Duration(ms)"
if context_tier > 0
	table_header$ = "Context" + tab$ + "Context duration(ms)" + tab$ + table_header$ + tab$ + "Duration(%)"
endif
for point from 1 to points
	table_header$ = table_header$ + tab$ + "Timestamp_p" + string$(point) + tab$ + "Intensity_p" + string$(point)
	for formant from 1 to 3 ; not interested in F4 and F5
		table_header$ = table_header$ + tab$ + "F" + string$(formant) + "_p" + string$(point)
	endfor
endfor
table_header$ = table_header$ + tab$ + "Pitch contour"
if spectral_moments
	table_header$ = table_header$ + tab$ + "First peak" + tab$ + "Second peak" + tab$ + "Third peak" + tab$ 
									 ... + "Centroid" + tab$ + "Standard deviation" + tab$ + "Skewness" + tab$ + "Kurtosis"
endif

# Data processing starts here!
final_data$ = ""
for segment from 1 to segments
	selectObject: textgridID
	segment_label$ = Get label of interval: segment_tier, segment
	segment_data$ = ""

	##### Get data of every non-empty segment
	if segment_label$ <> ""
		### Get data points (timestamps)
		segment_start = Get start time of interval: segment_tier, segment
		segment_end = Get end time of interval: segment_tier, segment
		segment_mid = (segment_start + segment_end) / 2
		segment_q1 = (segment_start + segment_mid) / 2
		segment_q3 = (segment_mid + segment_end) / 2
		segment_duration = segment_end - segment_start
		segment_data$ = segment_label$ + tab$ + string$(segment_duration * 1000)

		segment_start = segment_start + (segment_duration * padding / 100)
		segment_end = segment_end - (segment_duration * padding / 100)
		
		points# = {segment_start, segment_q1, segment_mid, segment_q3, segment_end}

		### Get context data and relative duration
		if context_tier > 0
			context = Get interval at time: context_tier, segment_start
			context_label$ = Get label of interval: context_tier, context
			context_start = Get start time of interval: context_tier, context
			context_end = Get end time of interval: context_tier, context
			context_duration = context_end - context_start
			segment_relative_duration = (segment_duration / context_duration) * 100
			context_data$ = context_label$ + tab$ + string$(context_duration * 1000)
			segment_data$ = context_data$ + tab$ + segment_data$ + tab$ + string$(segment_relative_duration) + "%"
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
			segment_data$ = segment_data$ + tab$ + string$(points#[point]) + tab$ + string$(intensity_at_point)
			for formant from 1 to 3	
				selectObject: formantID
				formant_at_point = Get value at time: formant, points#[point], "hertz", "linear"
				segment_data$ = segment_data$ + tab$ + string$(formant_at_point)
			endfor
		endfor

		## Add maximum pitch to the list of values (ordered by time)
		# This ensures we don't make mistakes in identifying the peak and its alignment
		selectObject: pitchID
		pitch_max = Get maximum: points#[1], points#[points], "Hertz", "parabolic"
		if pitch_max == undefined
			pitch_max = -1
		endif
		pitch_max_t = Get time of maximum: points#[1], points#[points], "Hertz", "parabolic"
		# Get index where maximum pitch value will be inserted
		pitch_max_index = 1 ; if max pitch happens before first point, insert at start
		if pitch_max_t >= points#[points]
			pitch_max_index = points + 1 ; if max pitch happens after last point, insert at end
		else
			for point from 1 to (points - 1)
				if pitch_max_t >= points#[point] and pitch_max_t < points#[point + 1]
					pitch_max_index = point + 1
				endif
			endfor
		endif

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
		segment_data$ = segment_data$ + tab$ + pitch_contour$

		### Get spectral moments and peaks
		if spectral_moments
			# Isolate a spectral slice (window length = 0.025s) at the segment's midpoint
			selectObject: soundID
        	partID = Extract part: segment_mid - 0.0125, segment_mid + 0.0125, "hamming", 1.0, "yes"
			# Apply a filter to isolate friction
			cutoff = better_max * 3
			if cutoff < 500
				cutoff = 500
			elsif cutoff > 1000
				cutoff = 1000
			endif
			filteredID = Filter (pass Hann band): cutoff, 11000, 100
			# Moments
			spectrumID = To Spectrum: 1
			cog = Get centre of gravity: 2
			stddev = Get standard deviation: 2
			skew = Get skewness: 2
			kurt = Get kurtosis: 2
			# Peaks
			lpc_spectrumID = LPC smoothing: 10, 50 ; use LPC to isolate peaks (up to 10 peaks from 1kHz to 11kHz)
			spectrumTierID = To SpectrumTier (peaks)
			tableID = Down to Table
			Sort rows: "pow(dB/Hz)"
			rows = Get number of rows
			first_peak = Get value: rows, "freq(Hz)"
			second_peak = Get value: rows - 1, "freq(Hz)"
			third_peak = Get value: rows - 2, "freq(Hz)"		
			removeObject: partID, filteredID, spectrumID, lpc_spectrumID, spectrumTierID, tableID

			spectral_moments$ = string$(cog) + tab$ + string$(stddev) + tab$ + string$(skew) + tab$ + string$(kurt)
			spectral_peaks$ = string$(first_peak) + tab$ + string$(second_peak) + tab$ + string$(third_peak)
			segment_data$ = segment_data$ + tab$ + spectral_peaks$ + tab$ + spectral_moments$ 
		endif

		# Replace periods by commas and append segment data to final data
		segment_data$ = replace$(segment_data$, ".", ",", 0)
		final_data$ = final_data$ + segment_data$ + newline$
	endif
endfor

final_output$ = table_header$ + newline$ + final_data$

# Write final output (a tab-separated text file)
beginPause: "Confirm path to output file"
	outfile: "Outfile", folder$ + sound_name$ + "_" + tier_name$ + ".txt"
endPause: "Continue", 1
writeFile: outfile$, final_output$

##### Preprocessing #####
# Identify outliers in formant values and get averages
# Format data to NORM standards (using average formant values)
to_NORM = 0
norm_outfile$ = folder$ + sound_name$ + "_NORM.txt"
if preprocessing
	segment_table = Read Table from tab-separated file: outfile$

	column_exists = Get column index: "Intensity_avg"
	if column_exists == 0
		Append column: "Intensity_avg"
	endif
	column_exists = Get column index: "Intensity_max"
	if column_exists == 0
		Append column: "Intensity_max"
	endif
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

	segments = Get number of rows
	for segment from 1 to segments
		# Read intensity and formant values at each point
		intensity# = zero#(points)
		f1# = zero#(points) 
		f2# = zero#(points)
		f3# = zero#(points)
		for point from 1 to points
			intensity#[point] = Get value: segment, "Intensity_p" + string$(point) ; Intensity shouldn't return undefined values

			f1#[point] = Get value: segment, "F1_p" + string$(point)
			if f1#[point] == undefined
				f1#[point] = -1
			endif
			f2#[point] = Get value: segment, "F2_p" + string$(point)
			if f3#[point] == undefined
				f3#[point] = -1
			endif
			f3#[point] = Get value: segment, "F3_p" + string$(point)
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
				Set string value: segment, "F1_p" + string$(point), "outlier=" + string$(f1#[point])
			endif
			if f2#[point] < f2q1 - (factor * f2_IQR) | f2#[point] > f2q3 + (factor * f2_IQR)
				f2_sum = f2_sum - f2#[point]
				f2_size = f2_size - 1
				Set string value: segment, "F2_p" + string$(point), "outlier=" + string$(f2#[point])			
			endif
			if f3#[point] < f3q1 - (factor * f3_IQR) | f3#[point] > f3q3 + (factor * f3_IQR)
				f3_sum = f3_sum - f3#[point]
				f3_size = f3_size - 1
				Set string value: segment, "F3_p" + string$(point), "outlier=" + string$(f3#[point]) 
			endif
		endfor
		f1_avg = f1_sum / f1_size
		f2_avg = f2_sum / f2_size
		f3_avg = f3_sum / f3_size
		intensity_avg = mean(intensity#) ; No preprocessing done to intensity values, just get average and maximum
		intensity_max = max(intensity#)

		Set string value: segment, "F1_avg", replace$(string$(f1_avg), ".", ",", 0)
		Set string value: segment, "F2_avg", replace$(string$(f2_avg), ".", ",", 0)
		Set string value: segment, "F3_avg", replace$(string$(f3_avg), ".", ",", 0)
		Set string value: segment, "Intensity_avg", replace$(string$(intensity_avg), ".", ",", 0)
		Set string value: segment, "Intensity_max", replace$(string$(intensity_max), ".", ",", 0)
	endfor

	# Save changes
	selectObject: segment_table
	Save as tab-separated file: outfile$

	beginPause: "NORM format"
		comment: "Format the data to NORM standards?"
		boolean: "To NORM", 0
		word: "Speaker name", ""
	endPause: "Continue", 1
	if to_NORM
		norm_table = Create Table with column names: sound_name$ + "_NORM", segments, "Speaker Segment Context F1 F2 F3 F1g F2g F3g"
	
		selectObject: segment_table
		rows = Get number of rows
		for row from 1 to rows
			selectObject: segment_table
			segment$ = Get value: row, "Segment"
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
			Set string value: row, "Segment", segment$
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
	removeObject: segment_table
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
removeObject: soundID, textgridID, pitchID, formantID, intensityID
