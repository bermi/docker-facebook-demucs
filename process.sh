#!/bin/bash

set -uEo pipefail

input="$1"
input_filename=$(basename "${input}")
input_no_ext="${input%.mp3}"
metadata="${input_no_ext}.json"
input_dir=$(printf %q "$input_no_ext")

test -f "${metadata}" || \
(\
    echo "Extracting metadata for ${input}";\
    eyeD3 --plugin=json "${input}" 2>/dev/null | tee > "${metadata}"; \
);

destination_dir="${input_dir//input/output/htdemucs}"

IFS=$'\n'
separated_files=$(bash -c "find ${destination_dir} -maxdepth 1 -type f -name '*.mp3'" 2>/dev/null || echo "")

# If there are no separated files, exit
if [ -z "$separated_files" ]; then
    echo "No separated files found for ${input}"
    make run track="${input_filename}"
fi

best_release_date=$(jq -r '.best_release_date' "${metadata}")
year=${best_release_date:0:4}
artist=$(jq -r '.artist' "${metadata}")
album=$(jq -r '.album' "${metadata}")
title=$(jq -r '.title' "${metadata}")
track=$(jq -r '.track' "${metadata}")
composer=$(jq -r '.composer' "${metadata}")

new_filename="${year/#null/unknown} - ${artist/#null/unknown} - ${title/#null/unknown} - ${composer/#null/unknown}"

# # Iterate over separated files and print their path
for separated_file in $separated_files; do
    sep_type=$(basename "${separated_file%.*}")
    destination_path="processed/${new_filename}.${sep_type}.mp3"
    test -f "$destination_path" || \
    (\
        echo "Copying ${separated_file} to ${destination_path}"; \
        cp "${separated_file}" "${destination_path}"; \
        eyeD3 --quiet --artist "${artist/#null/unknown}" --title "${title/#null/unknown}" --album "${album/#null/unknown}" --release-date "${best_release_date/#null/1900}" --composer "${composer/#null/unknown}" --track "${track/#null/1}" "${destination_path}" >/dev/null; \
        sox "${destination_path}" "${destination_path}.tmp.mp3" silence -l 1 0.1 1% -1 2.0 1%; \
        mv "${destination_path}.tmp.mp3" "${destination_path}"; \
    );
done
