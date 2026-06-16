# Move interval boundaries on a tier to the nearest zero crossing 
# For this script to work as intended, the TextGrid with the annotated segments must be named after the input Sound file and located in the same folder
#
# Input:
# 	sound_file - Sound file (.wav)
# 	interval_tier - Interval tier to be processed (0 = all tiers) 
#	replace_tier - If false, the original tier(s) will be preserved in the output file; otherwise, tiers are replaced 
# Output:
#	*_n0x - TextGrid file with processed tiers. This script doesn't replace the original TextGrid file
#
# Luis Stemmer (FONAPLI/UFSC), 2026

form: "Move boundaries to nearest zero crossing"
	infile: "Sound file", ""
	comment: "Tier with boundaries to be modified (0 = all)"
	integer: "Interval tier", "0"
	boolean: "Replace tier", 1
endform

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
tiers = Get number of tiers

if interval_tier == 0
	for tier from 1 to tiers
		@moveBoundaries: soundID, textgridID, tier, replace_tier
	endfor
else
	@moveBoundaries: soundID, textgridID, interval_tier, replace_tier
endif

n0x_textgrid$ = folder$ + sound_name$ + "_n0x.TextGrid"
original_textgridID = Read from file: textgrid$
if replace_tier == 0
	selectObject: textgridID, original_textgridID
	merged_textgridID = Merge
	Save as text file: n0x_textgrid$
	removeObject: merged_textgridID
else
	selectObject: textgridID
	Save as text file: n0x_textgrid$
endif

Read from file: n0x_textgrid$
writeInfoLine: "The modified TextGrid has been opened in Praat Objects window and stored at: ", newline$, n0x_textgrid$

# Remove objects opened by this script
removeObject: soundID
removeObject: textgridID
removeObject: original_textgridID

# Move all boundaries of an interval tier to their nearest zero crossing point
procedure moveBoundaries: .soundID, .textgridID, .interval_tier, .replace_tier
	selectObject: .textgridID
	.intervals = Get number of intervals: .interval_tier
	.tier_name$ = Get tier name: .interval_tier
	if .replace_tier == 0
		.tier_name$ = .tier_name$ + "_n0x"
	endif
	Insert interval tier: .interval_tier + 1, .tier_name$
	for .interval from 1 to .intervals - 1
		selectObject: .textgridID
		.boundary = Get end time of interval: .interval_tier, .interval
		.int_label$ = Get label of interval: .interval_tier, .interval
		selectObject: .soundID
		.nearest_0x = Get nearest zero crossing: 1, .boundary

		selectObject: .textgridID
		Insert boundary: .interval_tier + 1, .nearest_0x
		Set interval text: .interval_tier + 1, .interval, .int_label$
	endfor
	Remove tier: .interval_tier
endproc
# Move interval boundaries in a tier to the nearest zero crossing 
# For this script to work as intended, the TextGrid with the annotated segments must be named after the input Sound file and located in the same folder
#
# Input:
# 	Sound sound_file - Sound file (.wav)
# 	integer interval_tier - Interval tier to be processed (0 = all tiers) 
#	boolean replace_tier - If false, the original tier(s) will be preserved in the output file; otherwise, tiers are replaced 
# Output:
#	TextGrid *_n0x - TextGrid file with processed tiers
#					 NOTE: This script doesn't replace the original TextGrid file
#
# Luis Stemmer (FONAPLI/UFSC), 2026

form: "Move boundaries to nearest zero crossing"
	infile: "Sound file", ""
	comment: "Tier with boundaries to be modified (0 = all)"
	integer: "Interval tier", "0"
	boolean: "Replace tier", 0
endform

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
tiers = Get number of tiers

if interval_tier == 0
	for tier from 1 to tiers
		@moveBoundaries: soundID, textgridID, tier, replace_tier
	endfor
else
	@moveBoundaries: soundID, textgridID, interval_tier, replace_tier
endif

n0x_textgrid$ = folder$ + sound_name$ + "_n0x.TextGrid"
original_textgridID = Read from file: textgrid$
if replace_tier == 0
	selectObject: textgridID, original_textgridID
	merged_textgridID = Merge
	Save as text file: n0x_textgrid$
	removeObject: merged_textgridID
else
	selectObject: textgridID
	Save as text file: n0x_textgrid$
endif

Read from file: n0x_textgrid$
writeInfoLine: "The modified TextGrid has been opened in Praat Objects window and stored at: ", newline$, n0x_textgrid$

# Remove objects opened by this script
removeObject: soundID
removeObject: textgridID
removeObject: original_textgridID

# Move all boundaries of an interval tier to their nearest zero crossing point
procedure moveBoundaries: .soundID, .textgridID, .interval_tier, .replace_tier
	selectObject: .textgridID
	.intervals = Get number of intervals: .interval_tier
	.tier_name$ = Get tier name: .interval_tier
	if .replace_tier == 0
		.tier_name$ = .tier_name$ + "_n0x"
	endif
	Insert interval tier: .interval_tier + 1, .tier_name$
	for .interval from 1 to .intervals - 1
		selectObject: .textgridID
		.boundary = Get end time of interval: .interval_tier, .interval
		.int_label$ = Get label of interval: .interval_tier, .interval
		selectObject: .soundID
		.nearest_0x = Get nearest zero crossing: 1, .boundary

		selectObject: .textgridID
		Insert boundary: .interval_tier + 1, .nearest_0x
		Set interval text: .interval_tier + 1, .interval, .int_label$
	endfor
	Remove tier: .interval_tier
endproc
