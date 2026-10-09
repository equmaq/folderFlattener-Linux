#!/usr/bin/env bash

set -u

# Check if the correct number of arguments is provided
if [[ $# -ne 1 ]]; then
	printf 'Usage: %s DIRECTORY\n' "$0" >&2
	exit 2
fi

# Check if the provided argument is a directory
working_dir=$1

# Check if the provided argument is a valid directory
if [[ ! -d $working_dir ]]; then
	printf 'Error: directory does not exist: %s\n' "$working_dir" >&2
	exit 1
fi

# Check if gio command is available
if ! command -v gio >/dev/null 2>&1; then
	printf 'Error: gio is required. Install GLib/GIO for your distribution.\n' >&2
	exit 1
fi

# Check if find command is available
working_dir=$(realpath -- "$working_dir")
printf 'Flattening %s...\n' "$working_dir"

# Find all files in the directory and its subdirectories, delete .part files
while IFS= read -r -d '' file; do
	if [[ $file == *.part ]]; then
		if gio remove -- "$file"; then
			printf 'Deleted unused .part file: %s\n' "$file"
		else
			printf 'Could not delete .part file: %s\n' "$file" >&2
		fi
		continue
	fi

    # Generate a new filename based on the relative path and original filename
	directory=$(dirname -- "$file")
	relative_path=${directory#"$working_dir"/}
	base_name=$(basename -- "$file")
	new_base_name=${relative_path//\//_}_${base_name}
	filename=$new_base_name
	count=1

    # Check for filename conflicts and generate a unique filename if necessary
	while [[ -e $working_dir/$filename ]]; do
		if [[ $new_base_name == *.* ]]; then
			filename=${new_base_name%.*}_${count}.${new_base_name##*.}
		else
			filename=${new_base_name}_${count}
		fi
		((count++))
	done

    # Remove specific strings from the filenames
	for string in '/example' '/other example' "/the slashes are just there so this won't do anything"; do
		filename=${filename//"$string"/}
	done

    # Move the file to the working directory with the new filename
	destination=$working_dir/$filename
	printf 'Moving: "%s" to "%s"\n' "$file" "$destination"
	if ! gio move -- "$file" "$destination"; then
		printf 'Could not move: %s\n' "$file" >&2
	fi
done < <(find "$working_dir" -mindepth 2 -type f -print0)

# Remove empty directories after moving files
find "$working_dir" -mindepth 1 -depth -type d -empty -delete

printf 'Finished flattening %s.\n' "$working_dir"
