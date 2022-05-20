source $stdenv/setup

echo "Retrieving $collection::$file from internet archive..."
downloadedFile=""
[[ -n "$downloadToTemp" ]] && downloadedFile="$TMPDIR/file"
[[ ! -n "$downloadToTemp" ]] && downloadedFile="$out"
ia --insecure download -s "$collection" "$file" > $downloadedFile

runHook postFetch
