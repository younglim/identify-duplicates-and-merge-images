#!/bin/bash
# Within each folder in present directory, convert pdf to jpg, move out duplicate images, and merge all images in same folder
# v0.2
# Zui Young @younglim

if ! brew ls --versions imagemagick gs> /dev/null; then
	echo "Installing dependencies"
	brew install imagemagick gs
fi

# Bigger number will result in false-positive detection of duplicate images
threshold=0.01

# PDF to JPG Conversion Quality (dpi)
dpi=300

# Quality of JPG Compression
quality=95

# Sets nullglob
shopt -s nullglob 

basedir=$PWD
outputcmd=$basedir/merge-by-folder.sh

moved_pdf="$basedir/moved_pdf"
mkdir -p "$moved_pdf"

moved_duplicate="$basedir/moved_duplicate"
mkdir -p "$moved_duplicate"

merged_folder="$basedir/merged"

echo -e Finding folders within \"$PWD\" $'\n'

touch "$outputcmd"
rm "$outputcmd"
touch "$outputcmd"
chmod +x "$outputcmd"

rm -rf "$basedir/merged/$folder.jpg"
# echo compare -metric RMSE $filenames NULL: >> $outputcmd

# Function to traverse and do operation
function render_pdf_find_dup_and_move () {
	if [ "$folder" != "merged/" ] && [ "$folder" != "moved_duplicate/" ] && [ "$folder" != "moved_pdf/" ]; then
	
		cd "$basedir/$folder"
		echo Checking \"$folder\"
		
		# Convert pdf to jpg
		if ls *.pdf &> /dev/null; then
			for pdf1 in *.pdf; do
				echo -e	$'\t' Converting \"$pdf1\" to jpg
				convert -density $dpi "$pdf1" "$(echo "$pdf1" | cut -f 1 -d '.')-%03d.jpg"
				
				echo -e	$'\t' Moving \"$pdf1\" to \"$moved_pdf/$folder\" $'\n' 
				mkdir -p "$moved_pdf/$folder"
				mv "$pdf1" "$moved_pdf/$folder"
			done

			# Fix ? character in filename
			if ls *.jpg &> /dev/null; then
				for filename in *; do 
					if [ -f "$filename" ]; then 
						mv "$filename" "$(echo $filename | tr '?' '-')" ; 
					fi
				done
			fi	
		fi	

		cd "$basedir/$folder"

		for image1 in *.{jpg,jpeg,png,gif}; do
			if [ -f "$image1" ]; then 
				for image2 in *.{jpg,jpeg,png,gif}; do
					if [ -f "$image1" ] &&[ "$image1" != "$image2" ]; then
						value=$(compare -metric phash "$image1" "$image2" null: 2>&1);

						if (( $(echo "$value < $threshold" |bc -l) )); then

							echo -e	$'\t' Duplicate \"$image1\" \"$image2\"
							
							echo -e	$'\t' Moving \"$image2\" to \"$moved_duplicate/$folder\" $'\n' 
							mkdir -p "$moved_duplicate/$folder"
							mv "$image2" "$moved_duplicate/$folder"

						fi
					fi

				done
				
			fi
		done


		filenames=$(ls -p | grep -v / | sed -e 's/^/"/g' -e 's/$/"/g' | tr '\n' ' ')

		if [ ! -z "$filenames" ]; then

			echo cd \"$basedir/$folder\" >> "$outputcmd"

			num_dir="${folder//[^/]}"

			if (( ${#num_dir} >= 2 )); then
				echo convert -quality $quality $filenames -append \"$basedir/merged/$(echo $folder | sed 's:/*$::'| sed -e 's/\//-/g').jpg\" >> "$outputcmd"
			else 
				echo convert -quality $quality $filenames -append \"$(echo $basedir/merged/$folder | sed 's:/*$::').jpg\" >> "$outputcmd"
			
			fi
			
			echo -e $'\n\n' >> "$outputcmd"
			
		fi
		
	fi

}


for outerfolder in */; do
	# Cater for 1 level of nested folder
	cd "$basedir/$outerfolder"
	for folder in */; do
		folder="$outerfolder$folder"
		render_pdf_find_dup_and_move
	done

	folder="$outerfolder"
	render_pdf_find_dup_and_move
done

echo -e $'\n====================\n' Merging images in individual folder to \"$merged_folder\"
mkdir -p "$basedir/merged"
"$basedir/merge-by-folder.sh"
open "$basedir/merged"
echo -e $'Completed!\n===================='
